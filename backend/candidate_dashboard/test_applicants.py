from copy import deepcopy
from unittest.mock import patch

from django.core.exceptions import ValidationError
from django.db import connection
from django.db.migrations.executor import MigrationExecutor
from django.test import TestCase, TransactionTestCase, override_settings
from django.test.utils import CaptureQueriesContext
from django.utils import timezone

from accounts.models import CompanyProfile, User
from .models import Application, CandidateProfile, JobOffer
from .selection_text import normalized, selection_text
from .test_applications import ApplicationFixture


@override_settings(PASSWORD_HASHERS=['django.contrib.auth.hashers.MD5PasswordHasher'])
class ApplicantTests(ApplicationFixture, TestCase):
    def setUp(self):
        super().setUp()
        self.a = Application.objects.create(candidate=self.user, offer=self.offer)
        self.b = Application.objects.create(candidate=self.other, offer=self.offer, status='in_review')
        self.p = CandidateProfile.objects.create(candidate=self.user,
            experience=[{'position': 'Ingeniera Backend', 'company': 'Laboratorio QA', 'description': 'APIs Django'}],
            education=[{'qualification': 'Ingeniería de Sistemas', 'institution': 'Instituto QA', 'internal_note': 'secreto-no-indexar'}],
            skills=[{'name': 'Python', 'level': 'avanzado'}, {'name': 'Django'}])
        CandidateProfile.objects.create(candidate=self.other, experience=[{'position': 'Ventas'}],
                                       education=[{'qualification': 'Técnico'}], skills=[{'name': 'Excel'}])
        self.foreign_offer = self.make_offer(company=self.foreign_company)
        self.foreign_application = Application.objects.create(candidate=self.user, offer=self.foreign_offer)
        self.url = f'/api/company/offers/{self.offer.pk}/applications/'
        self.authenticate(self.company)

    def test_selection_lists_only_owned_including_closed_archived_and_counts(self):
        closed = self.make_offer(status='closed')
        archived = self.make_offer(status='archived')
        r = self.client.get('/api/company/applicant-offers/?page_size=2')
        self.assertEqual(r.status_code, 200)
        self.assertEqual([o['id'] for o in r.data['offers']], [archived.pk, closed.pk])
        page2 = self.client.get('/api/company/applicant-offers/?page_size=2&page=2')
        self.assertEqual(page2.data['offers'][0]['applicants_count'], 2)
        self.assertEqual(page2.data['count'], 3)
        self.assertEqual(self.client.get('/api/company/applicant-offers/?skill=Python').status_code, 400)

    def test_filters_individual_combined_accent_case_literal_and_absence(self):
        for q in ['experience=INGENIERA', 'experience=laboratorio', 'experience=django',
                  'education=INGENIERIA', 'education=instituto', 'skill=pYtHoN',
                  'experience=Backend&education=Sistemas&skill=django']:
            r = self.client.get(self.url + '?' + q)
            self.assertEqual(r.status_code, 200, q)
            self.assertEqual([a['id'] for a in r.data['applications']], [self.a.pk], q)
            self.assertEqual(r.data['filter_scope'], 'current_profile')
        for q in ['education=secreto-no-indexar', 'skill=avanzado', 'skill=%25',
                  'experience=Ventas&skill=Python', 'education=ausente']:
            r = self.client.get(self.url + '?' + q)
            self.assertEqual((r.data['count'], r.data['applications']), (0, []), q)
        self.p.delete()
        self.assertEqual(self.client.get(self.url + '?skill=Python').data['count'], 0)
        self.assertEqual(self.client.get(self.url).data['count'], 2)

    def test_current_profile_changes_recompute_filters_without_touching_application(self):
        self.p.skills = [{'name': 'Rust'}]
        self.p.save(update_fields=['skills'])
        self.assertEqual(self.client.get(self.url + '?skill=Python').data['count'], 0)
        self.assertEqual(self.client.get(self.url + '?skill=Rust').data['count'], 1)
        CandidateProfile.objects.filter(pk=self.p.pk).update(education=[{'qualification': 'Maestría'}])
        self.assertEqual(self.client.get(self.url + '?education=maestria').data['count'], 1)
        self.a.refresh_from_db()
        self.assertEqual(self.a.status, 'submitted')

    def test_projection_uses_known_structured_fields_and_keeps_records(self):
        original = deepcopy(self.p.education)
        self.p.refresh_from_db()
        self.assertEqual(self.p.education, original)
        self.assertNotIn('secreto', self.p.selection_education)
        self.assertEqual(normalized('  INGENIERÍA  QA '), 'ingenieria qa')
        self.assertEqual(selection_text([{'title': 'Senior', 'internal': 'oculto'}], 'experience'), 'senior')
        self.assertEqual(selection_text(['Python', {'name': 'Django'}], 'skills'), 'python\ndjango')
        with self.assertRaises(ValidationError):
            CandidateProfile.objects.bulk_update([self.p], ['skills'])

    def test_stable_name_date_order_and_bounded_sql_pagination(self):
        same_date = timezone.now()
        with patch('django.utils.timezone.now', return_value=same_date):
            for i in range(12):
                u = User.objects.create_user(f'page{i}@hu020.test', role='candidato', full_name='Zeta QA', email_verified=True)
                Application.objects.create(candidate=u, offer=self.offer)
        for order in ('newest', 'oldest', 'name', 'name_desc'):
            first = self.client.get(self.url + '?page_size=10&order=' + order).data
            second = self.client.get(self.url + '?page_size=10&page=2&order=' + order).data
            ids = [x['id'] for x in first['applications'] + second['applications']]
            self.assertEqual((len(ids), len(set(ids))), (14, 14))
            self.assertEqual(first['applications'], self.client.get(self.url + '?page_size=10&order=' + order).data['applications'])
        with CaptureQueriesContext(connection) as queries:
            r = self.client.get(self.url + '?page_size=10')
        self.assertLessEqual(len(queries), 7)
        self.assertEqual(len(r.data['applications']), 10)
        self.assertTrue(any('LIMIT 10' in x['sql'] for x in queries))
        self.assertFalse(any('cv_document' in x['sql'] for x in queries))

    def test_unknown_repeated_limits_controls_and_invalid_parameters(self):
        for q in ('page=0', 'page=-1', 'page=99', 'page=1&page=1', 'page=%EF%BC%91',
                  'page_size=51', 'page_size=x', 'order=salary', 'candidate_id=2', 'offer_id=2',
                  'skill=Python&skill=Excel', 'education=%0Aotro', 'experience=' + 'a' * 101):
            self.assertEqual(self.client.get(self.url + '?' + q).status_code, 400, q)
        self.assertEqual(self.client.get(self.url + '?experience=&education=&skill=').data['count'], 2)

    def test_foreign_ids_selection_list_detail_profile_and_pdf_are_private(self):
        for path in [f'/api/company/offers/{self.foreign_offer.pk}/applications/',
                     f'/api/company/applications/{self.foreign_application.pk}/',
                     f'/api/company/applications/{self.foreign_application.pk}/profile/',
                     f'/api/company/applications/{self.foreign_application.pk}/profile/photo/',
                     f'/api/company/applications/{self.foreign_application.pk}/cv/']:
            self.assertEqual(self.client.get(path).status_code, 404, path)
        self.assertEqual(self.client.get(f'/api/company/offers/999999/applications/').status_code, 404)
        self.assertEqual(self.client.get(self.url).data['applications'][0]['candidate']['full_name'], self.other.full_name)

    def test_role_approval_session_and_read_only(self):
        for user in (self.user, self.other):
            self.authenticate(user)
            self.assertEqual(self.client.get(self.url).status_code, 403)
            self.assertEqual(self.client.get('/api/company/applicant-offers/').status_code, 403)
        self.authenticate(self.company)
        CompanyProfile.objects.filter(company=self.company).update(state='pending')
        self.assertEqual(self.client.get(self.url).status_code, 403)
        CompanyProfile.objects.filter(company=self.company).update(state='approved')
        self.assertEqual(self.client.post(self.url, {'status': 'accepted'}, format='json').status_code, 405)
        self.client.credentials()
        self.assertEqual(self.client.get(self.url).status_code, 401)

    def test_inactive_offer_and_legacy_document_stay_consultable_without_fabrication(self):
        for state in ['closed', 'archived']:
            self.offer.status = state
            self.offer.save(update_fields=['status'])
            r = self.client.get(self.url)
            self.assertEqual(r.status_code, 200)
            self.assertEqual(r.data['offer']['status'], state)
            self.assertEqual(r.data['count'], 2)
            self.assertIsNone(r.data['applications'][0]['cv'])
        self.assertEqual(self.client.get(f'/api/company/applications/{self.a.pk}/cv/').status_code, 404)

    def test_private_uploaded_and_generated_copies_survive_source_changes(self):
        for source in ('uploaded', 'generated'):
            offer = self.make_offer()
            self.authenticate(self.user)
            created = self.submit(source, offer=offer)
            self.assertEqual(created.status_code, 201)
            item = Application.objects.get(pk=created.data['application']['id'])
            raw = bytes(item.cv_document)
            (self.uploaded if source == 'uploaded' else self.generated).delete()
            offer.status = 'archived';offer.save(update_fields=['status'])
            self.authenticate(self.company)
            self.assertEqual(self.client.get(f'/api/company/applications/{item.pk}/cv/').content, raw)
            detail = self.client.get(f'/api/company/applications/{item.pk}/')
            self.assertEqual(detail.data['candidate']['full_name'], self.user.full_name)
            self.assertEqual(detail.data['application']['cv']['sha256'], item.cv_sha256)


class SelectionMigrationTests(TransactionTestCase):
    def test_catalog_and_projection_preserve_prior_profiles_applications_documents_relations(self):
        executor = MigrationExecutor(connection);latest = executor.loader.graph.leaf_nodes()
        target = [x for x in latest if x[0] != 'candidate_dashboard'] + [('candidate_dashboard', '0004_application_cv_document_application_cv_filename_and_more')]
        try:
            executor.migrate(target);apps = executor.loader.project_state(target).apps
            U=apps.get_model('accounts','User');O=apps.get_model('candidate_dashboard','JobOffer')
            A=apps.get_model('candidate_dashboard','Application');P=apps.get_model('candidate_dashboard','CandidateProfile')
            N=apps.get_model('candidate_dashboard','Notification');S=apps.get_model('candidate_dashboard','SavedOffer')
            user=U.objects.create(email='migration@hu020.test',role='candidato');company=U.objects.create(email='company-migration@hu020.test',role='empresa')
            offer=O.objects.create(company_id=company.pk,title='Anterior QA',company_name='Empresa QA',status='closed')
            app=A.objects.create(candidate_id=user.pk,offer_id=offer.pk,cv_source='uploaded',cv_source_id=8,
                                 cv_filename='anterior.pdf',cv_document=b'original-frozen-test',cv_sha256='a'*64,cv_size_bytes=20)
            education=[{'title':'Ingeniería', 'private':'conservar'}]
            profile=P.objects.create(candidate_id=user.pk,education=education,experience=['Backend'],skills=[{'name':'Python'}],photo_data=b'foto-anterior')
            notice=N.objects.create(recipient_id=company.pk,application_id=app.pk,title='Aviso anterior')
            saved=S.objects.create(candidate_id=user.pk,offer_id=offer.pk)
            date=app.created_at
            MigrationExecutor(connection).migrate(latest)
            row=Application.objects.get(pk=app.pk);p=CandidateProfile.objects.get(pk=profile.pk)
            self.assertEqual((row.candidate_id,row.offer_id,row.created_at,row.status,bytes(row.cv_document)),(user.pk,offer.pk,date,'submitted',b'original-frozen-test'))
            self.assertEqual((p.education,bytes(p.photo_data)),(education,b'foto-anterior'))
            self.assertEqual((p.selection_education,p.selection_experience,p.selection_skills),('ingenieria','backend','python'))
            self.assertEqual(type(row).Status.values,['submitted','in_review','accepted','rejected'])
            self.assertEqual(N.objects.get(pk=notice.pk).application_id,app.pk)
            self.assertEqual(S.objects.get(pk=saved.pk).offer_id,offer.pk)
        finally:
            MigrationExecutor(connection).migrate(latest)
