"""Business flow and permissions against a disposable Django test database."""
from smtplib import SMTPException
from unittest.mock import patch

from django.core import signing
from django.test import TestCase
from django.test import override_settings
from django.core.files.uploadedfile import SimpleUploadedFile
from io import BytesIO
from PIL import Image
from rest_framework.authtoken.models import Token
from rest_framework.test import APIClient

from candidate_dashboard.models import Application, JobOffer, Notification
from .models import CompanyProfile, CompanyReview, User


@override_settings(PASSWORD_HASHERS=["django.contrib.auth.hashers.MD5PasswordHasher"])
class CompanyAccessTests(TestCase):
    password = "PruebaAislada!42"
    fields = {"legal_name": "Organización ficticia QA", "tax_id": "900123456-7", "sector": "Tecnología", "location": "Pasto", "contact_email": "contacto@worknet.test", "description": "Organización ficticia para pruebas."}

    def setUp(self):
        self.company = User.objects.create_user("empresa@worknet.test", self.password, role="empresa", email_verified=True, full_name="Empresa QA")
        self.other = User.objects.create_user("otra@worknet.test", self.password, role="empresa", email_verified=True)
        self.candidate = User.objects.create_user("candidato@worknet.test", self.password, role="candidato", email_verified=True)
        self.admin = User.objects.create_user("admin@worknet.test", self.password, is_staff=True, email_verified=True)
        self.client = APIClient()
        self.use(self.company)

    def use(self, user):
        self.client.credentials(HTTP_AUTHORIZATION="Token " + Token.objects.get_or_create(user=user)[0].key)

    def submit(self):
        saved = self.client.patch("/api/company/", self.fields, format="json")
        self.assertEqual(saved.status_code, 200, saved.data)
        response = self.client.post("/api/company/submit/")
        self.assertEqual(response.status_code, 200, response.data)
        return response.data["company"]

    def decide(self, info, decision="approved", **extra):
        self.use(self.admin)
        return self.client.post(f"/api/admin/companies/{info['id']}/review/", {"decision": decision, "version": info["version"], **extra}, format="json")

    def test_initial_pending_is_not_submitted_or_accessible(self):
        info = self.client.get("/api/company/").data["company"]
        self.assertEqual(info["state"], "pending")
        self.assertFalse(info["submitted"])
        self.assertEqual(self.client.get("/api/dashboard/company/").status_code, 403)
        self.assertEqual(self.client.post("/api/company/submit/").status_code, 400)

    def test_required_fields_email_and_tax_id(self):
        for data in ({"contact_email": "no-correo"}, {"tax_id": "abc"}, {"legal_name": " "}, {"state": "approved"}, {"company": self.other.pk}):
            with self.subTest(data=data):
                self.assertEqual(self.client.patch("/api/company/", data, format="json").status_code, 400)

    def test_owner_persistence_and_unique_tax_id(self):
        self.submit()
        self.assertEqual(self.client.get("/api/company/").data["company"]["tax_id"], self.fields["tax_id"])
        self.use(self.other)
        self.assertEqual(self.client.get("/api/company/").data["company"]["legal_name"], "")
        self.assertEqual(self.client.patch("/api/company/", self.fields, format="json").status_code, 400)

    def test_only_admin_can_review_and_company_cannot_self_approve(self):
        info = self.submit()
        for user in (self.company, self.other, self.candidate):
            self.use(user)
            self.assertEqual(self.client.get("/api/admin/companies/").status_code, 403)
            self.assertEqual(self.client.post(f"/api/admin/companies/{info['id']}/review/", {"decision": "approved", "version": info["version"]}, format="json").status_code, 403)

    def test_rejection_requires_reason_then_correction_and_resubmission(self):
        info = self.submit()
        self.assertEqual(self.decide(info, "rejected").status_code, 400)
        response = self.decide(info, "rejected", reason="Corrige la razón social.")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["company"]["reviewed_by"], self.admin.pk)
        self.use(self.company)
        rejected = self.client.get("/api/company/").data["company"]
        self.assertEqual(rejected["state"], "rejected")
        self.assertEqual(rejected["rejection_reason"], "Corrige la razón social.")
        self.assertEqual(self.client.patch("/api/company/", {"legal_name": "Razón social corregida QA"}, format="json").status_code, 200)
        resent = self.client.post("/api/company/submit/")
        self.assertEqual(resent.status_code, 200)
        self.assertEqual(resent.data["company"]["state"], "pending")
        self.assertEqual(CompanyReview.objects.count(), 3)

    def test_approval_unlocks_company_dashboard_and_login_state(self):
        info = self.submit()
        self.assertEqual(self.decide(info).status_code, 200)
        self.use(self.company)
        self.assertEqual(self.client.get("/api/dashboard/company/").status_code, 200)
        login = self.client.post("/api/login/", {"email": self.company.email, "password": self.password}, format="json")
        self.assertEqual(login.data["user"]["company_state"], "approved")
        self.assertEqual(self.client.patch("/api/company/", {"legal_name": "Cambiar sin revisión"}, format="json").status_code, 400)
        self.assertEqual(self.client.patch("/api/company/", {"website": "https://example.org"}, format="json").status_code, 200)

    def test_submission_locked_until_review_and_stale_decision_conflicts(self):
        info = self.submit()
        self.assertEqual(self.client.post("/api/company/submit/").status_code, 400)
        self.assertEqual(self.client.patch("/api/company/", {"legal_name": "Otro"}, format="json").status_code, 400)
        self.assertEqual(self.decide(info).status_code, 200)
        self.assertEqual(self.decide(info, "rejected", reason="Decisión vieja").status_code, 409)

    def test_notices_pending_list_and_audit_event(self):
        info = self.submit()
        self.use(self.admin)
        dashboard = self.client.get("/api/dashboard/admin/").data
        self.assertEqual(dashboard["metrics"], {"candidates": 1, "companies": 2, "pending_companies": 1})
        self.assertEqual(len(dashboard["notifications"]), 1)
        self.assertEqual(dashboard["recent_events"][0]["action"], "submitted")
        listing = self.client.get("/api/admin/companies/").data
        self.assertEqual(listing["companies"][0]["id"], info["id"])
        self.assertEqual(self.client.get("/api/admin/companies/?page=invalida").status_code, 400)
        self.decide(info)
        self.assertTrue(Notification.objects.filter(recipient=self.company).exists())
        self.assertEqual(self.client.get("/api/admin/companies/").data["count"], 0)

    def test_company_summary_scoped_to_own_offers_and_applications(self):
        info = self.submit()
        self.decide(info)
        offer = JobOffer.objects.create(company=self.company, title="Oferta QA", company_name="QA", location="Pasto", contract_type="Indefinido", status="published")
        Application.objects.create(candidate=self.candidate, offer=offer)
        JobOffer.objects.create(company=self.other, title="Ajena", company_name="Otra", location="Pasto", contract_type="Indefinido", status="closed")
        self.use(self.company)
        summary = self.client.get("/api/dashboard/company/").data
        self.assertEqual(summary["metrics"], {"active_offers": 1, "closed_offers": 0, "applications": 1})
        self.assertEqual(summary["recent_applications"][0]["offer__title"], "Oferta QA")

    def test_anonymous_and_cross_role_access(self):
        for user in (self.company, self.candidate):
            self.use(user)
            self.assertEqual(self.client.get("/api/dashboard/admin/").status_code, 403)
        self.use(self.candidate)
        self.assertEqual(self.client.get("/api/company/").status_code, 403)
        self.client.credentials()
        for path in ("/api/company/", "/api/dashboard/company/", "/api/dashboard/admin/", "/api/admin/companies/"):
            self.assertEqual(self.client.get(path).status_code, 401)

    def test_remote_logout_revokes_used_token(self):
        token = Token.objects.get(user=self.company).key
        self.assertEqual(self.client.post("/api/logout/").status_code, 200)
        self.assertFalse(Token.objects.filter(key=token).exists())
        self.assertEqual(self.client.get("/api/account/").status_code, 401)

    def test_admin_account_role_matches_login(self):
        self.use(self.admin)
        self.assertEqual(self.client.get("/api/account/").data["user"]["role"], "admin")

    def test_approved_extras_logo_is_private_and_invalid_image_preserves_it(self):
        self.assertEqual(self.client.put("/api/company/logo/", {}, format="multipart").status_code, 403)
        info = self.submit()
        self.decide(info)
        self.use(self.company)
        extras = self.client.patch("/api/company/", {"website": "https://example.org", "social_links": ["https://example.org/red"]}, format="json")
        self.assertEqual(extras.status_code, 200)
        self.assertEqual(self.client.get("/api/company/").data["company"]["social_links"], ["https://example.org/red"])
        data = BytesIO()
        Image.new("RGB", (8, 8), "green").save(data, "PNG")
        upload = SimpleUploadedFile("logo.png", data.getvalue(), content_type="image/png")
        self.assertEqual(self.client.put("/api/company/logo/", {"photo": upload}, format="multipart").status_code, 200)
        image = self.client.get("/api/company/logo/")
        self.assertEqual(image.status_code, 200)
        self.assertEqual(image["Cache-Control"], "private, no-store")
        invalid = SimpleUploadedFile("logo.png", b"falso", content_type="image/png")
        self.assertEqual(self.client.put("/api/company/logo/", {"photo": invalid}, format="multipart").status_code, 400)
        self.assertEqual(self.client.get("/api/company/logo/").content, image.content)
        self.use(self.other)
        self.assertEqual(self.client.get("/api/company/logo/").status_code, 403)
        self.use(self.company)
        self.assertEqual(self.client.delete("/api/company/logo/").status_code, 200)
        self.assertEqual(self.client.get("/api/company/logo/").status_code, 404)

    def test_registration_creates_before_role_choice_and_disallows_reassignment(self):
        self.client.credentials()
        registered = self.client.post("/api/register/", {"full_name": "Registro nuevo QA", "email": "nuevo@worknet.test", "password": self.password, "password_confirm": self.password}, format="json")
        self.assertEqual(registered.status_code, 201)
        self.assertEqual(registered.data["user"]["role"], "")
        ticket = registered.data["registration_token"]
        self.assertEqual(self.client.post("/api/register/role/", {"registration_token": ticket, "role": "admin"}, format="json").status_code, 400)
        chosen = self.client.post("/api/register/role/", {"registration_token": ticket, "role": "empresa"}, format="json")
        self.assertEqual(chosen.status_code, 200)
        self.assertEqual(self.client.post("/api/register/role/", {"registration_token": ticket, "role": "candidato"}, format="json").status_code, 409)

    def test_role_ticket_invalid_or_expired_and_authenticated_recovery(self):
        self.client.credentials()
        self.assertEqual(self.client.post("/api/register/role/", {"role": "empresa", "registration_token": "invalido"}, format="json").status_code, 400)
        unassigned = User.objects.create_user("sinrol@worknet.test", self.password, email_verified=True)
        with patch("django.core.signing.time.time", return_value=0):
            expired = signing.dumps({"user_id": unassigned.pk}, salt="worknet-role-choice")
        self.assertEqual(self.client.post("/api/register/role/", {"role": "empresa", "registration_token": expired}, format="json").status_code, 400)
        login = self.client.post("/api/login/", {"email": unassigned.email, "password": self.password}, format="json")
        self.assertEqual(login.data["user"]["role"], "unassigned")
        self.use(unassigned)
        self.assertEqual(self.client.post("/api/register/role/", {"role": "candidato"}, format="json").status_code, 200)

    def test_registration_send_failure_rolls_back_and_recovery_reports_failure(self):
        self.client.credentials()
        with patch("accounts.views.send_verification_email", side_effect=SMTPException("fallo simulado")):
            response = self.client.post("/api/register/", {"full_name": "Fallo QA", "email": "fallo@worknet.test", "password": self.password, "password_confirm": self.password}, format="json")
        self.assertEqual(response.status_code, 503)
        self.assertFalse(User.objects.filter(email="fallo@worknet.test").exists())
        with patch("accounts.views.send_password_recovery_email", side_effect=SMTPException("fallo simulado")):
            response = self.client.post("/api/password-recovery/request/", {"email": self.company.email}, format="json")
        self.assertEqual(response.status_code, 503)
