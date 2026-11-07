from datetime import timedelta

from django.core.exceptions import ValidationError
from django.test import TestCase, override_settings
from django.utils import timezone

from accounts.models import CompanyReview
from . import test_edit_offers as editing_tests
from .models import Application, JobOffer, SavedOffer


@override_settings(PASSWORD_HASHERS=["django.contrib.auth.hashers.MD5PasswordHasher"])
class LifecycleOfferTests(TestCase):
    authenticate = editing_tests.EditOfferTests.authenticate
    setUp = editing_tests.EditOfferTests.setUp
    stored = editing_tests.EditOfferTests.stored
    preserved = '/api/company/offers/preserved/'

    def transition(self, action='close', **data):
        return self.client.post(self.url + 'transition/', {'action': action, **data}, format='json')

    def test_close_then_archive_changes_only_status_and_retains_history_and_profiles(self):
        application = Application.objects.create(candidate=self.company, offer=self.offer)
        SavedOffer.objects.create(candidate=self.company, offer=self.offer)
        before = self.stored()
        relations = list(Application.objects.values()), list(SavedOffer.objects.values())
        reviews = list(CompanyReview.objects.values())
        profile = type(self.profile).objects.values().get(pk=self.profile.pk)
        for action, state in [('close', 'closed'), ('archive', 'archived')]:
            result = self.transition(action, confirm=True)
            self.assertEqual(result.status_code, 200)
            self.assertEqual(self.stored(), {**before, 'status': state})
            self.assertEqual(result.data['offer']['id'], self.offer.pk)
            self.assertEqual(self.client.get('/api/company/offers/active/').data['count'], 0)
            self.assertEqual(self.client.get(self.preserved).data['offers'][0]['status'], state)
            self.assertEqual(self.client.patch(self.url, {'title': 'No'}, format='json').status_code, 409)
            self.assertEqual(self.client.get(self.url).status_code, 409)
            self.assertEqual(self.client.get('/api/dashboard/company/').data['metrics']['applications'], 1)
            self.assertEqual((list(Application.objects.values()), list(SavedOffer.objects.values())), relations)
            application.save()  # El historial ya existente sigue siendo válido.
        self.assertEqual(type(self.profile).objects.values().get(pk=self.profile.pk), profile)
        self.assertEqual(list(CompanyReview.objects.values()), reviews)
        self.assertEqual(JobOffer.objects.count(), 1)

    def test_transition_matrix_and_safe_retries_without_reopening(self):
        for initial in ['published', 'closed', 'archived', 'draft', 'unknown']:
            for action, expected in [('close', {'published': 200, 'closed': 200}),
                                     ('archive', {'published': 200, 'closed': 200, 'archived': 200})]:
                self.offer.status = initial
                self.offer.expires_at = timezone.now() - timedelta(days=1)
                self.offer.save()
                before = self.stored()
                result = self.transition(action, confirm=True)
                self.assertEqual(result.status_code, expected.get(initial, 409), (initial, action))
                self.assertEqual(self.stored(), {**before, 'status': ('closed' if action == 'close' else 'archived')} if result.status_code == 200 else before)

    def test_archive_needs_explicit_boolean_confirmation_and_bad_bodies_never_write(self):
        before = self.stored()
        for confirm in [None, False, 'true', 1, {}, []]:
            self.assertEqual(self.transition('archive', confirm=confirm).status_code, 400)
            self.assertEqual(self.stored(), before)
        for data in [{}, [], {'action': 'reopen'}, {'action': 'close', 'status': 'archived'}, {'action': 'archive', 'confirm': True, 'title': 'No'}]:
            self.assertEqual(self.client.post(self.url + 'transition/', data, format='json').status_code, 400)
            self.assertEqual(self.stored(), before)

    def test_foreign_missing_and_unapproved_roles_cannot_transition_or_read_history(self):
        before = self.stored()
        other = type(self.company).objects.create_user('foreign@worknet.test', role='empresa')
        foreign = JobOffer.objects.create(**self.data, company=other, status='published')
        a = self.client.post(f'/api/company/offers/{foreign.pk}/transition/', {'action': 'close'}, format='json')
        b = self.client.post('/api/company/offers/999999/transition/', {'action': 'close'}, format='json')
        self.assertEqual(a.status_code, 404)
        self.assertEqual(a.data, b.data)
        for role, staff, verified, state in [('candidato', False, True, 'approved'), ('empresa', True, True, 'approved'),
                ('empresa', False, False, 'approved'), ('empresa', False, True, 'pending'), ('empresa', False, True, 'rejected')]:
            self.company.role, self.company.is_staff, self.company.email_verified = role, staff, verified
            self.company.save()
            self.profile.state = state
            self.profile.save()
            self.assertEqual(self.transition().status_code, 403)
            self.assertEqual(self.client.get(self.preserved).status_code, 403)
        self.profile.delete()
        self.assertEqual(self.transition().status_code, 403)
        self.client.credentials()
        self.assertEqual(self.transition().status_code, 401)
        self.assertEqual(self.client.get(self.preserved).status_code, 401)
        self.assertEqual(self.stored(), before)

    def test_preserved_listing_paginates_own_closed_archived_and_never_writes(self):
        for i in range(23):
            JobOffer.objects.create(**self.data, company=self.company, status='closed' if i % 2 else 'archived')
        JobOffer.objects.create(**self.data, company=self.company, status='draft')
        before = list(JobOffer.objects.values())
        first = self.client.get(self.preserved)
        second = self.client.get(self.preserved, {'page': 2, 'company': 999})
        self.assertEqual(first.data['count'], 23)
        self.assertEqual(len(first.data['offers']), 20)
        self.assertEqual(second.data['previous_page'], 1)
        self.assertEqual(len(second.data['offers']), 3)
        self.assertIn('no-store', first['Cache-Control'])
        self.assertEqual(list(JobOffer.objects.values()), before)
        self.assertEqual(self.client.delete(self.url + 'transition/').status_code, 405)

    def test_closed_archived_disappear_from_actual_candidate_recent_results_keep_counts(self):
        candidate = type(self.company).objects.create_user('candidate@worknet.test', role='candidato', email_verified=True)
        application = Application.objects.create(candidate=candidate, offer=self.offer)
        self.authenticate(candidate)
        self.assertEqual([o['id'] for o in self.client.get('/api/dashboard/candidate/').data['recent_jobs']], [self.offer.pk])
        for state in ['closed', 'archived']:
            self.offer.status = state
            self.offer.save(update_fields=['status'])
            result = self.client.get('/api/dashboard/candidate/').data
            self.assertEqual(result['recent_jobs'], [])
            self.assertEqual(result['metrics']['applications_count'], 1)
            self.assertTrue(Application.objects.filter(pk=application.pk, offer=self.offer).exists())

    def test_actual_application_save_and_bulk_create_block_inactive_without_partial_insert(self):
        for state in ['closed', 'archived', 'draft', 'unknown', 'published']:
            self.offer.status = state
            self.offer.expires_at = timezone.now() - timedelta(seconds=1) if state == 'published' else None
            self.offer.save()
            with self.assertRaises(ValidationError):
                Application.objects.create(candidate=self.company, offer=self.offer)
            active = JobOffer.objects.create(**self.data, company=self.company, status='published')
            with self.assertRaises(ValidationError):
                Application.objects.bulk_create([Application(candidate=self.company, offer=active), Application(candidate=self.company, offer=self.offer)])
            self.assertFalse(Application.objects.exists())

    def test_active_application_creation_and_history_relations_cannot_be_reassigned(self):
        a = Application.objects.create(candidate=self.company, offer=self.offer)
        other = JobOffer.objects.create(**self.data, company=self.company, status='published')
        Application.objects.bulk_create([Application(candidate=self.company, offer=other)])
        a.offer = other
        with self.assertRaises(ValidationError):
            a.save()
        with self.assertRaises(ValidationError):
            Application.objects.filter(pk=a.pk).update(offer=other)
        self.assertEqual(Application.objects.get(pk=a.pk).offer_id, self.offer.pk)

    def test_bulk_conflict_update_cannot_reassign_existing_application(self):
        a = Application.objects.create(candidate=self.company, offer=self.offer)
        other = JobOffer.objects.create(**self.data, company=self.company, status='published')
        with self.assertRaises(ValidationError):
            Application.objects.bulk_create([Application(pk=a.pk, candidate=self.company, offer=other)],
                                            update_conflicts=True, update_fields=['offer'], unique_fields=['id'])
        self.assertEqual(Application.objects.get(pk=a.pk).offer_id, self.offer.pk)
