"""Unit-test fixtures only; acceptance must exercise password and actual TOTP API."""
from datetime import timedelta
from django.utils import timezone
from django_otp.plugins.otp_totp.models import TOTPDevice
from rest_framework.authtoken.models import Token
from .models import AdminMFASession


def fixture_token(user):
    user.refresh_from_db()
    token, _ = Token.objects.get_or_create(user=user)
    if user.is_staff or user.is_superuser:
        TOTPDevice.objects.get_or_create(user=user, name="WorkNet", defaults={"confirmed": True})
        AdminMFASession.objects.update_or_create(token=token, defaults={"revision": user.admin_revision,
            "password_hash": user.get_session_auth_hash(), "expires_at": timezone.now() + timedelta(hours=12)})
    return token
