from urllib.parse import parse_qs, urlparse

from django.core import mail
from django.test import TestCase, override_settings
from rest_framework.test import APIClient

from .models import User


@override_settings(MAILERS={"default": {
    "BACKEND": "django.core.mail.backends.locmem.EmailBackend"
}})
class PasswordRecoveryTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(
            email="persona@example.com", password="Original-Secret-472!",
            full_name="Persona Ejemplo", role="candidato",
        )

    def request_reset(self):
        response = self.client.post("/api/password-recovery/request/", {
            "email": " PERSONA@EXAMPLE.COM "
        }, format="json")
        self.assertEqual(response.status_code, 200)
        link = next(line for line in mail.outbox[-1].body.splitlines()
                    if line.startswith("http"))
        query = parse_qs(urlparse(link).query)
        return {"uid": query["uid"][0], "token": query["token"][0],
                "new_password": "Replacement-Secret-839!",
                "new_password_confirm": "Replacement-Secret-839!"}

    def test_reset_and_token_reuse(self):
        payload = self.request_reset()
        self.assertEqual(mail.outbox[0].to, [self.user.email])
        response = self.client.post("/api/password-recovery/confirm/", payload)
        self.assertEqual(response.status_code, 200)
        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password(payload["new_password"]))
        self.assertFalse(self.user.check_password("Original-Secret-472!"))
        self.assertEqual(self.client.post(
            "/api/password-recovery/confirm/", payload
        ).status_code, 400)

    def test_unknown_email_has_same_response(self):
        known = self.client.post("/api/password-recovery/request/", {
            "email": self.user.email
        })
        unknown = self.client.post("/api/password-recovery/request/", {
            "email": "unknown@example.com"
        })
        self.assertEqual(known.data, unknown.data)
        self.assertEqual(unknown.status_code, 200)
        self.assertEqual(len(mail.outbox), 1)

    def test_invalid_reset_data_does_not_change_password(self):
        payload = self.request_reset()
        for changes in (
            {"uid": "invalid"}, {"token": "invalid"},
            {"new_password_confirm": "different"},
            {"new_password": "123", "new_password_confirm": "123"},
        ):
            with self.subTest(changes=changes):
                response = self.client.post(
                    "/api/password-recovery/confirm/", {**payload, **changes}
                )
                self.assertEqual(response.status_code, 400)
        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password("Original-Secret-472!"))

    @override_settings(PASSWORD_RESET_TIMEOUT=-1)
    def test_expired_token(self):
        payload = self.request_reset()
        self.assertEqual(self.client.post(
            "/api/password-recovery/confirm/", payload
        ).status_code, 400)

    def test_invalid_email(self):
        self.assertEqual(self.client.post(
            "/api/password-recovery/request/", {"email": "invalid"}
        ).status_code, 400)
