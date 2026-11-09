"""Administrative authority is evaluated from the database on every request."""
from django.db.models import F
from rest_framework.exceptions import PermissionDenied

from .models import AdminAccess, AdminChallenge, User

CATALOG = {
    "dashboard": "Consultar panel administrativo",
    "review_companies": "Validar empresas",
    "view_events": "Consultar eventos administrativos",
    "manage_admins": "Gestionar cuentas administrativas",
    "manage_permissions": "Configurar permisos administrativos",
}
ROLE_PERMISSIONS = {
    "revisor": {"dashboard", "review_companies", "view_events"},
    "gestor": set(CATALOG),
}


def admin_permissions(user):
    if not user.is_active or not (user.is_staff or user.is_superuser):
        return set()
    if user.is_superuser:
        return set(CATALOG)
    access = AdminAccess.objects.filter(user=user).first()
    # Existing staff retain their original review capabilities, but must enroll MFA.
    if access is None:
        return set(ROLE_PERMISSIONS["revisor"])
    return set(access.permissions) & ROLE_PERMISSIONS.get(access.role, set())


def require_permission(user, permission):
    if permission not in admin_permissions(user):
        raise PermissionDenied("No tienes permiso para esta función administrativa.")


def locked_user(pk):
    """Write first also serializes SQLite transactions; row lock on PostgreSQL.

    All challenge/device/authority mutations take this same lock. Call inside atomic.
    """
    User.objects.filter(pk=pk).update(admin_revision=F("admin_revision"))
    return User.objects.select_for_update().get(pk=pk)


def locked_request_actor(request):
    locked_user(request.user.pk)
    from .authentication import TokenAuthentication
    return TokenAuthentication().authenticate_credentials(request.auth.key)[0]


def revoke_admin(user):
    from rest_framework.authtoken.models import Token
    User.objects.filter(pk=user.pk).update(admin_revision=F("admin_revision") + 1)
    Token.objects.filter(user=user).delete()
    AdminChallenge.objects.filter(user=user).update(consumed=True)


def admin_data(user):
    from django_otp.plugins.otp_totp.models import TOTPDevice
    access = AdminAccess.objects.filter(user=user).first()
    return {
        "id": user.pk, "full_name": user.full_name, "email": user.email,
        "administrative_role": "principal" if user.is_superuser else access.role if access else "revisor",
        "is_active": user.is_active, "email_verified": user.email_verified,
        "permissions": sorted(admin_permissions(user)) if user.is_active else sorted(
            set(access.permissions) & ROLE_PERMISSIONS.get(access.role, set()) if access else ROLE_PERMISSIONS["revisor"]),
        "mfa_enrolled": TOTPDevice.objects.filter(user=user, confirmed=True).exists(),
        "version": access.version if access else 0,
        "protected": user.is_superuser,
    }
