from accounts.testing import fixture_token
from concurrent.futures import ThreadPoolExecutor
from copy import deepcopy
from datetime import timedelta
from hashlib import sha256
from io import BytesIO
from threading import Barrier
from unittest.mock import patch

from django.core.exceptions import ValidationError as ModelValidationError
from django.db import IntegrityError, OperationalError, close_old_connections, connection, transaction
from django.db.migrations.executor import MigrationExecutor
from django.test import TestCase, TransactionTestCase, override_settings
from django.test.utils import CaptureQueriesContext
from django.utils import timezone
from pypdf import PdfReader
from rest_framework.authtoken.models import Token
from rest_framework.test import APIClient

from accounts.models import CompanyProfile, User
from curriculum.models import GeneratedCurriculum, UploadedCurriculum
from curriculum.tests import DATA, pdf_bytes
from .models import Application, JobOffer, Notification, SavedOffer


class ApplicationFixture:
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user('candidate@hu018.test', 'LocalTest123!', full_name='Candidata QA', role='candidato', email_verified=True)
        self.other = User.objects.create_user('other@hu018.test', 'LocalTest123!', role='candidato', email_verified=True)
        self.company = User.objects.create_user('company@hu018.test', 'LocalTest123!', role='empresa', email_verified=True)
        self.foreign_company = User.objects.create_user('foreign@hu018.test', 'LocalTest123!', role='empresa', email_verified=True)
        for company in (self.company, self.foreign_company):
            CompanyProfile.objects.create(company=company, legal_name='Empresa ficticia QA', state='approved')
        self.offer = self.make_offer()
        self.url = f'/api/offers/{self.offer.pk}/application/'
        raw = pdf_bytes('CV subido original QA')
        self.uploaded = UploadedCurriculum.objects.create(candidate=self.user, filename='cv-original.pdf', document=raw, size_bytes=len(raw))
        self.generated = GeneratedCurriculum.objects.create(candidate=self.user, template='moderna', data=deepcopy(DATA))
        self.authenticate(self.user)

    def make_offer(self, **changes):
        return JobOffer.objects.create(**(dict(company=self.company, title='Oferta HU018 QA', company_name='Empresa ficticia QA',
            location='Pasto', contract_type='Indefinido', status='published', published_at=timezone.now()-timedelta(days=1)) | changes))

    def authenticate(self, user):
        self.client.credentials(HTTP_AUTHORIZATION='Token '+fixture_token(user).key)

    def body(self, source='uploaded', item=None):
        item = item or (self.uploaded if source=='uploaded' else self.generated)
        return {'cv_source': source, 'cv_id': item.pk, 'cv_revision': item.updated_at.isoformat(), 'confirm': True}

    def submit(self, source='uploaded', offer=None, body=None):
        return self.client.post(f'/api/offers/{(offer or self.offer).pk}/application/', body or self.body(source), format='json')


@override_settings(PASSWORD_HASHERS=['django.contrib.auth.hashers.MD5PasswordHasher'])
class ApplicationTests(ApplicationFixture, TestCase):
    def test_uploaded_receipt_private_pdf_history_and_real_company_notice(self):
        context = self.client.get(self.url)
        self.assertEqual(context.status_code,200)
        self.assertEqual({x['source'] for x in context.data['cv_options']},{'uploaded','generated'})
        r=self.submit();self.assertEqual(r.status_code,201)
        item=Application.objects.get();self.assertEqual(r.data['application']['id'],item.pk)
        self.assertEqual(r.data['application']['status'],'submitted');self.assertTrue(r.data['created'])
        self.assertIsNotNone(item.created_at);self.assertEqual(bytes(item.cv_document),bytes(self.uploaded.document))
        self.assertEqual(item.cv_sha256,sha256(bytes(self.uploaded.document)).hexdigest())
        self.assertEqual((item.cv_source_id,item.cv_source_updated_at,item.cv_filename),(self.uploaded.pk,self.uploaded.updated_at,'cv-original.pdf'))
        pdf=self.client.get(f'/api/applications/{item.pk}/cv/')
        self.assertEqual(pdf.content,bytes(item.cv_document));self.assertEqual(pdf['Content-Type'],'application/pdf')
        for key,value in [('Cache-Control','private, no-store'),('X-Content-Type-Options','nosniff'),('Content-Security-Policy','sandbox')]:self.assertEqual(pdf[key],value)
        self.assertIn('Authorization',pdf['Vary'])
        history=self.client.get('/api/applications/');self.assertEqual(history.data['applications'][0],r.data['application'])
        self.assertEqual(self.client.get('/api/dashboard/candidate/').data['metrics']['applications_count'],1)
        notice=Notification.objects.get();self.assertEqual((notice.application_id,notice.recipient_id),(item.pk,self.company.pk))
        self.authenticate(self.company)
        dashboard=self.client.get('/api/dashboard/company/');self.assertEqual(dashboard.status_code,200)
        self.assertEqual(dashboard.data['notifications'][0]['id'],notice.pk)
        self.assertIn('Candidata QA',dashboard.data['notifications'][0]['title'])
        self.assertEqual(self.client.get(f'/api/company/applications/{item.pk}/cv/').content,bytes(item.cv_document))
        self.authenticate(self.foreign_company)
        self.assertEqual(self.client.get('/api/dashboard/company/').data['notifications'],[])

    def test_generated_document_remains_after_edit_delete_and_archive(self):
        r=self.submit('generated');self.assertEqual(r.status_code,201)
        item=Application.objects.get();raw=bytes(item.cv_document)
        self.assertEqual((item.cv_source,item.cv_template),('generated','moderna'))
        text='\n'.join(p.extract_text() for p in PdfReader(BytesIO(raw)).pages)
        self.assertIn('María Núñez',text);self.assertIn('Pruebas de software',text)
        self.client.patch('/api/curriculum/generated/',{'template':'minimalista','data':{**deepcopy(DATA),'personal':{'full_name':'Nombre modificado'}}},format='json')
        self.client.delete('/api/curriculum/generated/')
        self.authenticate(self.company)
        self.assertEqual(self.client.post(f'/api/company/offers/{self.offer.pk}/transition/',{'action':'archive','confirm':True},format='json').status_code,200)
        self.assertEqual(self.client.get(f'/api/company/applications/{item.pk}/cv/').content,raw)
        self.authenticate(self.user)
        history=self.client.get('/api/applications/').data['applications'][0]
        self.assertEqual((history['offer']['status'],history['offer']['is_active']),('archived',False))
        self.assertEqual(self.client.get(f'/api/applications/{item.pk}/cv/').content,raw)
        self.assertEqual(Application.objects.count(),1)

    def test_repeat_and_different_selection_keep_original_even_after_source_delete_and_close(self):
        body=self.body();r=self.submit();item=Application.objects.get();before=Application.objects.values().get()
        self.client.delete('/api/curriculum/uploaded/')
        self.offer.status='closed';self.offer.save(update_fields=['status'])
        for data in (body,self.body('generated')):
            repeated=self.submit(body=data);self.assertEqual(repeated.status_code,200);self.assertFalse(repeated.data['created'])
            self.assertEqual(repeated.data['application']['id'],item.pk)
            self.assertEqual(repeated.data['application']['cv']['source'],'uploaded')
        self.assertEqual(Application.objects.values().get(),before);self.assertEqual(Notification.objects.count(),1)
        self.assertEqual(self.client.get(self.url).data['application']['id'],item.pk)

    def test_uploaded_replacement_does_not_change_sent_copy(self):
        self.submit();original=bytes(Application.objects.get().cv_document)
        raw=pdf_bytes('CV reemplazado')
        UploadedCurriculum.objects.filter(pk=self.uploaded.pk).update(document=raw,size_bytes=len(raw))
        self.assertEqual(self.client.get(f'/api/applications/{Application.objects.get().pk}/cv/').content,original)

    def test_missing_foreign_invalid_and_changed_cv_rejected_without_application_or_notice(self):
        foreign=UploadedCurriculum.objects.create(candidate=self.other,filename='ajeno.pdf',document=pdf_bytes(),size_bytes=len(pdf_bytes()))
        data=self.body(item=foreign)
        self.assertEqual(self.submit(body=data).status_code,400)
        data=self.body();data['cv_revision']=(self.uploaded.updated_at-timedelta(seconds=1)).isoformat()
        self.assertEqual(self.submit(body=data).status_code,400)
        UploadedCurriculum.objects.filter(pk=self.uploaded.pk).update(document=b'invalid',size_bytes=7)
        self.assertEqual(self.submit().status_code,400)
        UploadedCurriculum.objects.filter(pk=self.uploaded.pk).delete()
        self.assertEqual(self.submit().status_code,400)
        self.generated.data={};self.generated.save()
        self.assertEqual(self.submit('generated').status_code,400)
        self.assertEqual((Application.objects.count(),Notification.objects.count()),(0,0))

    def test_input_rejects_unconfirmed_unknown_and_forged_actors(self):
        for changes in [{'candidate_id':self.other.pk},{'company_id':self.foreign_company.pk},{'confirm':False},{'confirm':'true'},{'cv_source':'foreign'},{'cv_id':0},{'cv_revision':'invalid'}]:
            self.assertEqual(self.submit(body=self.body()|changes).status_code,400,changes)
        self.assertEqual(self.client.post(self.url+'?candidate_id=2',self.body(),format='json').status_code,400)
        self.assertEqual(self.client.put(self.url,self.body(),format='json').status_code,405)
        self.assertEqual((Application.objects.count(),Notification.objects.count()),(0,0))

    def test_only_visible_active_offers_accept_new_applications(self):
        for changes in [{'status':'closed'},{'status':'archived'},{'status':'draft'},
                        {'expires_at':timezone.now()},{'published_at':timezone.now()+timedelta(days=1)}]:
            offer=self.make_offer(**changes)
            self.assertEqual(self.submit(offer=offer).status_code,404)
            self.assertEqual(self.client.get(f'/api/offers/{offer.pk}/application/').status_code,404)
        self.company.is_active=False;self.company.save(update_fields=['is_active'])
        self.assertEqual(self.submit().status_code,404)
        self.company.is_active=True;self.company.role='candidato';self.company.save(update_fields=['is_active','role'])
        self.assertEqual(self.submit().status_code,404)
        self.assertEqual((Application.objects.count(),Notification.objects.count()),(0,0))

    def test_state_revalidated_after_form_and_saved_inactive_visible_without_accepting(self):
        for action in ('close','archive'):
            offer=self.make_offer();url=f'/api/offers/{offer.pk}/application/'
            self.assertTrue(self.client.get(url).data['offer']['is_active'])
            SavedOffer.objects.create(candidate=self.user,offer=offer)
            self.authenticate(self.company)
            self.assertEqual(self.client.post(f'/api/company/offers/{offer.pk}/transition/',{'action':action,'confirm':True},format='json').status_code,200)
            self.authenticate(self.user)
            self.assertEqual(self.submit(offer=offer).status_code,404)
            self.assertFalse(self.client.get(url).data['offer']['is_active'])
        self.assertEqual((Application.objects.count(),Notification.objects.count()),(0,0))

    def test_expiry_during_pdf_preparation_and_final_model_guard_are_controlled(self):
        from .applications import snapshot
        def expires(*args):
            frozen=snapshot(*args)
            JobOffer.objects.filter(pk=self.offer.pk).update(expires_at=timezone.now()-timedelta(seconds=1))
            return frozen
        with patch('candidate_dashboard.applications.snapshot',side_effect=expires):
            self.assertEqual(self.submit().status_code,404)
        with patch('candidate_dashboard.applications.Application.objects.create',side_effect=ModelValidationError('Venció al insertar')):
            self.assertEqual(self.submit().status_code,404)
        self.assertEqual((Application.objects.count(),Notification.objects.count()),(0,0))

    def test_close_after_submission_keeps_application_cv_and_notice(self):
        self.submit();before=Application.objects.values().get();notice=Notification.objects.values().get()
        self.authenticate(self.company)
        for action in ('close','archive'):
            self.assertEqual(self.client.post(f'/api/company/offers/{self.offer.pk}/transition/',{'action':action,'confirm':True},format='json').status_code,200)
        self.assertEqual(Application.objects.values().get(),before);self.assertEqual(Notification.objects.values().get(),notice)
        self.assertEqual(self.client.get(f'/api/company/applications/{before["id"]}/').status_code,200)
        self.authenticate(self.user)
        self.assertEqual(self.client.get('/api/offers/search/').data['count'],0)
        self.assertEqual(self.client.get('/api/applications/').data['count'],1)

    def test_permissions_privacy_and_reauthentication(self):
        self.submit();item=Application.objects.get()
        self.authenticate(self.other)
        self.assertEqual(self.client.get('/api/applications/').data['count'],0)
        for suffix in ('','cv/'):
            self.assertEqual(self.client.get(f'/api/applications/{item.pk}/{suffix}').status_code,404)
        self.authenticate(self.foreign_company)
        for suffix in ('','cv/'):
            self.assertEqual(self.client.get(f'/api/company/applications/{item.pk}/{suffix}').status_code,404)
        self.authenticate(self.company)
        self.assertEqual(self.client.get('/api/applications/').status_code,403)
        self.authenticate(self.user)
        self.assertEqual(self.client.get('/api/applications/').data['count'],1)
        self.assertEqual(self.client.get(f'/api/company/applications/{item.pk}/cv/').status_code,403)
        self.user.email_verified=False;self.user.save(update_fields=['email_verified'])
        self.assertEqual(self.client.get(self.url).status_code,403)
        self.client.credentials()
        self.assertEqual(self.client.get(self.url).status_code,401)
        self.assertEqual(self.submit().status_code,401)

    def test_snapshot_and_relations_immutable_through_save_update_and_bulk_update(self):
        self.submit();item=Application.objects.get();before=Application.objects.values().get()
        for field,value in [('cv_filename','changed.pdf'),('cv_document',b'changed'),('cv_sha256','bad'),('created_at',item.created_at+timedelta(days=1)),('candidate_id',self.other.pk)]:
            with self.assertRaises(ModelValidationError):Application.objects.filter(pk=item.pk).update(**{field:value})
            setattr(item,field,value)
            with self.assertRaises(ModelValidationError):item.save()
            with self.assertRaises(ModelValidationError),transaction.atomic():Application.objects.bulk_update([item],[field])
            item.refresh_from_db()
        self.assertEqual(Application.objects.values().get(),before)

    def test_database_unique_application_and_one_notice_even_outside_api(self):
        self.submit();item=Application.objects.get()
        for action in (lambda:Application.objects.create(candidate=self.user,offer=self.offer),
                       lambda:Notification.objects.create(recipient=self.company,title='Duplicada',application=item)):
            with self.assertRaises(IntegrityError),transaction.atomic():action()
        with connection.cursor() as cursor:
            constraints=connection.introspection.get_constraints(cursor,Application._meta.db_table)
        self.assertTrue(constraints['dashboard_unique_application']['unique'])
        self.assertEqual((Application.objects.count(),Notification.objects.count()),(1,1))

    def test_pagination_query_bound_and_strict_parameters(self):
        for _ in range(3):self.submit(offer=self.make_offer())
        with CaptureQueriesContext(connection) as queries:r=self.client.get('/api/applications/?page_size=2')
        self.assertEqual(r.status_code,200);self.assertEqual(len(queries),3)
        self.assertNotIn('cv_document',queries[-1]['sql'])
        self.assertEqual((r.data['count'],r.data['next_page']),(3,2))
        second=self.client.get('/api/applications/?page_size=2&page=2').data
        self.assertEqual(len(second['applications']),1)
        for q in ('page=0','page=9','page_size=51','page_size=x','page=1&page=1','candidate_id=2','page=１'):
            self.assertEqual(self.client.get('/api/applications/?'+q).status_code,400,q)

    def test_empty_and_historical_cv_are_not_fabricated(self):
        empty=self.client.get('/api/applications/').data;self.assertEqual((empty['count'],empty['total_pages'],empty['applications']),(0,0,[]))
        item=Application.objects.create(candidate=self.user,offer=self.offer)
        self.assertIsNone(self.client.get('/api/applications/').data['applications'][0]['cv'])
        self.assertEqual(self.client.get(f'/api/applications/{item.pk}/cv/').status_code,404)

    def test_notice_failure_rolls_back_and_busy_returns_recoverable_failure(self):
        with patch('candidate_dashboard.applications.Notification.objects.create',side_effect=IntegrityError('notice failed')):
            with self.assertRaises(IntegrityError):self.submit()
        self.assertEqual(Application.objects.count(),0)
        with patch('candidate_dashboard.applications.snapshot',side_effect=OperationalError('database is locked')):
            r=self.submit();self.assertEqual(r.status_code,503)
        self.assertEqual((Application.objects.count(),Notification.objects.count()),(0,0))


@override_settings(PASSWORD_HASHERS=['django.contrib.auth.hashers.MD5PasswordHasher'])
class ConcurrentApplicationTests(ApplicationFixture, TransactionTestCase):
    def test_four_concurrent_submissions_keep_one_snapshot_and_notice(self):
        barrier=Barrier(4);body=self.body();candidate=self.user;url=self.url
        def worker(_):
            close_old_connections()
            try:
                client=APIClient();client.force_authenticate(candidate);barrier.wait(timeout=10)
                r=client.post(url,body,format='json');return r.status_code,r.data
            finally:close_old_connections()
        with ThreadPoolExecutor(max_workers=4) as pool:results=list(pool.map(worker,range(4)))
        self.assertEqual(sorted(x[0] for x in results),[200,200,200,201])
        self.assertEqual(len({x[1]['application']['id'] for x in results}),1)
        self.assertEqual((Application.objects.count(),Notification.objects.count()),(1,1))
        item=Application.objects.get();self.assertEqual(item.cv_sha256,sha256(bytes(self.uploaded.document)).hexdigest())


class ApplicationMigrationTests(TransactionTestCase):
    def test_new_schema_preserves_legacy_application_saved_offer_and_notice(self):
        executor=MigrationExecutor(connection);latest=executor.loader.graph.leaf_nodes()
        old_target=[x for x in latest if x[0]!='candidate_dashboard']+[('candidate_dashboard','0003_joboffer_category_joboffer_description_and_more')]
        try:
            executor.migrate(old_target);apps=executor.loader.project_state(old_target).apps
            U=apps.get_model('accounts','User');O=apps.get_model('candidate_dashboard','JobOffer')
            A=apps.get_model('candidate_dashboard','Application');N=apps.get_model('candidate_dashboard','Notification');S=apps.get_model('candidate_dashboard','SavedOffer')
            user=U.objects.create(email='legacy-candidate@hu018.test',role='candidato');company=U.objects.create(email='legacy-company@hu018.test',role='empresa')
            offer=O.objects.create(company_id=company.pk,title='Oferta anterior',company_name='QA',location='Pasto',contract_type='Fijo',status='published')
            item=A.objects.create(candidate_id=user.pk,offer_id=offer.pk);notice=N.objects.create(recipient_id=company.pk,title='Aviso anterior');saved=S.objects.create(candidate_id=user.pk,offer_id=offer.pk)
            timestamp=item.created_at
            executor=MigrationExecutor(connection);executor.migrate(latest)
            row=Application.objects.get(pk=item.pk)
            self.assertEqual((row.candidate_id,row.offer_id,row.created_at),(user.pk,offer.pk,timestamp))
            self.assertEqual((row.cv_source,row.cv_size_bytes,bytes(row.cv_document)),('',0,b''))
            self.assertIsNone(Notification.objects.get(pk=notice.pk).application_id)
            self.assertEqual(SavedOffer.objects.get(pk=saved.pk).offer_id,offer.pk)
        finally:MigrationExecutor(connection).migrate(latest)
