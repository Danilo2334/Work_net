"""HU019 lee cambios persistidos por actor QA; no anticipa mutaciones HU021."""
from django.test import TestCase, override_settings

from .models import Application, Notification
from .test_applications import ApplicationFixture


@override_settings(PASSWORD_HASHERS=['django.contrib.auth.hashers.MD5PasswordHasher'])
class HistoryTests(ApplicationFixture, TestCase):
    def test_four_states_own_history_detail_and_controlled_change(self):
        applications = []
        for state in Application.Status:
            item = Application.objects.create(candidate=self.user, offer=self.make_offer(), status=state)
            applications.append(item)
        foreign = Application.objects.create(candidate=self.other, offer=self.make_offer())
        response = self.client.get('/api/applications/?page_size=4')
        self.assertEqual(response.status_code, 200)
        self.assertEqual([a['status'] for a in response.data['applications']], list(reversed(Application.Status.values)))
        self.assertEqual(response.data['count'], 4)
        self.assertNotIn(foreign.pk, [a['id'] for a in response.data['applications']])
        for item in applications:
            detail = self.client.get(f'/api/applications/{item.pk}/')
            self.assertEqual(detail.status_code, 200)
            self.assertEqual(detail.data['application']['status'], item.status)
            self.assertEqual(detail.data['application']['offer']['title'], item.offer.title)
            self.assertIsNone(detail.data['application']['cv'])
        item = applications[0]
        original_date = item.created_at
        # Actor QA explícito: cambio de fixture, no endpoint ni pantalla empresarial.
        Application.objects.filter(pk=item.pk).update(status=Application.Status.ACCEPTED)
        detail = self.client.get(f'/api/applications/{item.pk}/').data['application']
        self.assertEqual(detail['status'], 'accepted')
        item.refresh_from_db()
        self.assertEqual(item.created_at, original_date)
        self.assertEqual(Notification.objects.count(), 0)

    def test_status_read_does_not_create_mutation_api_or_cross_candidate_access(self):
        item = Application.objects.create(candidate=self.user, offer=self.offer)
        url = f'/api/applications/{item.pk}/'
        self.assertEqual(self.client.patch(url, {'status': 'accepted'}, format='json').status_code, 405)
        self.authenticate(self.other)
        self.assertEqual(self.client.get(url).status_code, 404)
        item.refresh_from_db()
        self.assertEqual(item.status, 'submitted')

    def test_status_change_keeps_frozen_document_and_idempotent_receipt(self):
        created = self.submit()
        original = created.data['application']
        item = Application.objects.get()
        raw = bytes(item.cv_document)
        Application.objects.filter(pk=item.pk).update(status=Application.Status.IN_REVIEW)
        detail = self.client.get(f'/api/applications/{item.pk}/').data['application']
        self.assertEqual(detail['cv'], original['cv'])
        self.assertEqual(detail['created_at'], original['created_at'])
        self.assertEqual(self.client.get(f'/api/applications/{item.pk}/cv/').content, raw)
        repeated = self.submit()
        self.assertEqual(repeated.status_code, 200)
        self.assertEqual(repeated.data['application']['status'], 'in_review')
        self.assertEqual((Application.objects.count(), Notification.objects.count()), (1, 1))
