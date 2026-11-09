from accounts.testing import fixture_token
from concurrent.futures import ThreadPoolExecutor
from datetime import timedelta
from threading import Barrier
from unittest.mock import patch

from django.db import IntegrityError, OperationalError, close_old_connections, connection, transaction
from django.test import TestCase, TransactionTestCase, override_settings
from django.test.utils import CaptureQueriesContext
from django.utils import timezone
from rest_framework.authtoken.models import Token
from rest_framework.test import APIClient

from accounts.models import CompanyProfile, User
from .models import Application, JobOffer, SavedOffer


class FavoriteFixture:
    listing = "/api/offers/saved/"

    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user("candidate@hu017.test", "LocalTest123!", role="candidato", email_verified=True)
        self.other = User.objects.create_user("other@hu017.test", "LocalTest123!", role="candidato", email_verified=True)
        self.company = User.objects.create_user("company@hu017.test", "LocalTest123!", role="empresa", email_verified=True)
        CompanyProfile.objects.create(company=self.company, legal_name="Empresa ficticia QA", state="approved")
        self.offer = self.make_offer()
        self.url = f"/api/offers/{self.offer.pk}/saved/"
        self.authenticate(self.user)

    def authenticate(self, user):
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {fixture_token(user).key}")

    def make_offer(self, **changes):
        return JobOffer.objects.create(**(dict(company=self.company, title="Oferta HU017 QA", company_name="Empresa ficticia QA",
            location="Pasto", contract_type="Indefinido", category="Tecnología", salary="3000000.00",
            status="published", published_at=timezone.now() - timedelta(days=1)) | changes))


@override_settings(PASSWORD_HASHERS=["django.contrib.auth.hashers.MD5PasswordHasher"])
class FavoritesTests(FavoriteFixture, TestCase):
    def test_add_read_repeat_and_delete_idempotently_without_changing_offer(self):
        before = JobOffer.objects.values().get()
        for _ in range(2):
            r = self.client.put(self.url, {}, format="json")
            self.assertEqual(r.status_code, 200)
            self.assertEqual(r.data, {"offer_id": self.offer.pk, "is_saved": True})
        original = SavedOffer.objects.values().get()
        self.assertEqual(SavedOffer.objects.count(), 1)
        r = self.client.get(self.listing)
        self.assertEqual(r.data["count"], 1)
        row = r.data["offers"][0]
        self.assertEqual((row["id"], row["status"], row["availability"], row["is_active"], row["is_saved"]),
                         (self.offer.pk, "published", "active", True, True))
        self.assertEqual(row["salary"], "3000000.00")
        self.client.put(self.url)
        self.assertEqual(SavedOffer.objects.values().get(), original)
        self.assertIn("no-store", r["Cache-Control"])
        self.assertIn("Authorization", r["Vary"])
        for _ in range(2):
            r = self.client.delete(self.url)
            self.assertEqual((r.status_code, r.data["is_saved"]), (200, False))
        self.assertEqual(self.client.get(self.listing).data["offers"], [])
        self.assertEqual(JobOffer.objects.values().get(), before)

    def test_database_constraint_rejects_duplicates_even_outside_api(self):
        SavedOffer.objects.create(candidate=self.user, offer=self.offer)
        with self.assertRaises(IntegrityError), transaction.atomic():
            SavedOffer.objects.create(candidate=self.user, offer=self.offer)
        SavedOffer.objects.create(candidate=self.other, offer=self.offer)
        self.assertEqual(SavedOffer.objects.count(), 2)
        with connection.cursor() as cursor:
            constraints = connection.introspection.get_constraints(cursor, SavedOffer._meta.db_table)
        self.assertTrue(constraints["dashboard_unique_saved_offer"]["unique"])

    def test_search_dashboard_and_favorites_return_own_membership_and_count(self):
        SavedOffer.objects.create(candidate=self.other, offer=self.offer)
        search = "/api/offers/search/"
        self.assertFalse(self.client.get(search).data["offers"][0]["is_saved"])
        self.client.put(self.url)
        self.assertTrue(self.client.get(search).data["offers"][0]["is_saved"])
        dash = self.client.get("/api/dashboard/candidate/").data
        self.assertTrue(dash["recent_jobs"][0]["is_saved"])
        self.assertEqual(dash["metrics"]["saved_offers_count"], 1)
        self.client.delete(self.url)
        self.assertFalse(self.client.get(search).data["offers"][0]["is_saved"])
        self.assertEqual(self.client.get("/api/dashboard/candidate/").data["metrics"]["saved_offers_count"], 0)
        self.assertEqual(SavedOffer.objects.get().candidate_id, self.other.pk)

    def test_isolation_reauthentication_and_forged_candidate_parameters(self):
        self.client.put(self.url)
        self.authenticate(self.other)
        self.assertEqual(self.client.get(self.listing).data["count"], 0)
        self.assertEqual(self.client.delete(self.url).status_code, 200)
        self.assertEqual(SavedOffer.objects.get().candidate_id, self.user.pk)
        for method in (self.client.put, self.client.delete):
            self.assertEqual(method(self.url, {"candidate_id": self.user.pk}, format="json").status_code, 400)
            self.assertEqual(method(self.url + f"?candidate_id={self.user.pk}").status_code, 400)
        self.assertEqual(self.client.get(self.listing, {"candidate_id": self.user.pk}).status_code, 400)
        self.authenticate(self.user)
        self.assertEqual(self.client.get(self.listing).data["count"], 1)

    def test_real_close_archive_preserve_relation_and_are_visible_only_in_saved(self):
        Application.objects.create(candidate=self.user, offer=self.offer)
        other_save = SavedOffer.objects.create(candidate=self.other, offer=self.offer)
        self.client.put(self.url)
        before = SavedOffer.objects.values().get(candidate=self.user)
        for action, state in (("close", "closed"), ("archive", "archived")):
            self.authenticate(self.company)
            r = self.client.post(f"/api/company/offers/{self.offer.pk}/transition/", {"action": action, "confirm": True}, format="json")
            self.assertEqual(r.status_code, 200)
            self.authenticate(self.user)
            row = self.client.get(self.listing).data["offers"][0]
            self.assertEqual((row["status"], row["availability"], row["is_active"]), (state, state, False))
            self.assertEqual(self.client.get("/api/offers/search/").data["count"], 0)
            self.assertEqual(self.client.put(self.url).status_code, 200)
            self.assertEqual(SavedOffer.objects.values().get(candidate=self.user), before)
        self.assertEqual(self.client.delete(self.url).status_code, 200)
        self.assertTrue(SavedOffer.objects.filter(pk=other_save.pk).exists())
        self.assertEqual(Application.objects.get().offer_id, self.offer.pk)
        self.assertEqual(JobOffer.objects.count(), 1)

    def test_expired_draft_unavailable_and_null_salary_saved_contract(self):
        SavedOffer.objects.create(candidate=self.user, offer=self.offer)
        now = timezone.now()
        cases = [({"expires_at": now}, "expired"), ({"status": "draft"}, "draft"),
                 ({"published_at": None}, "unavailable"), ({"published_at": now + timedelta(days=1)}, "unavailable")]
        for changes, availability in cases:
            JobOffer.objects.filter(pk=self.offer.pk).update(status="published", expires_at=None, published_at=now, salary=None)
            JobOffer.objects.filter(pk=self.offer.pk).update(**changes)
            with patch("candidate_dashboard.favorites.timezone.now", return_value=now):
                row = self.client.get(self.listing).data["offers"][0]
            self.assertEqual((row["availability"], row["is_active"], row["salary"]), (availability, False, None))

    def test_cannot_create_new_saved_relation_for_hidden_offer(self):
        for changes in ({"status": "closed"}, {"status": "archived"}, {"status": "draft"},
                        {"expires_at": timezone.now()}, {"published_at": None},
                        {"published_at": timezone.now() + timedelta(days=1)}):
            JobOffer.objects.filter(pk=self.offer.pk).update(status="published", expires_at=None, published_at=timezone.now())
            JobOffer.objects.filter(pk=self.offer.pk).update(**changes)
            self.assertEqual(self.client.put(self.url).status_code, 404)
            self.assertFalse(SavedOffer.objects.exists())
        self.assertEqual(self.client.put('/api/offers/999999/saved/').status_code, 404)
        self.assertEqual(self.client.delete('/api/offers/999999/saved/').status_code, 200)
        JobOffer.objects.filter(pk=self.offer.pk).update(status="published", expires_at=None, published_at=timezone.now())
        User.objects.filter(pk=self.company.pk).update(is_active=False)
        self.assertEqual(self.client.put(self.url).status_code, 404)
        self.assertFalse(SavedOffer.objects.exists())

    def test_pagination_strict_parameters_and_empty(self):
        self.assertEqual(self.client.get(self.listing).data["total_pages"], 0)
        SavedOffer.objects.bulk_create([SavedOffer(candidate=self.user, offer=self.make_offer(title=f"Oferta {i}")) for i in range(13)])
        first = self.client.get(self.listing).data
        second = self.client.get(self.listing, {"page": 2}).data
        self.assertEqual((first["count"], first["next_page"], second["previous_page"], len(second["offers"])), (13, 2, 1, 3))
        self.assertFalse(set(x["id"] for x in first["offers"]) & set(x["id"] for x in second["offers"]))
        for query in ("page=0", "page=1.0", "page=3", "page=", "page=1&page=2", "page_size=51", "page_size=0", "owner=1"):
            self.assertEqual(self.client.get(self.listing + '?' + query).status_code, 400, query)

    def test_permissions_and_unsupported_methods(self):
        for user in (self.company, User.objects.create_user("unverified@hu017.test", role="candidato"),
                     User.objects.create_user("staff@hu017.test", role="candidato", email_verified=True, is_staff=True)):
            self.authenticate(user)
            for method, url in ((self.client.get,self.listing),(self.client.put,self.url),(self.client.delete,self.url)):
                self.assertEqual(method(url).status_code, 403)
        self.client.credentials()
        for method, url in ((self.client.get,self.listing),(self.client.put,self.url),(self.client.delete,self.url)):
            self.assertEqual(method(url).status_code, 401)
        self.authenticate(self.user)
        self.assertEqual(self.client.post(self.url, {}, format="json").status_code, 405)

    def test_list_queries_are_bounded_and_do_not_grow_per_offer(self):
        SavedOffer.objects.bulk_create([SavedOffer(candidate=self.user, offer=self.make_offer(title=f"Oferta {i}")) for i in range(12)])
        with CaptureQueriesContext(connection) as queries:
            r = self.client.get(self.listing)
        self.assertEqual(len(r.data["offers"]), 10)
        self.assertEqual(len(queries), 3)  # Token, conteo, SELECT con JOIN/EXISTS.
        self.assertIn("LIMIT 10", queries[-1]["sql"])

    def test_sqlite_lock_exhaustion_returns_retryable_503_not_unhandled_500(self):
        with patch("candidate_dashboard.favorites.SavedOffer.objects.filter", side_effect=OperationalError("database is locked")), patch("candidate_dashboard.favorites.time.sleep"):
            self.assertEqual(self.client.put(self.url).status_code, 503)
        self.assertFalse(SavedOffer.objects.exists())


@override_settings(PASSWORD_HASHERS=["django.contrib.auth.hashers.MD5PasswordHasher"])
class ConcurrentFavoritesTests(FavoriteFixture, TransactionTestCase):
    def test_concurrent_api_membership_is_unique_and_repeatable(self):
        for method, expected in (("put", 1), ("delete", 0)):
            barrier = Barrier(4)
            def request(_):
                close_old_connections()
                try:
                    client = APIClient()
                    # La autenticación real se prueba aparte. En SQLite shared
                    # memory su SELECT puede fallar antes de entrar al endpoint;
                    # aquí aislamos la contención real de las cuatro mutaciones.
                    client.force_authenticate(user=self.user)
                    barrier.wait(timeout=5)
                    return getattr(client, method)(self.url).status_code
                finally:
                    close_old_connections()
            with ThreadPoolExecutor(max_workers=4) as pool:
                statuses = list(pool.map(request, range(4)))
            self.assertEqual(statuses, [200] * 4)
            self.assertEqual(SavedOffer.objects.filter(candidate=self.user, offer=self.offer).count(), expected)
