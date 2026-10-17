from datetime import timedelta

from django.db import IntegrityError, transaction
from django.test import override_settings
from django.utils import timezone
from rest_framework.authtoken.models import Token
from rest_framework.test import APITestCase

from accounts.models import User
from .models import Application, CandidateProfile, JobOffer, Notification, SavedOffer


@override_settings(PASSWORD_HASHERS=["django.contrib.auth.hashers.MD5PasswordHasher"])
class CandidateDashboardTests(APITestCase):
    url = "/api/dashboard/candidate/"

    def setUp(self):
        self.user = self.make_user("candidate", "candidato")
        self.other = self.make_user("other", "candidato")
        self.company = self.make_user("company", "empresa")
        self.token = Token.objects.create(user=self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Token {self.token.key}")

    def make_user(self, name, role):
        return User.objects.create_user(
            email=f"{name}@example.com", full_name=name, role=role,
            password="PruebaDashboard!2026", email_verified=True,
        )

    def offer(self, **extra):
        fields = dict(company=self.company, title="Desarrollador Django", company_name="WorkNet QA",
                      location="Pasto", contract_type="Indefinido", status="published", published_at=timezone.now())
        fields.update(extra)
        return JobOffer.objects.create(**fields)

    def dashboard(self):
        response = self.client.get(self.url)
        self.assertEqual(response.status_code, 200)
        return response.data

    def test_empty_dashboard_has_zero_metrics_and_no_fake_offers(self):
        data = self.dashboard()
        self.assertEqual(data["metrics"], dict(applications_count=0, saved_offers_count=0, pending_notifications_count=0))
        self.assertEqual(data["recent_jobs"], [])
        self.assertEqual(data["profile_completion"]["percentage"], 17)
        self.assertEqual(data["profile_completion"]["status"], "incomplete")

    def test_get_does_not_create_a_profile_or_activity(self):
        self.dashboard()
        self.assertEqual(CandidateProfile.objects.count(), 0)
        self.assertEqual(Notification.objects.count(), 0)

    def test_counts_are_isolated_and_unread_only(self):
        first, second = self.offer(), self.offer()
        Application.objects.create(candidate=self.user, offer=first)
        Application.objects.create(candidate=self.user, offer=second)
        Application.objects.create(candidate=self.other, offer=first)
        SavedOffer.objects.create(candidate=self.user, offer=first)
        SavedOffer.objects.create(candidate=self.other, offer=second)
        Notification.objects.create(recipient=self.user, title="Sin leer")
        Notification.objects.create(recipient=self.user, title="Leída", read_at=timezone.now())
        Notification.objects.create(recipient=self.other, title="De otro usuario")
        self.assertEqual(self.dashboard()["metrics"], dict(applications_count=2, saved_offers_count=1, pending_notifications_count=1))

    def test_preferences_do_not_hide_pending_in_app_notifications(self):
        self.user.push_notifications = False
        self.user.save(update_fields=["push_notifications"])
        Notification.objects.create(recipient=self.user, title="Sin leer")
        self.assertEqual(self.dashboard()["metrics"]["pending_notifications_count"], 1)

    def test_marking_a_notification_read_changes_the_next_summary(self):
        notification = Notification.objects.create(recipient=self.user, title="Sin leer")
        self.assertEqual(self.dashboard()["metrics"]["pending_notifications_count"], 1)
        notification.read_at = timezone.now()
        notification.save(update_fields=["read_at"])
        self.assertEqual(self.dashboard()["metrics"]["pending_notifications_count"], 0)

    def test_full_profile_has_100_percent_and_no_missing_sections(self):
        CandidateProfile.objects.create(candidate=self.user, professional_summary="Backend Django",
            education=[{"title": "Ingeniería"}], experience=[{"position": "Backend"}], skills=["Python"], languages=["Español"])
        self.assertEqual(self.dashboard()["profile_completion"], dict(
            percentage=100, status="complete", completed_sections=6, total_sections=6, missing_sections=[]))

    def test_partial_profile_uses_six_equal_sections(self):
        CandidateProfile.objects.create(candidate=self.user, professional_summary="Django", skills=["Python"])
        completion = self.dashboard()["profile_completion"]
        self.assertEqual(completion["percentage"], 50)
        self.assertEqual(completion["missing_sections"], ["education", "experience", "languages"])

    def test_whitespace_is_not_a_completed_section(self):
        User.objects.filter(pk=self.user.pk).update(full_name=" ")
        CandidateProfile.objects.create(candidate=self.user, professional_summary="  ")
        self.assertEqual(self.dashboard()["profile_completion"]["percentage"], 0)

    def test_profile_from_another_candidate_does_not_increase_completion(self):
        CandidateProfile.objects.create(candidate=self.other, professional_summary="Otro", skills=["Python"])
        self.assertEqual(self.dashboard()["profile_completion"]["percentage"], 17)

    def test_recent_jobs_are_published_visible_and_not_expired_or_future(self):
        visible = self.offer()
        for status in ("draft", "closed", "archived"):
            self.offer(status=status)
        self.offer(published_at=None)
        self.offer(published_at=timezone.now() + timedelta(days=1))
        self.offer(expires_at=timezone.now() - timedelta(seconds=1))
        inactive_company = self.make_user("inactive", "empresa")
        User.objects.filter(pk=inactive_company.pk).update(is_active=False)
        self.offer(company=inactive_company)
        self.offer(company=self.other)
        jobs = self.dashboard()["recent_jobs"]
        self.assertEqual([job["id"] for job in jobs], [visible.pk])
        self.assertEqual(set(jobs[0]), {"id", "title", "company_name", "location", "contract_type", "published_at"})

    def test_recent_jobs_are_limited_to_five_in_stable_date_order(self):
        published = timezone.now() - timedelta(days=1)
        offers = [self.offer(published_at=published) for _ in range(7)]
        self.assertEqual([row["id"] for row in self.dashboard()["recent_jobs"]], [o.pk for o in reversed(offers[-5:])])

    def test_application_history_and_saved_offers_still_count_closed_jobs(self):
        job = self.offer(status="closed")
        Application.objects.create(candidate=self.user, offer=job)
        SavedOffer.objects.create(candidate=self.user, offer=job)
        data = self.dashboard()
        self.assertEqual(data["metrics"]["applications_count"], 1)
        self.assertEqual(data["metrics"]["saved_offers_count"], 1)
        self.assertEqual(data["recent_jobs"], [])

    def test_duplicate_applications_and_saves_cannot_inflate_metrics(self):
        job = self.offer()
        for model in (Application, SavedOffer):
            model.objects.create(candidate=self.user, offer=job)
            with self.assertRaises(IntegrityError), transaction.atomic():
                model.objects.create(candidate=self.user, offer=job)

    def test_query_string_cannot_select_a_foreign_account(self):
        Notification.objects.create(recipient=self.other, title="Privada")
        response = self.client.get(self.url, {"user_id": self.other.pk, "candidate_id": self.other.pk})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["user"]["id"], self.user.pk)
        self.assertEqual(response.data["metrics"]["pending_notifications_count"], 0)

    def test_missing_and_invalid_tokens_are_rejected(self):
        self.client.credentials()
        self.assertEqual(self.client.get(self.url).status_code, 401)
        self.client.credentials(HTTP_AUTHORIZATION="Token invalido")
        self.assertEqual(self.client.get(self.url).status_code, 401)

    def test_company_and_admin_cannot_access_candidate_dashboard(self):
        admin = self.make_user("admin", "candidato")
        admin.is_staff = True
        admin.save(update_fields=["is_staff"])
        superuser = self.make_user("superuser", "candidato")
        superuser.is_superuser = True
        superuser.save(update_fields=["is_superuser"])
        for user in (self.company, admin, superuser):
            with self.subTest(email=user.email):
                token = Token.objects.create(user=user)
                self.client.credentials(HTTP_AUTHORIZATION=f"Token {token.key}")
                self.assertEqual(self.client.get(self.url).status_code, 403)

    def test_inactive_candidate_is_rejected(self):
        User.objects.filter(pk=self.user.pk).update(is_active=False)
        self.assertEqual(self.client.get(self.url).status_code, 401)

    def test_summary_is_read_only(self):
        for method in (self.client.post, self.client.patch, self.client.delete):
            self.assertEqual(method(self.url, {}, format="json").status_code, 405)
        self.assertTrue(User.objects.filter(pk=self.user.pk).exists())

    def test_deleted_account_cannot_access_summary(self):
        self.user.delete()
        self.assertEqual(self.client.get(self.url).status_code, 401)
