from django.test import override_settings
from rest_framework.authtoken.models import Token
from rest_framework.test import APITestCase

from .account_configuration import AccountSerializer
from .models import User


@override_settings(PASSWORD_HASHERS=["django.contrib.auth.hashers.MD5PasswordHasher"])
class AccountConfigurationTests(APITestCase):
    password = "PruebaCuenta!2026"
    new_password = "NuevaClaveSegura!739"

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

    def password_data(self, **overrides):
        data = {
            "current_password": self.password,
            "new_password": self.new_password,
            "new_password_confirm": self.new_password,
        }
        data.update(overrides)
        return data

    def test_login_returns_token_and_preserves_existing_user_response(self):
        self.client.credentials()
        response = self.client.post(
            "/api/login/", {"email": self.user.email, "password": self.password}, format="json"
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["token"], self.token.key)
        self.assertEqual(response.data["user"]["role"], "candidato")
        self.assertNotIn("password", response.data["user"])

    def test_login_rejects_unverified_user_without_issuing_token(self):
        self.client.credentials()
        self.other.email_verified = False
        self.other.save(update_fields=["email_verified"])
        response = self.client.post(
            "/api/login/", {"email": self.other.email, "password": self.password}, format="json"
        )
        self.assertEqual(response.status_code, 400)
        self.assertFalse(Token.objects.filter(user=self.other).exists())

    def test_login_rejects_wrong_password(self):
        self.client.credentials()
        response = self.client.post(
            "/api/login/", {"email": self.other.email, "password": "incorrecta"}, format="json"
        )
        self.assertEqual(response.status_code, 400)
        self.assertFalse(Token.objects.filter(user=self.other).exists())

    def test_all_account_endpoints_require_authentication(self):
        self.client.credentials()
        for method, url in (
            ("get", "/api/account/"), ("patch", "/api/account/"),
            ("post", "/api/account/password/"), ("delete", "/api/account/delete/"),
        ):
            with self.subTest(method=method, url=url):
                self.assertEqual(getattr(self.client, method)(url).status_code, 401)

    def test_invalid_token_is_rejected(self):
        self.client.credentials(HTTP_AUTHORIZATION="Token token-invalido")
        self.assertEqual(self.client.get("/api/account/").status_code, 401)

    def test_profile_contains_email_but_no_password_or_admin_flags(self):
        response = self.client.get("/api/account/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(set(response.data["user"]), {
            "id", "full_name", "email", "role", "email_verified"
        })
        self.assertEqual(response.data["user"]["email"], self.user.email)

    def test_name_update_only_changes_authenticated_user(self):
        response = self.client.patch("/api/account/", {"full_name": "Danilo Actualizado"}, format="json")
        self.assertEqual(response.status_code, 200)
        self.user.refresh_from_db()
        self.other.refresh_from_db()
        self.assertEqual(self.user.full_name, "Danilo Actualizado")
        self.assertEqual(self.other.full_name, "Empresa de prueba")
        self.assertEqual(self.user.role, "candidato")
        self.assertTrue(Token.objects.filter(pk=self.token.key).exists())

    def test_invalid_name_or_empty_update_is_rejected(self):
        for data in ({}, {"full_name": "   "}, {"full_name": "a" * 151}, {"full_name": None}):
            with self.subTest(data=data):
                self.assertEqual(self.client.patch("/api/account/", data, format="json").status_code, 400)
        self.user.refresh_from_db()
        self.assertEqual(self.user.full_name, "Danilo Carlosama")

    def test_profile_rejects_role_email_privileges_and_other_user_ids(self):
        for field, value in {
            "id": self.other.pk, "user_id": self.other.pk, "email": "nuevo@example.com",
            "role": "empresa", "email_verified": True, "is_staff": True,
            "is_superuser": True, "password": self.new_password,
        }.items():
            with self.subTest(field=field):
                response = self.client.patch(
                    "/api/account/", {"full_name": "No guardar", field: value}, format="json"
                )
                self.assertEqual(response.status_code, 400)
        self.user.refresh_from_db()
        self.assertEqual(self.user.full_name, "Danilo Carlosama")
        self.assertFalse(self.user.is_superuser)

    def test_password_change_validates_current_password(self):
        response = self.client.post(
            "/api/account/password/", self.password_data(current_password="incorrecta"), format="json"
        )
        self.assertEqual(response.status_code, 400)
        self.assertIn("current_password", response.data["errors"])
        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password(self.password))
        self.assertTrue(Token.objects.filter(pk=self.token.key).exists())

    def test_password_change_rejects_mismatch(self):
        response = self.client.post(
            "/api/account/password/", self.password_data(new_password_confirm="otra"), format="json"
        )
        self.assertEqual(response.status_code, 400)
        self.assertIn("new_password_confirm", response.data["errors"])

    def test_password_change_rejects_weak_passwords_and_reused_password(self):
        for value in ("123", "123456789", self.password):
            with self.subTest(password=value):
                response = self.client.post(
                    "/api/account/password/",
                    self.password_data(new_password=value, new_password_confirm=value), format="json",
                )
                self.assertEqual(response.status_code, 400)

    def test_password_change_rejects_missing_confirmation_and_extra_user_id(self):
        data = self.password_data()
        data.pop("new_password_confirm")
        self.assertEqual(self.client.post("/api/account/password/", data, format="json").status_code, 400)
        data = self.password_data(user_id=self.other.pk)
        self.assertEqual(self.client.post("/api/account/password/", data, format="json").status_code, 400)

    def test_password_change_hashes_password_and_rotates_token(self):
        response = self.client.post("/api/account/password/", self.password_data(), format="json")
        self.assertEqual(response.status_code, 200)
        new_token = response.data["token"]
        self.assertNotEqual(new_token, self.token.key)
        self.user.refresh_from_db()
        self.other.refresh_from_db()
        self.assertTrue(self.user.check_password(self.new_password))
        self.assertFalse(self.user.check_password(self.password))
        self.assertNotEqual(self.user.password, self.new_password)
        self.assertTrue(self.other.check_password(self.password))
        self.assertEqual(self.client.get("/api/account/").status_code, 401)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {new_token}")
        self.assertEqual(self.client.get("/api/account/").status_code, 200)
        self.client.credentials()
        self.assertEqual(self.client.post(
            "/api/login/", {"email": self.user.email, "password": self.password}, format="json"
        ).status_code, 400)
        self.assertEqual(self.client.post(
            "/api/login/", {"email": self.user.email, "password": self.new_password}, format="json"
        ).status_code, 200)

    def test_delete_requires_explicit_boolean_confirmation_and_password(self):
        invalid_payloads = [
            {"current_password": self.password}, {"confirmation": True},
            {"current_password": self.password, "confirmation": False},
            {"current_password": self.password, "confirmation": "true"},
            {"current_password": self.password, "confirmation": 1},
            {"current_password": "incorrecta", "confirmation": True},
            {"current_password": self.password, "confirmation": True, "user_id": self.other.pk},
        ]
        for data in invalid_payloads:
            with self.subTest(data=data):
                response = self.client.delete("/api/account/delete/", data, format="json")
                self.assertEqual(response.status_code, 400)
                self.assertTrue(User.objects.filter(pk=self.user.pk).exists())

    def test_new_password_with_spaces_can_be_used_to_login(self):
        password = "  NuevaClaveSegura!739  "
        response = self.client.post(
            "/api/account/password/",
            self.password_data(new_password=password, new_password_confirm=password),
            format="json",
        )
        self.assertEqual(response.status_code, 200)
        self.client.credentials()
        response = self.client.post(
            "/api/login/", {"email": self.user.email, "password": password}, format="json"
        )
        self.assertEqual(response.status_code, 200)

    def test_delete_removes_own_account_and_revokes_access(self):
        response = self.client.delete(
            "/api/account/delete/", {"current_password": self.password, "confirmation": True}, format="json"
        )
        self.assertEqual(response.status_code, 200)
        self.assertFalse(User.objects.filter(pk=self.user.pk).exists())
        self.assertTrue(User.objects.filter(pk=self.other.pk).exists())
        self.assertFalse(Token.objects.filter(pk=self.token.key).exists())
        self.assertEqual(self.client.get("/api/account/").status_code, 401)
        self.client.credentials()
        self.assertEqual(self.client.post(
            "/api/login/", {"email": self.user.email, "password": self.password}, format="json"
        ).status_code, 400)

    def test_get_cannot_delete_account(self):
        self.assertEqual(self.client.get("/api/account/delete/").status_code, 405)
        self.assertTrue(User.objects.filter(pk=self.user.pk).exists())

    def test_password_reset_outside_hu004_also_revokes_token(self):
        # HU003 y el administrador usan el mismo set_password()/save().
        self.user.set_password(self.new_password)
        self.user.save(update_fields=["password"])
        self.assertFalse(Token.objects.filter(pk=self.token.key).exists())
        self.assertEqual(self.client.get("/api/account/").status_code, 401)

    def test_disabling_user_revokes_token(self):
        self.user.is_active = False
        self.user.save(update_fields=["is_active"])
        self.assertFalse(Token.objects.filter(pk=self.token.key).exists())
        self.assertEqual(self.client.get("/api/account/").status_code, 401)

    def test_profile_update_does_not_restore_a_stale_password(self):
        stale_user = User.objects.get(pk=self.user.pk)
        self.user.set_password(self.new_password)
        self.user.save(update_fields=["password"])
        serializer = AccountSerializer(stale_user, data={"full_name": "Nuevo nombre"}, partial=True)
        self.assertTrue(serializer.is_valid())
        serializer.save()
        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password(self.new_password))

    def test_company_role_can_configure_own_account(self):
        token = Token.objects.create(user=self.other)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")
        self.assertEqual(self.client.get("/api/account/").data["user"]["role"], "empresa")
        self.assertEqual(self.client.patch(
            "/api/account/", {"full_name": "Empresa Actualizada"}, format="json"
        ).status_code, 200)
        self.user.refresh_from_db()
        self.assertEqual(self.user.full_name, "Danilo Carlosama")

    def test_registration_endpoint_still_validates_duplicate_email(self):
        self.client.credentials()
        data = {
            "full_name": "Usuario Nuevo", "email": "nuevo@example.com", "role": "candidato",
            "password": self.password, "password_confirm": self.password,
        }
        self.assertEqual(self.client.post("/api/register/", data, format="json").status_code, 201)
        self.assertEqual(self.client.post("/api/register/", data, format="json").status_code, 400)
