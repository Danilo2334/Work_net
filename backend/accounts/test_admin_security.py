"""HU026 security contracts, real protocol, revocation and administration boundaries."""
import time
from datetime import timedelta
from unittest.mock import patch

from django.core import mail
from django.test import override_settings, TransactionTestCase
from django.utils import timezone
from django_otp.oath import totp
from django_otp.plugins.otp_totp.models import TOTPDevice
from rest_framework.authtoken.models import Token
from rest_framework.test import APIClient, APITestCase

from .admin_access import CATALOG, admin_permissions, revoke_admin
from .admin_mfa import recovery_digest
from .models import AdminAccess, AdminChallenge, AdminEvent, AdminMFASession, AdminRecoveryCode, User
from .testing import fixture_token


@override_settings(MAILERS={"default": {"BACKEND": "django.core.mail.backends.locmem.EmailBackend"}},
                   PASSWORD_HASHERS=["django.contrib.auth.hashers.MD5PasswordHasher"])
class AdminSecurityTests(APITestCase):
    password = "SeguridadAdmin!2026"

    def setUp(self):
        self.principal = User.objects.create_superuser("principal@worknet.test", self.password, full_name="Principal QA")
        self.reviewer = User.objects.create_user("revisor@worknet.test", self.password, full_name="Revisor QA", is_staff=True, email_verified=True)
        self.candidate = User.objects.create_user("candidato@worknet.test", self.password, role="candidato", email_verified=True)

    def post(self, path, data):
        return self.client.post("/api/" + path, data, format="json")

    def begin(self, user=None):
        self.client.credentials()
        response = self.post("login/", {"email": (user or self.principal).email, "password": self.password})
        self.assertEqual(response.status_code, 202)
        self.assertNotIn("token", response.data)
        return response.data["challenge"]

    def enroll(self, user=None):
        user = user or self.principal
        challenge = self.begin(user)
        response = self.post("admin/mfa/setup/", {"challenge": challenge})
        self.assertEqual(response.status_code, 200)
        device = TOTPDevice.objects.get(user=user)
        code = f"{totp(device.bin_key):06d}"
        response = self.post("admin/mfa/verify/", {"challenge": challenge, "code": code})
        self.assertEqual(response.status_code, 200, response.data)
        return response, challenge, code

    def use(self, user):
        self.client.credentials(HTTP_AUTHORIZATION="Token " + fixture_token(user).key)

    def test_password_never_issues_admin_token_and_legacy_tokens_cannot_bypass(self):
        old = Token.objects.create(user=self.principal)
        challenge = self.begin()
        self.assertTrue(AdminChallenge.objects.filter(pk=challenge).exists())
        self.client.credentials(HTTP_AUTHORIZATION="Token " + old.key)
        for route in ("dashboard/admin/", "account/", "admin/companies/", "admin/accounts/", "notifications/"):
            self.assertEqual(self.client.get("/api/" + route).status_code, 401, route)

    def test_enrollment_real_totp_rotates_old_token_hashes_recovery_and_one_use_ticket(self):
        old = Token.objects.create(user=self.principal).key
        response, challenge, code = self.enroll()
        self.assertNotEqual(response.data["token"], old)
        self.assertTrue(response.data["user"]["mfa_verified"])
        self.assertEqual(response.data["user"]["administrative_role"], "principal")
        self.assertEqual(len(response.data["recovery_codes"]), 8)
        self.assertFalse(AdminRecoveryCode.objects.filter(digest=response.data["recovery_codes"][0]).exists())
        self.assertEqual(self.post("admin/mfa/verify/", {"challenge": challenge, "code": code}).status_code, 400)
        self.client.credentials(HTTP_AUTHORIZATION="Token " + response.data["token"])
        self.assertEqual(self.client.get("/api/dashboard/admin/").status_code, 200)

    def test_totp_replay_throttles_persist_and_challenge_replaced(self):
        _, _, code = self.enroll()
        challenge = self.begin()
        response = self.post("admin/mfa/verify/", {"challenge": challenge, "code": code})
        self.assertEqual(response.status_code, 400)
        self.assertEqual(AdminChallenge.objects.get(pk=challenge).attempts, 1)
        self.assertEqual(TOTPDevice.objects.get(user=self.principal).throttling_failure_count, 1)
        fresh = self.begin()
        self.assertEqual(self.post("admin/mfa/verify/", {"challenge": challenge, "code": code}).status_code, 400)
        self.assertEqual(TOTPDevice.objects.get(user=self.principal).throttling_failure_count, 1)
        self.assertNotEqual(fresh, challenge)

    def test_expiry_five_invalid_attempts_and_strict_parameters(self):
        challenge = self.begin()
        self.post("admin/mfa/setup/", {"challenge": challenge})
        for _ in range(5):
            self.assertEqual(self.post("admin/mfa/verify/", {"challenge": challenge, "code": "invalid"}).status_code, 400)
        self.assertEqual(AdminChallenge.objects.get(pk=challenge).attempts, 5)
        self.assertEqual(self.post("admin/mfa/setup/", {"challenge": challenge}).status_code, 400)
        challenge = self.begin()
        AdminChallenge.objects.filter(pk=challenge).update(expires_at=timezone.now() - timedelta(seconds=1))
        self.assertEqual(self.post("admin/mfa/setup/", {"challenge": challenge}).status_code, 400)
        for payload in ({"challenge": "bad"}, {"challenge": challenge, "user_id": self.principal.pk}):
            self.assertEqual(self.post("admin/mfa/setup/", payload).status_code, 400)

    def test_confirmed_seed_not_exposed_and_candidate_cannot_enroll(self):
        self.enroll()
        challenge = self.begin()
        self.assertEqual(self.post("admin/mfa/setup/", {"challenge": challenge}).status_code, 409)
        self.client.credentials()
        response = self.post("login/", {"email": self.candidate.email, "password": self.password})
        self.assertEqual(response.status_code, 200)
        self.assertIn("token", response.data)
        self.assertNotIn("mfa_required", response.data)

    def test_recovery_invalid_then_single_use_reenrollment_never_disables_mfa(self):
        response, _, _ = self.enroll()
        old_token = response.data["token"]
        backup = response.data["recovery_codes"][0]
        challenge = self.begin()
        self.assertEqual(self.post("admin/mfa/verify/", {"challenge": challenge, "code": "wrong", "recovery": True}).status_code, 400)
        recovery = self.post("admin/mfa/verify/", {"challenge": challenge, "code": backup, "recovery": True})
        self.assertEqual(recovery.status_code, 202)
        self.assertTrue(recovery.data["enrollment_required"])
        self.assertNotIn("token", recovery.data)
        self.assertFalse(Token.objects.filter(key=old_token).exists())
        self.assertFalse(AdminRecoveryCode.objects.filter(user=self.principal).exists())
        self.assertFalse(TOTPDevice.objects.filter(user=self.principal).exists())
        self.assertEqual(self.post("admin/mfa/verify/", {"challenge": recovery.data["challenge"], "code": backup, "recovery": True}).status_code, 400)
        next_challenge = recovery.data["challenge"]
        self.assertEqual(self.post("admin/mfa/setup/", {"challenge": next_challenge}).status_code, 200)
        replacement = TOTPDevice.objects.get(user=self.principal)
        verified = self.post("admin/mfa/verify/", {"challenge": next_challenge, "code": f"{totp(replacement.bin_key):06d}"})
        self.assertEqual(verified.status_code, 200)
        self.assertNotEqual(verified.data["token"], old_token)
        self.assertNotIn(backup, verified.data["recovery_codes"])

    def test_expired_totp_and_new_ticket_do_not_reset_device_throttling(self):
        challenge = self.begin()
        self.post("admin/mfa/setup/", {"challenge": challenge})
        device = TOTPDevice.objects.get(user=self.principal)
        expired = f"{totp(device.bin_key):06d}"
        with patch("django_otp.plugins.otp_totp.models.time.time", return_value=time.time()+120):
            self.assertEqual(self.post("admin/mfa/verify/", {"challenge": challenge, "code": expired}).status_code, 400)
        device.refresh_from_db()
        self.assertEqual(device.throttling_failure_count, 1)
        fresh = self.begin()
        current = f"{totp(device.bin_key):06d}"
        self.assertEqual(self.post("admin/mfa/verify/", {"challenge": fresh, "code": current}).status_code, 400)
        self.assertFalse(Token.objects.filter(user=self.principal).exists())

    def test_admin_password_recovery_revokes_challenge_and_session_keeps_second_factor(self):
        from urllib.parse import parse_qs, urlparse
        response, _, _ = self.enroll()
        old_token = response.data["token"]
        challenge = self.begin()
        self.assertEqual(self.post("password-recovery/request/", {"email": self.principal.email}).status_code, 200)
        link = next(line for line in mail.outbox[-1].body.splitlines() if line.startswith("http"))
        query = parse_qs(urlparse(link).query)
        replacement = "PasswordReset!2026"
        response = self.post("password-recovery/confirm/", {"uid": query["uid"][0], "token": query["token"][0],
            "new_password": replacement, "new_password_confirm": replacement})
        self.assertEqual(response.status_code, 200)
        self.assertFalse(Token.objects.filter(key=old_token).exists())
        self.assertEqual(self.post("admin/mfa/setup/", {"challenge": challenge}).status_code, 400)
        self.assertTrue(TOTPDevice.objects.get(user=self.principal).confirmed)
        response = self.post("login/", {"email": self.principal.email, "password": replacement})
        self.assertEqual(response.status_code, 202)
        self.assertFalse(response.data["enrollment_required"])

    def test_password_changes_revoke_tickets_api_cookie_keep_device_and_require_two_factors(self):
        response, _, _ = self.enroll()
        challenge = self.begin()
        self.client.credentials(HTTP_AUTHORIZATION="Token " + response.data["token"])
        response = self.post("account/password/", {"current_password": self.password,
            "new_password": "NuevaClave!2026", "new_password_confirm": "NuevaClave!2026"})
        self.assertEqual(response.status_code, 401)
        self.assertNotIn("token", response.data)
        self.assertFalse(Token.objects.filter(user=self.principal).exists())
        self.assertEqual(self.post("admin/mfa/setup/", {"challenge": challenge}).status_code, 400)
        self.assertTrue(TOTPDevice.objects.get(user=self.principal).confirmed)

    def test_expired_or_revision_mismatch_grant_fails_in_all_explicit_auth_classes(self):
        self.use(self.principal)
        grant = AdminMFASession.objects.get(token__user=self.principal)
        grant.expires_at = timezone.now() - timedelta(seconds=1)
        grant.save()
        for route in ("account/", "dashboard/admin/", "dashboard/candidate/", "profile/candidate/",
                      "offers/search/", "offers/saved/", "curriculum/"):
            self.assertEqual(self.client.get("/api/" + route).status_code, 401, route)
        self.use(self.principal)
        User.objects.filter(pk=self.principal.pk).update(admin_revision=1)
        self.assertEqual(self.client.get("/api/account/").status_code, 401)

    def test_principal_create_email_validation_no_escalation_or_password_in_response(self):
        self.use(self.principal)
        response = self.post("admin/accounts/", {"full_name": "Gestora QA", "email": "gestora@worknet.test",
            "password": self.password, "administrative_role": "gestor", "permissions": ["dashboard", "manage_admins"]})
        self.assertEqual(response.status_code, 201, response.data)
        user = User.objects.get(email="gestora@worknet.test")
        self.assertFalse(user.email_verified)
        self.assertTrue(user.is_staff)
        self.assertFalse(user.is_superuser)
        self.assertEqual(len(mail.outbox), 1)
        self.assertNotIn("password", response.data["administrator"])
        duplicate = self.post("admin/accounts/", {"full_name": "X", "email": user.email.upper(), "password": self.password, "administrative_role": "revisor"})
        self.assertEqual(duplicate.status_code, 400)
        self.use(self.reviewer)
        self.assertEqual(self.post("admin/accounts/", {"full_name": "X", "email": "x@worknet.test", "password": self.password, "administrative_role": "revisor"}).status_code, 403)

    def test_create_strict_roles_permissions_and_mail_failure_rolls_back(self):
        self.use(self.principal)
        base = {"full_name": "X", "email": "x@worknet.test", "password": self.password, "administrative_role": "revisor"}
        for change in ({"is_superuser": True}, {"administrative_role": "principal"}, {"permissions": ["manage_permissions"]}, {"password": "123"}, {"permissions": ["dashboard", "dashboard"]}):
            self.assertEqual(self.post("admin/accounts/", {**base, **change}).status_code, 400)
        with patch("accounts.admin_accounts.send_verification_email", side_effect=OSError("mail offline")):
            self.assertEqual(self.post("admin/accounts/", base).status_code, 503)
        self.assertFalse(User.objects.filter(email=base["email"]).exists())

    def test_listing_has_minimum_fields_stable_pagination_and_private_cache(self):
        self.use(self.principal)
        response = self.client.get("/api/admin/accounts/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["count"], 2)
        self.assertTrue({"full_name", "email", "administrative_role", "is_active", "permissions", "version"} <= set(response.data["results"][0]))
        self.assertIn("no-store", response["Cache-Control"])
        for query in ("page=0", "page=-1", "page=x", "page=2", "page=1&page=1", "is_staff=true", "page=" + "9"*5000):
            self.assertEqual(self.client.get("/api/admin/accounts/?" + query).status_code, 400)
        self.use(self.candidate)
        self.assertEqual(self.client.get("/api/admin/accounts/").status_code, 403)

    def update_admin(self, target, data):
        return self.client.patch(f"/api/admin/accounts/{target.pk}/", {"version": 0, **data}, format="json")

    def test_permission_revocation_deactivation_reactivation_sessions_and_conflict(self):
        old = fixture_token(self.reviewer).key
        self.use(self.principal)
        response = self.update_admin(self.reviewer, {"permissions": ["dashboard"]})
        self.assertEqual(response.status_code, 200)
        self.assertFalse(Token.objects.filter(key=old).exists())
        self.assertEqual(self.update_admin(self.reviewer, {"is_active": False}).status_code, 409)
        self.assertEqual(self.update_admin(self.reviewer, {"is_active": False, "version": 1}).status_code, 200)
        self.assertEqual(self.update_admin(self.reviewer, {"is_active": True, "version": 2}).status_code, 200)
        self.use(self.reviewer)
        self.assertEqual(self.client.get("/api/dashboard/admin/").status_code, 200)
        self.assertEqual(self.client.get("/api/admin/companies/").status_code, 403)
        self.assertEqual(self.client.get("/api/admin/events/").status_code, 403)

    def test_cannot_self_escalate_modify_primary_or_promote_candidate(self):
        self.use(self.principal)
        self.assertEqual(self.update_admin(self.principal, {"is_active": False}).status_code, 403)
        self.assertEqual(self.update_admin(self.candidate, {"is_active": True}).status_code, 404)
        self.assertEqual(self.client.delete("/api/account/delete/", {"current_password": self.password, "confirmation": True}, format="json").status_code, 403)
        AdminAccess.objects.create(user=self.reviewer, role="gestor", permissions=["dashboard", "manage_permissions"])
        self.use(self.reviewer)
        self.assertEqual(self.update_admin(self.principal, {"permissions": []}).status_code, 403)
        self.assertEqual(self.update_admin(self.reviewer, {"permissions": list(CATALOG)}).status_code, 403)
        other = User.objects.create_user("other@worknet.test", self.password, is_staff=True, email_verified=True)
        self.assertEqual(self.update_admin(other, {"permissions": ["dashboard", "review_companies"]}).status_code, 403)
        self.assertEqual(self.update_admin(other, {"permissions": ["dashboard"]}).status_code, 200)
        self.assertEqual(self.update_admin(other, {"is_active": False, "version": 1}).status_code, 403)

    def test_account_manager_can_deactivate_without_conceding_unchanged_permissions(self):
        manager = User.objects.create_user("gestor@worknet.test", self.password, is_staff=True, email_verified=True)
        AdminAccess.objects.create(user=manager, role="gestor", permissions=["manage_admins"])
        self.use(manager)
        response = self.update_admin(self.reviewer, {"full_name": "Revisora actualizada", "is_active": False})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["administrator"]["permissions"], ["dashboard", "review_companies", "view_events"])
        self.assertEqual(self.update_admin(self.reviewer, {"permissions": [], "version": 1}).status_code, 403)

    def test_django_admin_password_only_cookie_and_api_cookie_bypass_are_denied(self):
        from django.test import Client
        browser = Client()
        self.assertTrue(browser.login(email=self.principal.email, password=self.password))
        self.assertEqual(browser.get("/admin/").status_code, 302)

        response = browser.post("/admin/login/?next=/admin/", {"username": self.principal.email, "password": self.password})
        self.assertEqual(response.status_code, 200)
        self.assertFalse(browser.session.get("otp_device_id"))
        self.assertEqual(browser.get("/api/dashboard/admin/").status_code, 401)
        # A real OTP-enabled form authenticates the principal; no raw model CRUD is routed.
        TOTPDevice.objects.create(user=self.principal, name="WorkNet", confirmed=True)
        device = TOTPDevice.objects.get(user=self.principal)
        browser.logout()
        response = browser.post("/admin/login/?next=/admin/", {"username": self.principal.email,
            "password": self.password, "otp_device": device.persistent_id, "otp_token": f"{totp(device.bin_key):06d}"})
        self.assertEqual(response.status_code, 302, response.context["form"].errors if response.status_code == 200 else "")
        self.assertEqual(browser.get("/admin/").status_code, 200)
        self.assertEqual(browser.get("/admin/otp_totp/totpdevice/").status_code, 404)
        User.objects.filter(pk=self.principal.pk).update(admin_revision=1)
        self.assertEqual(browser.get("/admin/").status_code, 302)


@override_settings(PASSWORD_HASHERS=["django.contrib.auth.hashers.MD5PasswordHasher"])
class AdminConcurrencyTests(TransactionTestCase):
    def race(self, payload):
        from concurrent.futures import ThreadPoolExecutor
        from threading import Barrier
        from django.db import close_old_connections
        barrier = Barrier(2)
        def verify(_):
            close_old_connections()
            try:
                barrier.wait(timeout=10)
                response = APIClient().post("/api/admin/mfa/verify/", payload, format="json")
                return response.status_code
            finally:
                close_old_connections()
        with ThreadPoolExecutor(2) as pool:
            return list(pool.map(verify, range(2)))

    def prepare(self):
        user = User.objects.create_superuser("concurrencia@worknet.test", "Concurrency!2026")
        device = TOTPDevice.objects.create(user=user, name="WorkNet", confirmed=True)
        challenge = AdminChallenge.objects.create(user=user, password_hash=user.get_session_auth_hash(),
            revision=user.admin_revision, expires_at=timezone.now() + timedelta(minutes=5))
        return user, device, challenge

    def test_same_totp_and_challenge_only_one_grant_with_controlled_loser(self):
        user, device, challenge = self.prepare()
        statuses = self.race({"challenge": str(challenge.pk), "code": f"{totp(device.bin_key):06d}"})
        self.assertEqual(statuses.count(200), 1, statuses)
        self.assertTrue(set(statuses) <= {200, 400, 503}, statuses)
        self.assertEqual(Token.objects.filter(user=user).count(), 1)
        self.assertEqual(AdminMFASession.objects.filter(token__user=user).count(), 1)
        self.assertTrue(AdminChallenge.objects.get(pk=challenge.pk).consumed)

    def test_same_recovery_one_reenrollment_ticket_and_no_session(self):
        user, device, challenge = self.prepare()
        code = "a" * 32
        AdminRecoveryCode.objects.create(user=user, digest=recovery_digest(code))
        statuses = self.race({"challenge": str(challenge.pk), "code": code, "recovery": True})
        self.assertEqual(statuses.count(202), 1, statuses)
        self.assertTrue(set(statuses) <= {202, 400, 503}, statuses)
        self.assertFalse(Token.objects.filter(user=user).exists())
        self.assertFalse(AdminRecoveryCode.objects.filter(user=user).exists())
        self.assertEqual(AdminChallenge.objects.filter(user=user, consumed=False).count(), 1)

    def test_same_crud_version_one_save_and_controlled_conflict(self):
        from concurrent.futures import ThreadPoolExecutor
        from threading import Barrier
        from django.db import close_old_connections
        user, _, _ = self.prepare()
        token = fixture_token(user).key
        target = User.objects.create_user("destino@worknet.test", "Target!2026", is_staff=True, email_verified=True)
        barrier = Barrier(2)
        def save(name):
            close_old_connections()
            try:
                client = APIClient()
                client.credentials(HTTP_AUTHORIZATION="Token " + token)
                barrier.wait(timeout=10)
                return client.patch(f"/api/admin/accounts/{target.pk}/", {"version": 0, "full_name": name}, format="json").status_code
            finally:
                close_old_connections()
        with ThreadPoolExecutor(2) as pool:
            statuses = list(pool.map(save, ["Nombre A", "Nombre B"]))
        self.assertEqual(statuses.count(200), 1, statuses)
        self.assertTrue(set(statuses) <= {200, 409, 503}, statuses)
        self.assertEqual(AdminAccess.objects.get(user=target).version, 1)
