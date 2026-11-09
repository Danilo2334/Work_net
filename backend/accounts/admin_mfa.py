"""Password-bound, expiring challenges; RFC6238 via django-otp, one-use recovery."""
import base64
import hashlib
import secrets
from datetime import timedelta

from django.db import OperationalError, transaction
from django.db.models import F, Subquery
from django.utils import timezone
from django.utils.crypto import constant_time_compare
from django.views.decorators.debug import sensitive_post_parameters
from django.utils.decorators import method_decorator
from django_otp.plugins.otp_totp.models import TOTPDevice
from rest_framework import serializers
from rest_framework.authtoken.models import Token
from rest_framework.response import Response
from rest_framework.views import APIView

from .account_configuration import StrictInputSerializer
from .admin_access import admin_data, locked_user, revoke_admin
from .models import AdminChallenge, AdminEvent, AdminMFASession, AdminRecoveryCode, User


def private_response(data, status=200):
    response = Response(data, status=status)
    response["Cache-Control"] = "no-store, private"
    response["Pragma"] = "no-cache"
    return response


def challenge_data(challenge, enrollment):
    return {"mfa_required": True, "challenge": str(challenge.pk),
            "enrollment_required": enrollment, "expires_at": challenge.expires_at,
            "message": "Configura el autenticador para continuar." if enrollment else "Introduce el segundo factor."}


@transaction.atomic
def begin_challenge(user):
    authenticated_hash = user.get_session_auth_hash()
    user = locked_user(user.pk)
    if (not user.is_active or not user.email_verified or not (user.is_staff or user.is_superuser)
            or not constant_time_compare(authenticated_hash, user.get_session_auth_hash())):
        return private_response({"message": "La cuenta cambió. Inicia sesión de nuevo."}, 400)
    AdminChallenge.objects.filter(user=user, consumed=False).update(consumed=True)
    challenge = AdminChallenge.objects.create(user=user, password_hash=user.get_session_auth_hash(),
        revision=user.admin_revision, expires_at=timezone.now() + timedelta(minutes=5))
    return private_response(challenge_data(challenge, not TOTPDevice.objects.filter(user=user, confirmed=True).exists()), 202)


class ChallengeInput(StrictInputSerializer):
    challenge = serializers.UUIDField()


class VerifyInput(ChallengeInput):
    code = serializers.CharField(max_length=64, trim_whitespace=True)
    recovery = serializers.BooleanField(default=False)


def valid_challenge(identifier):
    # The ticket is not an API credential: it can only operate this MFA protocol.
    # Reserve the SQLite writer before any read, avoiding two readers upgrading locks.
    User.objects.filter(pk=Subquery(AdminChallenge.objects.filter(pk=identifier).values("user_id")[:1])).update(admin_revision=F("admin_revision"))
    initial = AdminChallenge.objects.filter(pk=identifier).first()
    if initial is None:
        return None, None
    user = locked_user(initial.user_id)
    ticket = AdminChallenge.objects.select_for_update().get(pk=identifier)
    if (ticket.consumed or ticket.attempts >= 5 or ticket.expires_at <= timezone.now()
            or not user.is_active or not user.email_verified or not (user.is_staff or user.is_superuser)
            or ticket.revision != user.admin_revision
            or not constant_time_compare(ticket.password_hash, user.get_session_auth_hash())):
        return None, None
    return user, ticket


def recovery_digest(code):
    # Random 128-bit codes; no plaintext recovery material is stored.
    return hashlib.sha256(code.encode("utf-8")).hexdigest()


@method_decorator(sensitive_post_parameters("code", "challenge"), name="dispatch")
class MFAView(APIView):
    authentication_classes = []
    permission_classes = []
    http_method_names = ["post", "options"]

    def finalize_response(self, request, response, *args, **kwargs):
        response = super().finalize_response(request, response, *args, **kwargs)
        response["Cache-Control"] = "no-store, private"
        response["Pragma"] = "no-cache"
        return response

    def handle_exception(self, exc):
        if isinstance(exc, OperationalError):
            return private_response({"message": "Hay otra operación de seguridad en curso. Reintenta."}, 503)
        return super().handle_exception(exc)


class MFASetupView(MFAView):
    @transaction.atomic
    def post(self, request):
        data = ChallengeInput(data=request.data)
        data.is_valid(raise_exception=True)
        user, ticket = valid_challenge(data.validated_data["challenge"])
        if user is None:
            return private_response({"message": "La autorización de doble factor no es válida o venció."}, 400)
        if TOTPDevice.objects.filter(user=user, confirmed=True).exists():
            return private_response({"message": "El autenticador ya está configurado."}, 409)
        device, _ = TOTPDevice.objects.get_or_create(user=user, name="WorkNet", defaults={"confirmed": False})
        return private_response({"secret": base64.b32encode(device.bin_key).decode(),
            "otpauth_url": device.config_url, "message": "Guarda esta clave únicamente en tu autenticador privado."})


class MFAVerifyView(MFAView):
    @transaction.atomic
    def post(self, request):
        data = VerifyInput(data=request.data)
        data.is_valid(raise_exception=True)
        user, ticket = valid_challenge(data.validated_data["challenge"])
        if user is None:
            return private_response({"message": "La autorización de doble factor no es válida o venció."}, 400)
        code = data.validated_data["code"]
        device = TOTPDevice.objects.select_for_update().filter(user=user, name="WorkNet").first()
        ticket.attempts += 1
        ticket.save(update_fields=["attempts"])
        if data.validated_data["recovery"]:
            matched = AdminRecoveryCode.objects.filter(user=user, digest=recovery_digest(code)).first()
            if matched is None or device is None or not device.confirmed:
                return private_response({"message": "Código de recuperación no válido."}, 400)
            # Recovery never disables MFA: replace lost authenticator, then verify the new one.
            revoke_admin(user)
            AdminRecoveryCode.objects.filter(user=user).delete()
            TOTPDevice.objects.filter(user=user).delete()
            AdminEvent.objects.create(actor=user, target=user, action="mfa_recovery")
            return begin_challenge(user)
        if device is None or len(code) != 6 or not code.isascii() or not code.isdigit() or not device.verify_token(code):
            # Return rather than raise: failure counters and library throttling must commit.
            return private_response({"message": "Código incorrecto, utilizado o temporalmente bloqueado. Espera el siguiente código."}, 400)
        enrolled = not device.confirmed
        if enrolled:
            device.confirmed = True
            device.save(update_fields=["confirmed"])
        ticket.consumed = True
        ticket.save(update_fields=["consumed"])
        # Never re-enable a pre-MFA/previous token, including credentials copied before enrollment.
        Token.objects.filter(user=user).delete()
        token = Token.objects.create(user=user)
        AdminMFASession.objects.create(token=token, revision=user.admin_revision,
            password_hash=user.get_session_auth_hash(), expires_at=timezone.now() + timedelta(hours=12))
        payload = {"message": "Doble factor verificado.", "token": token.key,
            "user": {"id": user.pk, "full_name": user.full_name, "email": user.email, "role": "admin",
                     "email_verified": user.email_verified, "mfa_verified": True,
                     **{k: v for k, v in admin_data(user).items() if k in ("administrative_role", "permissions")}}}
        if enrolled:
            AdminRecoveryCode.objects.filter(user=user).delete()
            codes = [secrets.token_hex(16) for _ in range(8)]
            AdminRecoveryCode.objects.bulk_create([AdminRecoveryCode(user=user, digest=recovery_digest(c)) for c in codes])
            payload["recovery_codes"] = codes
        AdminEvent.objects.create(actor=user, target=user, action="mfa_enrolled" if enrolled else "mfa_login")
        return private_response(payload)
