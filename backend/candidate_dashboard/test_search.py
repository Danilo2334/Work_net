from datetime import timedelta
from unittest.mock import patch

from django.db import connection
from django.test import TestCase, override_settings
from django.test.utils import CaptureQueriesContext
from django.utils import timezone
from rest_framework.authtoken.models import Token
from rest_framework.test import APIClient

from accounts.models import User
from .models import Application, JobOffer, SavedOffer


@override_settings(PASSWORD_HASHERS=["django.contrib.auth.hashers.MD5PasswordHasher"])
class SearchOffersTests(TestCase):
    url = "/api/offers/search/"

    def setUp(self):
        self.client = APIClient()
        self.now = timezone.now()
        self.company = User.objects.create_user("company@hu016.test", "LocalTest123!", role="empresa", email_verified=True)
        self.candidate = User.objects.create_user("candidate@hu016.test", "LocalTest123!", role="candidato", email_verified=True)
        self.authenticate(self.candidate)
        self.first = self.offer(title="Python Django", requirements="Python", salary="200.00")
        self.second = self.offer(title="Python", salary="400.00", location="Bogotá", category="Educación", contract_type="Fijo")
        self.third = self.offer(title="Soporte", description="Python Django", salary=None)

    def authenticate(self, user):
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {Token.objects.get_or_create(user=user)[0].key}")

    def offer(self, **changes):
        return JobOffer.objects.create(**{
            "company": self.company, "company_name": "Empresa ficticia QA", "title": "Desarrollo",
            "location": "Pasto", "category": "Tecnología", "contract_type": "Indefinido",
            "description": "Construcción", "requirements": "Pruebas", "salary": "300.00",
            "status": "published", "published_at": self.now - timedelta(days=1), **changes,
        })

    def ids(self, **params):
        response = self.client.get(self.url, params)
        self.assertEqual(response.status_code, 200, response.data)
        return [row["id"] for row in response.data["offers"]]

    def test_each_filter_and_combination_with_inclusive_salary(self):
        cases = [({"q": "pYtHoN Django"}, [self.first.pk, self.third.pk]),
                 ({"location": "pas"}, [self.third.pk, self.first.pk]),
                 ({"salary_min": "200", "salary_max": "200"}, [self.first.pk]),
                 ({"salary_min": "400"}, [self.second.pk]),
                 ({"salary_max": "200"}, [self.first.pk]),
                 ({"category": "Educación"}, [self.second.pk]),
                 ({"contract_type": "Fijo"}, [self.second.pk]),
                 ({"q": "Django", "location": "Pasto", "salary_min": "200", "salary_max": "400",
                   "category": "Tecnología", "contract_type": "Indefinido"}, [self.first.pk])]
        for params, expected in cases:
            with self.subTest(params=params):
                self.assertEqual(self.ids(**params), expected)
        self.assertEqual(self.ids(q="inexistente"), [])
        self.assertEqual(self.ids(q="Python Django", location="Cali"), [])

    def test_relevance_weights_and_stable_date_and_id_ties(self):
        company = self.offer(title="Otro", company_name="Python QA")
        self.assertEqual(self.ids(q="Python"), [self.first.pk, self.second.pk, self.third.pk, company.pk])
        self.assertEqual(self.ids(q="Python PYTHON python"), self.ids(q="python"))
        scores = lambda q: [o["relevance"] for o in self.client.get(self.url, {"q": q}).data["offers"]]
        self.assertEqual(scores("Python PYTHON python"), scores("python"))
        newer = self.offer(title="Python reciente", published_at=self.now)
        self.assertEqual(self.ids(q="Python", sort="date"), [newer.pk, company.pk, self.third.pk, self.second.pk, self.first.pk])
        self.assertEqual(self.ids(q="Python")[:3], [self.first.pk, newer.pk, self.second.pk])

    def test_unicode_case_and_literal_metacharacters(self):
        technical = self.offer(title="TÉCNICO QA C++ [A]", location="BOGOTÁ")
        self.assertEqual(self.ids(q="técnico", location="Bogotá"), [technical.pk])
        self.assertEqual(self.ids(q="TÉCNICO C++ [A]"), [technical.pk])
        self.assertEqual(self.ids(q=".*"), [])

    def test_pagination_and_contract_no_duplicates_or_missing(self):
        all_ids = self.ids(q="Python", sort="date")
        pages = []
        for page in (1, 2, 3):
            response = self.client.get(self.url, {"q": "Python", "sort": "date", "page_size": 1, "page": page})
            body = response.data
            self.assertEqual((body["count"], body["page"], body["total_pages"]), (3, page, 3))
            self.assertEqual(body["next_page"], page + 1 if page < 3 else None)
            self.assertEqual(body["previous_page"], page - 1 if page > 1 else None)
            pages += [o["id"] for o in body["offers"]]
        self.assertEqual(pages, all_ids)
        response = self.client.get(self.url)
        row = response.data["offers"][0]
        self.assertEqual(set(row), {"id", "title", "company_name", "location", "contract_type", "category", "salary", "published_at", "relevance"})
        self.assertIsNone(row["salary"])
        self.assertIn("no-store", response["Cache-Control"])
        self.assertIn("Authorization", response["Vary"])
        self.assertEqual(self.client.get(self.url, {"q": "sinresultados"}).data["total_pages"], 0)

    def test_visibility_same_as_candidate_dashboard_and_expiry_boundary(self):
        for status in ("draft", "closed", "archived"):
            self.offer(status=status)
        self.offer(expires_at=self.now)
        self.offer(expires_at=self.now - timedelta(seconds=1))
        self.offer(published_at=self.now + timedelta(seconds=1))
        self.offer(published_at=None)
        inactive = User.objects.create_user("inactive@hu016.test", role="empresa", is_active=False)
        self.offer(company=inactive)
        self.offer(company=self.candidate)
        with patch("candidate_dashboard.search.timezone.now", return_value=self.now):
            self.assertEqual(set(self.ids()), {self.first.pk, self.second.pk, self.third.pk})

    def test_hu015_transition_hides_search_without_deleting_relationships(self):
        Application.objects.create(candidate=self.candidate, offer=self.first)
        SavedOffer.objects.create(candidate=self.candidate, offer=self.first)
        for status in ("closed", "archived"):
            self.first.status = status
            self.first.save(update_fields=["status"])
            self.assertNotIn(self.first.pk, self.ids(q="Python"))
            self.assertEqual(Application.objects.get().offer_id, self.first.pk)
            self.assertEqual(SavedOffer.objects.get().offer_id, self.first.pk)
        self.assertEqual(JobOffer.objects.count(), 3)

    def test_invalid_parameters_rejected_without_writes(self):
        invalid = {"q": ["x" * 121, "a b c d e f g h i"], "location": ["x" * 201],
                   "salary_min": ["-1", "NaN", "Infinity", "10000000000", "1.001", ""],
                   "salary_max": ["-1", "NaN", "abc"], "category": ["Otro valor", ""],
                   "contract_type": ["Incorrecto"], "sort": ["salary", ""],
                   "page": ["0", "-1", "1.0", "1.5", "abc", "4", ""], "page_size": ["0", "51", "1.0", "-1"],
                   "unknown": ["x"]}
        for key, values in invalid.items():
            for value in values:
                with self.subTest(key=key, value=value):
                    self.assertEqual(self.client.get(self.url, {key: value}).status_code, 400)
        self.assertEqual(self.client.get(self.url, {"salary_min": "400", "salary_max": "200"}).status_code, 400)
        self.assertEqual(self.client.get(self.url + "?q=Python&q=Django").status_code, 400)
        self.assertEqual(self.client.post(self.url, {}, format="json").status_code, 405)
        self.assertEqual(JobOffer.objects.count(), 3)

    def test_permissions(self):
        self.client.credentials()
        self.assertEqual(self.client.get(self.url).status_code, 401)
        for user in (self.company, User.objects.create_user("unverified@hu016.test", role="candidato"),
                     User.objects.create_user("staff@hu016.test", role="candidato", is_staff=True, email_verified=True)):
            self.authenticate(user)
            self.assertEqual(self.client.get(self.url).status_code, 403)

    def test_two_offer_queries_bounded_page_and_no_n_plus_one(self):
        JobOffer.objects.bulk_create([JobOffer(company=self.company, company_name="QA", title="Python",
                                             status="published", published_at=self.now) for _ in range(105)])
        with CaptureQueriesContext(connection) as queries:
            response = self.client.get(self.url, {"q": "Python", "page_size": 50})
        self.assertEqual(len(response.data["offers"]), 50)
        offer_queries = [q for q in queries if '"candidate_dashboard_joboffer"' in q["sql"]]
        self.assertEqual(len(offer_queries), 2)
        self.assertIn("LIMIT 50", offer_queries[1]["sql"])
