"""HU026: strict administrative CRUD, authority boundaries, revocation and audit."""
from smtplib import SMTPException

from django.contrib.auth.password_validation import validate_password
from django.db import IntegrityError, OperationalError, transaction
from django.db.models import F, Q
from django.core.exceptions import ValidationError as DjangoValidationError
from rest_framework import serializers
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from django.utils.decorators import method_decorator
from django.views.decorators.debug import sensitive_post_parameters

from .account_configuration import StrictInputSerializer
from .admin_access import CATALOG, ROLE_PERMISSIONS, admin_data, admin_permissions, locked_user, locked_request_actor, require_permission, revoke_admin
from .admin_mfa import private_response
from .email_verification import send_verification_email
from .models import AdminAccess, AdminEvent, User


class AdminInput(StrictInputSerializer):
    full_name = serializers.CharField(max_length=150, required=False)
    administrative_role = serializers.ChoiceField(choices=list(ROLE_PERMISSIONS), required=False)
    permissions = serializers.ListField(child=serializers.ChoiceField(choices=list(CATALOG)), max_length=len(CATALOG), required=False)
    is_active = serializers.BooleanField(required=False)

    def validate(self, data):
        if "permissions" in data and len(set(data["permissions"])) != len(data["permissions"]):
            raise serializers.ValidationError({"permissions": "No repitas permisos."})
        return data


class CreateAdminInput(AdminInput):
    full_name = serializers.CharField(max_length=150)
    email = serializers.EmailField(max_length=254)
    password = serializers.CharField(write_only=True, trim_whitespace=False, max_length=128)
    administrative_role = serializers.ChoiceField(choices=list(ROLE_PERMISSIONS))

    def validate_email(self, value):
        value = value.strip().lower()
        if User.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError("Ya existe una cuenta con este correo.")
        return value

    def validate(self, data):
        data = super().validate(data)
        try:
            validate_password(data["password"], User(email=data["email"], full_name=data["full_name"]))
        except DjangoValidationError as error:
            raise serializers.ValidationError({"password": error.messages})
        return data


class UpdateAdminInput(AdminInput):
    version = serializers.IntegerField(min_value=0)


def validate_grants(actor, role, permissions):
    if not set(permissions) <= ROLE_PERMISSIONS[role]:
        raise ValidationError({"permissions": "Los permisos no corresponden al rol seleccionado."})
    if not set(permissions) <= admin_permissions(actor):
        raise PermissionDenied("No puedes conceder permisos que no tienes.")


class AdminAPIView(APIView):
    def finalize_response(self, request, response, *args, **kwargs):
        response = super().finalize_response(request, response, *args, **kwargs)
        response["Cache-Control"] = "no-store, private"
        return response

    def handle_exception(self, exc):
        if isinstance(exc, OperationalError):
            return private_response({"message": "Hay otra operación administrativa en curso. Actualiza y reintenta."}, 503)
        return super().handle_exception(exc)


@method_decorator(sensitive_post_parameters("password"), name="dispatch")
class AdminAccountsView(AdminAPIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        perms = admin_permissions(request.user)
        if not {"manage_admins", "manage_permissions"}.intersection(perms):
            raise PermissionDenied("No tienes permiso para consultar administradores.")
        if set(request.query_params) - {"page"} or any(len(request.query_params.getlist(k)) != 1 for k in request.query_params):
            raise ValidationError({"message": "Parámetros de listado no válidos."})
        raw = request.query_params.get("page", "1")
        if len(raw) > 6 or not raw.isascii() or not raw.isdigit() or not 1 <= int(raw) <= 100000:
            raise ValidationError({"page": "Indica una página válida."})
        page = int(raw)
        rows = User.objects.filter(Q(is_staff=True) | Q(is_superuser=True)).order_by("id")
        total = rows.count()
        if page > max(1, (total + 19) // 20):
            raise ValidationError({"page": "La página no existe."})
        return private_response({"results": [admin_data(u) for u in rows[(page - 1)*20:page*20]],
            "count": total, "page": page, "page_size": 20,
            "permission_catalog": [{"key": k, "label": v} for k, v in CATALOG.items()],
            "roles": [{"key": k, "permissions": sorted(v)} for k, v in ROLE_PERMISSIONS.items()],
            "can_create": request.user.is_superuser, "my_permissions": sorted(perms)})

    def post(self, request):
        data = CreateAdminInput(data=request.data)
        data.is_valid(raise_exception=True)
        values = dict(data.validated_data)
        role = values.pop("administrative_role")
        permissions = values.pop("permissions", sorted(ROLE_PERMISSIONS[role]))
        try:
            with transaction.atomic():
                actor = locked_request_actor(request)
                if not actor.is_active or not actor.is_superuser:
                    raise PermissionDenied("Solo el administrador principal puede crear administradores.")
                validate_grants(actor, role, permissions)
                user = User.objects.create_user(**values, is_staff=True, email_verified=False)
                AdminAccess.objects.create(user=user, role=role, permissions=permissions)
                send_verification_email(user, request)
                AdminEvent.objects.create(actor=actor, target=user, action="admin_created")
        except IntegrityError:
            raise ValidationError({"email": "Ya existe una cuenta con este correo."})
        except (SMTPException, OSError):
            return private_response({"message": "No se pudo enviar la verificación; no se creó la cuenta. Reintenta."}, 503)
        return private_response({"administrator": admin_data(user),
            "message": "Cuenta creada. Debe verificar su correo y configurar el doble factor al iniciar sesión."}, 201)


class AdminAccountView(AdminAPIView):
    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def patch(self, request, pk):
        data = UpdateAdminInput(data=request.data)
        data.is_valid(raise_exception=True)
        values = dict(data.validated_data)
        version = values.pop("version")
        if not values:
            raise ValidationError({"message": "Indica al menos un cambio."})
        if pk == request.user.pk:
            raise PermissionDenied("No puedes modificar tu propia autoridad administrativa.")
        # Reserve writers before any SELECT; a stable lock order also avoids reciprocal updates.
        for identifier in sorted({request.user.pk, pk}):
            User.objects.filter(pk=identifier).update(admin_revision=F("admin_revision"))
        actor = locked_request_actor(request)
        if not {"manage_admins", "manage_permissions"}.intersection(admin_permissions(actor)):
            raise PermissionDenied("No tienes permiso para gestionar administradores.")
        if not User.objects.filter(pk=pk).filter(Q(is_staff=True) | Q(is_superuser=True)).exists():
            return private_response({"message": "Administrador no encontrado."}, 404)
        locked = {identifier: locked_user(identifier) for identifier in sorted({request.user.pk, pk})}
        actor, user = locked_request_actor(request), locked[pk]
        if user.is_superuser:
            raise PermissionDenied("La cuenta principal está protegida y no se modifica desde esta función.")
        if {"full_name", "is_active"}.intersection(values):
            require_permission(actor, "manage_admins")
        if {"administrative_role", "permissions"}.intersection(values):
            require_permission(actor, "manage_permissions")
        access, _ = AdminAccess.objects.get_or_create(user=user, defaults={"role": "revisor", "permissions": sorted(ROLE_PERMISSIONS["revisor"])})
        if access.version != version:
            return private_response({"message": "La cuenta cambió. Actualiza el listado antes de guardar."}, 409)
        role = values.get("administrative_role", access.role)
        permissions = values.get("permissions", access.permissions)
        if {"administrative_role", "permissions"}.intersection(values):
            validate_grants(actor, role, permissions)
        authority_changed = role != access.role or set(permissions) != set(access.permissions) or values.get("is_active", user.is_active) != user.is_active
        for field in ("full_name", "is_active"):
            if field in values:
                setattr(user, field, values[field])
        user.save(update_fields=[k for k in ("full_name", "is_active") if k in values])
        access.role, access.permissions = role, sorted(permissions)
        access.version += 1
        access.save(update_fields=["role", "permissions", "version"])
        if authority_changed:
            revoke_admin(user)
        AdminEvent.objects.create(actor=actor, target=user, action="admin_authority_changed" if authority_changed else "admin_updated")
        return private_response({"administrator": admin_data(user), "message": "Cambios guardados. Los cambios de autoridad revocan sus sesiones."})


class AdminEventsView(AdminAPIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        require_permission(request.user, "view_events")
        if request.query_params:
            raise ValidationError({"message": "No se admiten parámetros."})
        return private_response({"events": list(AdminEvent.objects.order_by("-created_at", "-id").values(
            "id", "actor__full_name", "target__full_name", "action", "created_at")[:50])})
