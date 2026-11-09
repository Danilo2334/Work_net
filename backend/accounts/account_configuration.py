"""TASK-HU004-02: consultar, actualizar y eliminar la propia cuenta."""

from django.contrib.auth.password_validation import validate_password
from django.db import transaction
from rest_framework import serializers, status
from accounts.authentication import TokenAuthentication
from rest_framework.authtoken.models import Token
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import User


class AccountSerializer(serializers.ModelSerializer):
    role = serializers.SerializerMethodField()
    administrative_role = serializers.SerializerMethodField()
    permissions = serializers.SerializerMethodField()
    mfa_verified = serializers.SerializerMethodField()

    def to_representation(self, user):
        data = super().to_representation(user)
        if not (user.is_staff or user.is_superuser):
            for field in ("administrative_role", "permissions", "mfa_verified"):
                data.pop(field, None)
        return data

    def get_administrative_role(self, user):
        if not (user.is_staff or user.is_superuser):
            return None
        from .admin_access import admin_data
        return admin_data(user)["administrative_role"]

    def get_permissions(self, user):
        from .admin_access import admin_permissions
        return sorted(admin_permissions(user))

    def get_mfa_verified(self, user):
        # This serializer is used only after the MFA-aware authentication class.
        return bool(user.is_staff or user.is_superuser)

    def get_role(self, user):
        return "admin" if user.is_staff or user.is_superuser else user.role or "unassigned"

    class Meta:
        model = User
        fields = ("id", "full_name", "email", "role", "email_verified", "administrative_role", "permissions", "mfa_verified")
        read_only_fields = ("id", "email", "role", "email_verified")

    def to_internal_value(self, data):
        if isinstance(data, dict):
            forbidden = set(data) - {"full_name"}
            if forbidden:
                raise serializers.ValidationError({
                    field: "Este campo no se puede modificar desde configuración."
                    for field in sorted(forbidden)
                })
        return super().to_internal_value(data)

    def validate(self, data):
        if not data:
            raise serializers.ValidationError("Debes enviar full_name para actualizar tu nombre.")
        return data

    def update(self, instance, validated_data):
        instance.full_name = validated_data["full_name"]
        # Actualizar solo el nombre evita sobrescribir otras modificaciones concurrentes.
        instance.save(update_fields=["full_name"])
        return instance


class StrictInputSerializer(serializers.Serializer):
    def to_internal_value(self, data):
        if isinstance(data, dict):
            unknown = set(data) - set(self.fields)
            if unknown:
                raise serializers.ValidationError({
                    field: "Campo no permitido." for field in sorted(unknown)
                })
        return super().to_internal_value(data)


class ChangePasswordSerializer(StrictInputSerializer):
    current_password = serializers.CharField(write_only=True, trim_whitespace=False)
    new_password = serializers.CharField(write_only=True, trim_whitespace=False)
    new_password_confirm = serializers.CharField(write_only=True, trim_whitespace=False)

    def validate(self, data):
        user = self.context["user"]
        if not user.check_password(data["current_password"]):
            raise serializers.ValidationError({"current_password": "La contraseña actual es incorrecta."})
        if data["new_password"] != data["new_password_confirm"]:
            raise serializers.ValidationError({"new_password_confirm": "Las contraseñas no coinciden."})
        if user.check_password(data["new_password"]):
            raise serializers.ValidationError({"new_password": "La nueva contraseña debe ser diferente."})
        validate_password(data["new_password"], user=user)
        return data


class ExplicitConfirmationField(serializers.BooleanField):
    def to_internal_value(self, data):
        if data is not True:
            raise serializers.ValidationError("Debes confirmar enviando confirmation: true.")
        return True


class DeleteAccountSerializer(StrictInputSerializer):
    current_password = serializers.CharField(write_only=True, trim_whitespace=False)
    confirmation = ExplicitConfirmationField(write_only=True)

    def validate_current_password(self, value):
        if not self.context["user"].check_password(value):
            raise serializers.ValidationError("La contraseña actual es incorrecta.")
        return value


class AuthenticatedAccountView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated]


class AccountView(AuthenticatedAccountView):
    def get(self, request):
        return Response({"user": AccountSerializer(request.user).data})

    def patch(self, request):
        serializer = AccountSerializer(request.user, data=request.data, partial=True)
        if not serializer.is_valid():
            return Response(
                {"message": "No fue posible actualizar la cuenta.", "errors": serializer.errors},
                status=status.HTTP_400_BAD_REQUEST,
            )
        serializer.save()
        return Response({"message": "Datos actualizados correctamente.", "user": serializer.data})


class ChangePasswordView(AuthenticatedAccountView):
    def post(self, request):
        with transaction.atomic():
            user = User.objects.select_for_update().get(pk=request.user.pk)
            serializer = ChangePasswordSerializer(data=request.data, context={"user": user})
            if not serializer.is_valid():
                return Response(
                    {"message": "No fue posible cambiar la contraseña.", "errors": serializer.errors},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            user.set_password(serializer.validated_data["new_password"])
            user.save(update_fields=["password"])
            if user.is_staff or user.is_superuser:
                return Response({"message": "Contraseña actualizada. Inicia sesión de nuevo con doble factor."}, status=401)
            # La señal revoca el token anterior. El cliente debe guardar el nuevo.
            token = Token.objects.create(user=user)
        return Response({"message": "Contraseña actualizada correctamente.", "token": token.key})


class DeleteAccountView(AuthenticatedAccountView):
    def delete(self, request):
        if request.user.is_staff or request.user.is_superuser:
            return Response({"message": "Las cuentas administrativas se desactivan desde la gestión autorizada; no pueden eliminarse aquí."}, status=403)
        with transaction.atomic():
            user = User.objects.select_for_update().get(pk=request.user.pk)
            serializer = DeleteAccountSerializer(data=request.data, context={"user": user})
            if not serializer.is_valid():
                return Response(
                    {"message": "No fue posible eliminar la cuenta.", "errors": serializer.errors},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            user.delete()
        return Response({"message": "Cuenta eliminada correctamente."})
