from accounts.testing import fixture_token
from django.test import TestCase, override_settings
from rest_framework.authtoken.models import Token
from rest_framework.test import APIClient

from accounts.models import CompanyProfile, User
from .models import JobOffer


@override_settings(PASSWORD_HASHERS=["django.contrib.auth.hashers.MD5PasswordHasher"])
class PublishOfferTests(TestCase):
    url = "/api/company/offers/"

    def setUp(self):
        self.client = APIClient()
        self.company = User.objects.create_user("empresa@offers.test", "LocalTest123!", role="empresa", email_verified=True)
        self.profile = CompanyProfile.objects.create(company=self.company, state="approved", legal_name="Empresa ficticia QA")
        self.data = dict(title="Desarrollo", description="Construir aplicaciones", requirements="Python y pruebas",
                         salary="2500000.00", location="Pasto", category="Tecnología", contract_type="Indefinido")
        self.authenticate(self.company)

    def authenticate(self, user):
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {fixture_token(user).key}")

    def test_publishes_owned_offer_with_all_fields_and_updates_dashboard(self):
        response = self.client.post(self.url, self.data, format="json")
        self.assertEqual(response.status_code, 201)
        offer = JobOffer.objects.get()
        self.assertEqual(offer.company, self.company)
        self.assertEqual(offer.company_name, self.profile.legal_name)
        self.assertEqual(offer.status, "published")
        self.assertIsNotNone(offer.published_at)
        for field, value in self.data.items():
            self.assertEqual(str(getattr(offer, field)), value)
        dashboard = self.client.get("/api/dashboard/company/")
        self.assertEqual(dashboard.status_code, 200)
        self.assertEqual(dashboard.data["metrics"]["active_offers"], 1)

    def test_catalog_matches_accepted_values(self):
        response = self.client.get(self.url)
        self.assertEqual(response.status_code, 200)
        self.assertIn(self.data["category"], response.data["categories"])
        self.assertIn(self.data["contract_type"], response.data["contract_types"])

    def test_missing_and_blank_fields_do_not_create_partial_offers(self):
        for field in self.data:
            for value in (None, "", "   "):
                with self.subTest(field=field, value=value):
                    data = {**self.data, field: value}
                    response = self.client.post(self.url, data, format="json")
                    self.assertEqual(response.status_code, 400)
                    self.assertIn(field, response.data)
            data = self.data.copy()
            del data[field]
            self.assertEqual(self.client.post(self.url, data, format="json").status_code, 400)
        self.assertFalse(JobOffer.objects.exists())

    def test_invalid_salary_and_choices_and_lengths(self):
        for field, values in {"salary": ["-1", "NaN", "1.001", "10000000000"],
                              "category": ["inventada"], "contract_type": ["inventado"],
                              "title": ["x" * 201], "description": ["x" * 10001]}.items():
            for value in values:
                with self.subTest(field=field, value=str(value)[:20]):
                    self.assertEqual(self.client.post(self.url, {**self.data, field: value}, format="json").status_code, 400)
        self.assertFalse(JobOffer.objects.exists())

    def test_cannot_choose_owner_status_or_publication_time(self):
        for field in ("company", "company_name", "status", "published_at", "id"):
            self.assertEqual(self.client.post(self.url, {**self.data, field: "forged"}, format="json").status_code, 400)
        self.assertFalse(JobOffer.objects.exists())

    def test_pending_rejected_missing_profile_and_revoked_approval(self):
        for state in ("pending", "rejected"):
            self.profile.state = state
            self.profile.save()
            self.assertEqual(self.client.post(self.url, self.data, format="json").status_code, 403)
            self.assertEqual(self.client.get(self.url).status_code, 403)
        self.profile.delete()
        self.assertEqual(self.client.post(self.url, self.data, format="json").status_code, 403)
        self.assertFalse(JobOffer.objects.exists())

    def test_candidate_admin_unverified_and_anonymous_cannot_publish(self):
        for role, staff, verified in (("candidato", False, True), ("empresa", True, True), ("empresa", False, False)):
            self.company.role, self.company.is_staff, self.company.email_verified = role, staff, verified
            self.company.save()
            self.authenticate(self.company)
            self.assertEqual(self.client.post(self.url, self.data, format="json").status_code, 403)
        self.client.credentials()
        self.assertEqual(self.client.post(self.url, self.data, format="json").status_code, 401)
        self.assertFalse(JobOffer.objects.exists())

    def test_create_only_endpoint_rejects_updates_and_deletes(self):
        self.assertEqual(self.client.patch(self.url, self.data, format="json").status_code, 405)
        self.assertEqual(self.client.delete(self.url).status_code, 405)
