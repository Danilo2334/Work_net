from django.test import override_settings
from rest_framework.authtoken.models import Token
from rest_framework.test import APIClient, APITestCase

from .models import User
from .notification_preferences import NotificationPreferencesSerializer


@override_settings(PASSWORD_HASHERS=["django.contrib.auth.hashers.MD5PasswordHasher"])
class NotificationPreferencesTests(APITestCase):
    url = "/api/account/notifications/"
    password = "PruebaCuenta!2026"

    def setUp(self):
        self.user = User.objects.create_user(
            email="danilo@example.com", password=self.password,
            full_name="Danilo Carlosama", role="candidato", email_verified=True,
        )
        self.other = User.objects.create_user(
            email="empresa@example.com", password=self.password,
            full_name="Empresa de prueba", role="empresa", email_verified=True,
        )
        self.token = Token.objects.create(user=self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {self.token.key}")

    def test_initial_preferences_match_the_flutter_switch(self):
        response = self.client.get(self.url)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data, {"preferences": {"push_notifications": True}})

    def test_disabled_preference_persists_for_a_new_request_and_client(self):
        response = self.client.patch(self.url, {"push_notifications": False}, format="json")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["preferences"], {"push_notifications": False})
        self.user.refresh_from_db()
        self.assertFalse(self.user.push_notifications)
        fresh_client = APIClient()
        fresh_client.credentials(HTTP_AUTHORIZATION=f"Token {self.token.key}")
        self.assertEqual(fresh_client.get(self.url).data["preferences"], {"push_notifications": False})

    def test_notifications_can_be_enabled_again(self):
        self.user.push_notifications = False
        self.user.save(update_fields=["push_notifications"])
        response = self.client.patch(self.url, {"push_notifications": True}, format="json")
        self.assertEqual(response.status_code, 200)
        self.user.refresh_from_db()
        self.assertTrue(self.user.push_notifications)

    def test_repeating_the_same_preference_is_valid(self):
        for _ in range(2):
            self.assertEqual(self.client.patch(
                self.url, {"push_notifications": False}, format="json"
            ).status_code, 200)
        self.assertFalse(self.client.get(self.url).data["preferences"]["push_notifications"])

    def test_preferences_are_isolated_between_candidate_and_company(self):
        self.client.patch(self.url, {"push_notifications": False}, format="json")
        company_token = Token.objects.create(user=self.other)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {company_token.key}")
        self.assertTrue(self.client.get(self.url).data["preferences"]["push_notifications"])
        response = self.client.patch(self.url, {"push_notifications": False}, format="json")
        self.assertEqual(response.status_code, 200)
        self.other.refresh_from_db()
        self.assertFalse(self.other.push_notifications)

    def test_only_json_booleans_are_accepted_without_saving_invalid_values(self):
        for value in ("true", "false", "", 0, 1, None, [], {}):
            with self.subTest(value=value):
                response = self.client.patch(self.url, {"push_notifications": value}, format="json")
                self.assertEqual(response.status_code, 400)
                self.user.refresh_from_db()
                self.assertTrue(self.user.push_notifications)

    def test_empty_or_non_object_payload_is_rejected(self):
        for data in ({}, [], "texto"):
            with self.subTest(data=data):
                self.assertEqual(self.client.patch(self.url, data, format="json").status_code, 400)

    def test_foreign_ids_and_account_fields_are_rejected_without_partial_save(self):
        for field, value in {
            "user_id": self.other.pk, "id": self.other.pk, "role": "empresa",
            "is_superuser": True, "email": "otro@example.com", "full_name": "Otro nombre",
        }.items():
            with self.subTest(field=field):
                response = self.client.patch(
                    self.url, {"push_notifications": False, field: value}, format="json"
                )
                self.assertEqual(response.status_code, 400)
                self.user.refresh_from_db()
                self.other.refresh_from_db()
                self.assertTrue(self.user.push_notifications)
                self.assertTrue(self.other.push_notifications)

    def test_both_methods_require_a_token(self):
        self.client.credentials()
        self.assertEqual(self.client.get(self.url).status_code, 401)
        self.assertEqual(self.client.patch(self.url, {"push_notifications": False}, format="json").status_code, 401)

    def test_invalid_token_is_rejected(self):
        self.client.credentials(HTTP_AUTHORIZATION="Token invalido")
        self.assertEqual(self.client.get(self.url).status_code, 401)

    def test_inactive_user_cannot_change_preferences(self):
        User.objects.filter(pk=self.user.pk).update(is_active=False)
        self.assertEqual(self.client.patch(
            self.url, {"push_notifications": False}, format="json"
        ).status_code, 401)
        self.user.refresh_from_db()
        self.assertTrue(self.user.push_notifications)

    def test_updating_preferences_preserves_account_and_token(self):
        self.client.patch(self.url, {"push_notifications": False}, format="json")
        self.user.refresh_from_db()
        self.assertEqual(self.user.full_name, "Danilo Carlosama")
        self.assertEqual(self.user.email, "danilo@example.com")
        self.assertEqual(self.user.role, "candidato")
        self.assertTrue(self.user.email_verified)
        self.assertTrue(self.user.check_password(self.password))
        self.assertTrue(Token.objects.filter(pk=self.token.key).exists())
        self.assertEqual(self.client.get("/api/account/").status_code, 200)

    def test_stale_preference_update_does_not_restore_old_name_or_password(self):
        stale_user = User.objects.get(pk=self.user.pk)
        self.user.full_name = "Nombre actualizado"
        self.user.set_password("NuevaClaveSegura!739")
        self.user.save(update_fields=["full_name", "password"])
        serializer = NotificationPreferencesSerializer(stale_user, data={"push_notifications": False})
        self.assertTrue(serializer.is_valid())
        serializer.save()
        self.user.refresh_from_db()
        self.assertEqual(self.user.full_name, "Nombre actualizado")
        self.assertTrue(self.user.check_password("NuevaClaveSegura!739"))
        self.assertFalse(self.user.push_notifications)

    def test_unsupported_methods_do_not_delete_or_modify_the_account(self):
        self.assertEqual(self.client.delete(self.url).status_code, 405)
        self.assertEqual(self.client.post(self.url, {"push_notifications": False}, format="json").status_code, 405)
        self.assertTrue(User.objects.filter(pk=self.user.pk).exists())

    def test_deleting_account_revokes_access_to_preferences(self):
        response = self.client.delete(
            "/api/account/delete/", {"current_password": self.password, "confirmation": True}, format="json"
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(self.client.get(self.url).status_code, 401)
