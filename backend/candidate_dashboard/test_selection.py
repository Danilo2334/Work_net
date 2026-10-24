from django.test import TestCase, override_settings
from rest_framework.authtoken.models import Token
from rest_framework.test import APIClient

from accounts.models import CompanyProfile, User
from .models import Application, CandidateProfile, JobOffer
from .test_profile import photo
from .profile import validated_photo


@override_settings(PASSWORD_HASHERS=["django.contrib.auth.hashers.MD5PasswordHasher"])
class ApplicationProfileTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.candidate = self.user("candidato", "candidato")
        self.other_candidate = self.user("otro-candidato", "candidato")
        self.company = self.user("empresa", "empresa")
        self.other_company = self.user("otra-empresa", "empresa")
        for company in (self.company, self.other_company):
            CompanyProfile.objects.create(company=company, state=CompanyProfile.State.APPROVED)
        self.offer = JobOffer.objects.create(company=self.company, title="Desarrollo", company_name="Empresa QA")
        self.application = Application.objects.create(candidate=self.candidate, offer=self.offer)
        self.profile = CandidateProfile.objects.create(
            candidate=self.candidate, professional_summary="Perfil para selección",
            education=[{"qualification": "Ingeniería", "institution": "Instituto QA"}],
            experience=[{"position": "Desarrollo", "company": "Empresa anterior"}],
            skills=[{"name": "Python", "level": "avanzado"}],
            languages=[{"name": "Español", "level": "nativo"}],
            photo_data=validated_photo(photo()),
        )
        self.url = f"/api/company/applications/{self.application.pk}/profile/"
        self.authenticate(self.company)

    def user(self, name, role, **extra):
        return User.objects.create_user(
            email=f"{name}@example.test", full_name=name, password="QaPassword!2026",
            role=role, email_verified=True, **extra,
        )

    def authenticate(self, user):
        token, _ = Token.objects.get_or_create(user=user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")

    def test_offer_owner_reads_applicant_profile_without_account_secrets(self):
        result = self.client.get(self.url)
        self.assertEqual(result.status_code, 200)
        self.assertEqual(result.data["application"], {"id": self.application.pk, "offer_id": self.offer.pk})
        self.assertEqual(result.data["candidate"], {"id": self.candidate.pk, "full_name": self.candidate.full_name})
        self.assertEqual(result.data["profile"]["professional_summary"], self.profile.professional_summary)
        for section in ("education", "experience", "skills", "languages"):
            self.assertEqual(len(result.data["profile"][section]), 1)
        for field in ("email", "password", "push_notifications", "token", "photo_data"):
            self.assertNotIn(field, result.json())
        self.assertIn("no-store", result["Cache-Control"])
        self.assertIn("Authorization", result["Vary"])

    def test_other_company_and_nonexistent_application_share_not_found_response(self):
        self.authenticate(self.other_company)
        foreign = self.client.get(self.url)
        missing = self.client.get("/api/company/applications/999999/profile/")
        self.assertEqual(foreign.status_code, 404)
        self.assertEqual(foreign.data, missing.data)
        self.assertEqual(self.client.get(self.url + "photo/").status_code, 404)

    def test_cannot_select_a_candidate_or_company_through_query_parameters(self):
        CandidateProfile.objects.create(candidate=self.other_candidate, professional_summary="No debe aparecer")
        result = self.client.get(self.url, {"candidate": self.other_candidate.pk, "company": self.other_company.pk})
        self.assertEqual(result.data["candidate"]["id"], self.candidate.pk)
        self.assertEqual(result.data["profile"]["professional_summary"], self.profile.professional_summary)
        self.authenticate(self.other_company)
        self.assertEqual(self.client.get(self.url, {"company": self.company.pk}).status_code, 404)

    def test_get_does_not_create_or_rewrite_profile(self):
        original = self.profile.education
        self.client.get(self.url)
        self.profile.refresh_from_db()
        self.assertEqual(self.profile.education, original)
        self.profile.delete()
        result = self.client.get(self.url)
        self.assertEqual(result.status_code, 200)
        self.assertFalse(result.data["profile"]["exists"])
        self.assertFalse(CandidateProfile.objects.filter(candidate=self.candidate).exists())
        self.assertEqual(self.client.get(self.url + "photo/").status_code, 404)

    def test_photo_is_private_and_same_as_candidate_photo(self):
        result = self.client.get(self.url + "photo/")
        self.assertEqual(result.status_code, 200)
        self.assertEqual(result.content, bytes(self.profile.photo_data))
        self.assertEqual(result["Content-Type"], "image/jpeg")
        self.assertIn("no-store", result["Cache-Control"])
        self.assertIn("Authorization", result["Vary"])
        self.assertEqual(result["X-Content-Type-Options"], "nosniff")

    def test_company_routes_are_read_only_and_cannot_modify_candidate(self):
        for url in (self.url, self.url + "photo/"):
            for method in ("post", "put", "patch", "delete"):
                with self.subTest(url=url, method=method):
                    self.assertEqual(getattr(self.client, method)(url, {"professional_summary": "Intrusión"}, format="json").status_code, 405)
        self.profile.refresh_from_db()
        self.assertEqual(self.profile.professional_summary, "Perfil para selección")
        self.assertTrue(self.profile.photo_data)

    def test_anonymous_candidate_and_administrator_cannot_use_company_routes(self):
        self.client.credentials()
        for url in (self.url, self.url + "photo/"):
            self.assertEqual(self.client.get(url).status_code, 401)
        admin = self.user("admin", "empresa", is_staff=True)
        for user in (self.candidate, self.other_candidate, admin):
            self.authenticate(user)
            for url in (self.url, self.url + "photo/"):
                self.assertEqual(self.client.get(url).status_code, 403)

    def test_company_must_remain_verified_and_approved(self):
        company_profile = CompanyProfile.objects.get(company=self.company)
        for state in (CompanyProfile.State.PENDING, CompanyProfile.State.REJECTED):
            company_profile.state = state
            company_profile.save(update_fields=["state"])
            for url in (self.url, self.url + "photo/"):
                self.assertEqual(self.client.get(url).status_code, 403)
        company_profile.state = CompanyProfile.State.APPROVED
        company_profile.save(update_fields=["state"])
        self.company.email_verified = False
        self.company.save(update_fields=["email_verified"])
        self.assertEqual(self.client.get(self.url).status_code, 403)
        company_profile.delete()
        self.assertEqual(self.client.get(self.url).status_code, 403)

    def test_access_is_revoked_when_application_is_removed(self):
        self.application.delete()
        self.assertEqual(self.client.get(self.url).status_code, 404)
        self.assertEqual(self.client.get(self.url + "photo/").status_code, 404)

    def test_postulation_to_another_company_does_not_grant_access(self):
        offer = JobOffer.objects.create(company=self.other_company, title="Otra oferta", company_name="Otra empresa")
        application = Application.objects.create(candidate=self.other_candidate, offer=offer)
        url = f"/api/company/applications/{application.pk}/profile/"
        self.assertEqual(self.client.get(url).status_code, 404)
        self.assertEqual(self.client.get(url + "photo/").status_code, 404)

    def test_offer_status_does_not_break_existing_selection_history(self):
        for state in (JobOffer.Status.CLOSED, JobOffer.Status.ARCHIVED):
            self.offer.status = state
            self.offer.save(update_fields=["status"])
            self.assertEqual(self.client.get(self.url).status_code, 200)
