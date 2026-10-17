"""TASK-HU004-03: guardar y consultar preferencias del usuario autenticado."""

from rest_framework import serializers, status
from rest_framework.response import Response

from .account_configuration import AuthenticatedAccountView, StrictInputSerializer


class NotificationBooleanField(serializers.BooleanField):
    def to_internal_value(self, data):
        if type(data) is not bool:
            raise serializers.ValidationError("Debes enviar un booleano JSON: true o false.")
        return data


class NotificationPreferencesSerializer(StrictInputSerializer):
    push_notifications = NotificationBooleanField()

    def update(self, instance, validated_data):
        instance.push_notifications = validated_data["push_notifications"]
        # Guardar solo esta preferencia conserva cambios concurrentes en la cuenta.
        instance.save(update_fields=["push_notifications"])
        return instance


class NotificationPreferencesView(AuthenticatedAccountView):
    def get(self, request):
        return Response({"preferences": NotificationPreferencesSerializer(request.user).data})

    def patch(self, request):
        serializer = NotificationPreferencesSerializer(request.user, data=request.data)
        if not serializer.is_valid():
            return Response(
                {"message": "No fue posible actualizar las preferencias.", "errors": serializer.errors},
                status=status.HTTP_400_BAD_REQUEST,
            )
        serializer.save()
        return Response({
            "message": "Preferencias de notificaciones actualizadas correctamente.",
            "preferences": serializer.data,
        })
