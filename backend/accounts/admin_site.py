"""Django's administrative URL also requires TOTP; no alternate raw CRUD surface."""
from datetime import timedelta

from django.contrib.auth.signals import user_logged_in
from django.dispatch import receiver
from django.utils import timezone
from django_otp.admin import OTPAdminSite


@receiver(user_logged_in, dispatch_uid="worknet.admin_cookie_grant")
def admin_cookie_grant(sender, request, user, **kwargs):
    if user.is_staff or user.is_superuser:
        request.session["worknet_admin_revision"] = user.admin_revision
        request.session["worknet_admin_expires"] = (timezone.now() + timedelta(hours=12)).timestamp()


class WorkNetAdminSite(OTPAdminSite):
    site_header = "WorkNet · Acceso técnico con doble factor"
    site_title = "WorkNet"

    def has_permission(self, request):
        return (super().has_permission(request) and request.user.is_superuser
            and request.session.get("worknet_admin_revision") == request.user.admin_revision
            and request.session.get("worknet_admin_expires", 0) > timezone.now().timestamp())


# Intentionally empty: manage accounts through the protected, audited WorkNet API.
# Auto-discovered OTP/Token/Group models on Django's default site are never routed.
site = WorkNetAdminSite(name="admin")
