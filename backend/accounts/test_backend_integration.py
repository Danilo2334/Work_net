"""Regresiones de la unión HU001-HU005 con los ajustes de integración."""
from urllib.parse import parse_qs, urlparse

from django.core import mail
from django.test import override_settings
from rest_framework.authtoken.models import Token
from rest_framework.test import APITestCase

from .email_verification import create_verification_token
from .models import User


@override_settings(
    MAILERS={"default": {"BACKEND": "django.core.mail.backends.locmem.EmailBackend"}},
    PASSWORD_HASHERS=["django.contrib.auth.hashers.MD5PasswordHasher"],
)
class ConsolidatedBackendTests(APITestCase):
    password = "PruebaIntegracion!2026"

    def make_user(self, email="candidato@example.com", **extra):
        values = dict(full_name="Candidato de prueba", role="candidato", email_verified=True)
        values.update(extra)
        return User.objects.create_user(email=email, password=self.password, **values)

    def login(self, user, password=None):
        return self.client.post("/api/login/", {
            "email": user.email, "password": self.password if password is None else password,
        }, format="json")

    def test_registration_verification_login_and_dashboard_work_together(self):
        response = self.client.post("/api/register/", {
            "full_name": "Nueva candidata", "email": "nueva@example.com",
            "password": self.password, "password_confirm": self.password, "role": "candidato",
        }, format="json")
        self.assertEqual(response.status_code, 201)
        self.assertEqual(len(mail.outbox), 1)
        user = User.objects.get(email="nueva@example.com")
        self.assertFalse(user.email_verified)
        self.assertEqual(self.login(user).status_code, 400)
        link = next(line for line in mail.outbox[0].body.splitlines() if line.startswith("http"))
        parts = urlparse(link)
        self.assertEqual(self.client.get(parts.path + "?" + parts.query).status_code, 200)
        user.refresh_from_db()
        self.assertTrue(user.email_verified)
        response = self.login(user)
        self.assertEqual(response.status_code, 200)
        token = response.data["token"]
        self.assertEqual(self.login(user).data["token"], token)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token}")
        self.assertEqual(self.client.get("/api/account/").status_code, 200)
        self.assertEqual(self.client.get("/api/account/notifications/").status_code, 200)
        self.assertEqual(self.client.get("/api/dashboard/candidate/").status_code, 200)

    def test_duplicate_email_and_public_admin_registration_are_rejected(self):
        self.make_user(email="persona@example.com")
        for email, role in [("PERSONA@example.com", "candidato"), ("admin@example.com", "admin")]:
            with self.subTest(email=email, role=role):
                response = self.client.post("/api/register/", {
                    "full_name": "Intento", "email": email, "role": role,
                    "password": self.password, "password_confirm": self.password,
                }, format="json")
                self.assertEqual(response.status_code, 400)
        self.assertEqual(User.objects.count(), 1)
        self.assertEqual(len(mail.outbox), 0)

    def test_login_preserves_admin_role_from_integration_and_candidate_restriction(self):
        for field in ["is_staff", "is_superuser"]:
            with self.subTest(field=field):
                user = self.make_user(email=field + "@example.com", **{field: True})
                response = self.login(user)
                self.assertEqual(response.status_code, 200)
                self.assertEqual(response.data["user"]["role"], "admin")
                self.client.credentials(HTTP_AUTHORIZATION="Token " + response.data["token"])
                self.assertEqual(self.client.get("/api/dashboard/candidate/").status_code, 403)
                self.client.credentials()

    def test_unverified_email_does_not_receive_authentication_token(self):
        user = self.make_user(email_verified=False)
        self.assertEqual(self.login(user).status_code, 400)
        self.assertFalse(Token.objects.filter(user=user).exists())

    def test_password_change_preserves_spaces_and_revokes_previous_token(self):
        user = self.make_user()
        previous = self.login(user).data["token"]
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {previous}")
        new_password = "  ClaveConEspacios!2026  "
        response = self.client.post("/api/account/password/", {
            "current_password": self.password, "new_password": new_password,
            "new_password_confirm": new_password,
        }, format="json")
        self.assertEqual(response.status_code, 200)
        self.assertFalse(Token.objects.filter(key=previous).exists())
        self.assertEqual(self.client.get("/api/account/").status_code, 401)
        self.client.credentials()
        self.assertEqual(self.login(user, new_password).status_code, 200)
        self.assertEqual(self.login(user, new_password.strip()).status_code, 400)

    def test_password_recovery_revokes_login_and_preserves_preferences(self):
        user = self.make_user(push_notifications=False)
        previous = self.login(user).data["token"]
        request = self.client.post("/api/password-recovery/request/", {"email": user.email}, format="json")
        self.assertEqual(request.status_code, 200)
        link = next(line for line in mail.outbox[-1].body.splitlines() if line.startswith("http"))
        query = parse_qs(urlparse(link).query)
        replacement = "NuevaClaveRecuperada!2026"
        payload = {"uid": query["uid"][0], "token": query["token"][0],
                   "new_password": replacement, "new_password_confirm": replacement}
        response = self.client.post("/api/password-recovery/confirm/", payload, format="json")
        self.assertEqual(response.status_code, 200)
        self.assertFalse(Token.objects.filter(key=previous).exists())
        self.assertEqual(self.client.post("/api/password-recovery/confirm/", payload, format="json").status_code, 400)
        self.assertEqual(self.login(user).status_code, 400)
        token = self.login(user, replacement).data["token"]
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token}")
        self.assertEqual(self.client.get("/api/account/notifications/").data["preferences"], {"push_notifications": False})
        self.assertEqual(self.client.get("/api/dashboard/candidate/").status_code, 200)

    @override_settings(EMAIL_VERIFICATION_TIMEOUT=-1)
    def test_expired_verification_does_not_activate_the_account(self):
        user = self.make_user(email_verified=False)
        response = self.client.get("/api/verify-email/", {"token": create_verification_token(user)})
        self.assertEqual(response.status_code, 400)
        user.refresh_from_db()
        self.assertFalse(user.email_verified)
