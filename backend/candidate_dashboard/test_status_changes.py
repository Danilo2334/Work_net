"""HU021: eventos reales, autorización revalidada y garantías transaccionales."""
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
from unittest.mock import patch
from uuid import uuid4
from django.db import IntegrityError, close_old_connections, transaction
from django.db import connection
from django.db.migrations.executor import MigrationExecutor
from django.test import TestCase, TransactionTestCase, override_settings
from rest_framework.test import APIClient
from .models import Application, ApplicationStatusEvent, Notification
from .test_applications import ApplicationFixture


class StatusFixture(ApplicationFixture):
    def setUp(self):
        super().setUp()
        self.submit();self.item=Application.objects.get()
        self.url=f'/api/company/applications/{self.item.pk}/status/'
        self.authenticate(self.company)

    def body(self, state='in_review', version=0, **changes):
        # ApplicationFixture.submit supplies CV inputs during setUp.
        return dict(target_status=state, expected_version=version, request_id=str(uuid4()), comment='', confirm=True)|changes

    def submit(self, source='uploaded', offer=None, body=None):
        return self.client.post(f'/api/offers/{(offer or self.offer).pk}/application/',body or ApplicationFixture.body(self,source),format='json')

    def change(self, state='in_review', version=0, **changes):
        return self.client.post(self.url,self.body(state,version,**changes),format='json')


@override_settings(PASSWORD_HASHERS=['django.contrib.auth.hashers.MD5PasswordHasher'])
class StatusTests(StatusFixture, TestCase):
    def test_confirmed_review_accept_and_notice_recipient_history_dashboard(self):
        original=Application.objects.values().get();raw=bytes(self.item.cv_document)
        r=self.change(comment='Perfil revisado.');self.assertEqual(r.status_code,200)
        event=ApplicationStatusEvent.objects.get();notice=Notification.objects.get(status_event=event)
        self.assertEqual((event.from_status,event.to_status,event.comment,event.actor_id,event.version),('submitted','in_review','Perfil revisado.',self.company.pk,1))
        self.item.refresh_from_db();self.assertEqual(self.item.status_modified_at,event.changed_at)
        self.assertEqual((notice.recipient_id,notice.application_id,notice.event_kind),(self.user.pk,self.item.pk,'application_status_changed'))
        self.assertEqual(self.change('accepted',1).status_code,200)
        self.assertEqual(Notification.objects.filter(application=self.item,event_kind='application_created').count(),1)
        self.authenticate(self.user)
        history=self.client.get('/api/applications/').data['applications'][0]
        self.assertEqual(history['status'],'accepted');self.assertEqual(history['status_change']['version'],2)
        dashboard=self.client.get('/api/dashboard/candidate/').data
        self.assertEqual(dashboard['metrics']['pending_notifications_count'],2)
        self.assertEqual(dashboard['notifications'][0]['application_id'],self.item.pk)
        self.assertIn('Aceptada',dashboard['notifications'][0]['title'])
        self.assertEqual(self.client.get(f'/api/applications/{self.item.pk}/cv/').content,raw)
        self.item.refresh_from_db()
        for field in ['created_at','candidate_id','offer_id','cv_source','cv_sha256','cv_document','cv_filename']:
            self.assertEqual(getattr(self.item,field),original[field])

    def test_reject_without_comment_terminal_and_same_state_are_not_mutations(self):
        self.assertEqual(self.change('rejected').status_code,200)
        before=Application.objects.values().get()
        for target in ['rejected','accepted','in_review']:
            self.assertEqual(self.change(target,1).status_code,409)
        self.assertEqual(Application.objects.values().get(),before)
        self.assertEqual((ApplicationStatusEvent.objects.count(),Notification.objects.count()),(1,2))

    def test_cancel_false_missing_or_non_boolean_confirmation_writes_nothing(self):
        before=Application.objects.values().get()
        for value in [False,'true',1,None]:self.assertEqual(self.change(confirm=value).status_code,400)
        body=self.body();body.pop('confirm');self.assertEqual(self.client.post(self.url,body,format='json').status_code,400)
        self.assertEqual(Application.objects.values().get(),before)
        self.assertEqual((ApplicationStatusEvent.objects.count(),Notification.objects.count()),(0,1))

    def test_replay_and_lost_response_lookup_keep_date_comment_notice_once(self):
        body=self.body(comment='Revisada');r=self.client.post(self.url,body,format='json')
        before=Application.objects.values().get();event=ApplicationStatusEvent.objects.values().get()
        again=self.client.post(self.url,body,format='json');self.assertTrue(again.data['replayed'])
        self.assertEqual(again.data['event'],r.data['event'])
        lookup=self.client.get(self.url+'operations/'+body['request_id']+'/');self.assertEqual(lookup.data['event'],r.data['event'])
        self.assertEqual(Application.objects.values().get(),before);self.assertEqual(ApplicationStatusEvent.objects.values().get(),event)
        self.assertEqual(Notification.objects.count(),2)
        self.assertEqual(self.client.get(self.url+'operations/'+str(uuid4())+'/').status_code,404)
        self.assertEqual(self.client.post(self.url,body|{'comment':'otra'},format='json').status_code,409)
        self.change('accepted',1)
        replay=self.client.post(self.url,body,format='json');self.assertTrue(replay.data['replayed'])
        self.assertEqual(replay.data['application']['status'],'accepted');self.assertEqual(replay.data['event']['to_status'],'in_review')
        self.assertEqual(Notification.objects.count(),3)

    def test_stale_version_and_input_validation_do_not_overwrite(self):
        self.assertEqual(self.change().status_code,200)
        self.assertEqual(self.change('accepted',0).status_code,409)
        for changes in [{'expected_version':True},{'expected_version':'1'},{'expected_version':-1},
                        {'target_status':'submitted'},{'comment':'x'*2001},{'comment':'bad\x00'},
                        {'request_id':'bad'},{'candidate_id':self.other.pk}]:
            self.assertEqual(self.change(version=1,**changes).status_code,400,changes)
        self.assertEqual(self.client.post(self.url+'?page=1',self.body('accepted',1),format='json').status_code,400)
        self.assertEqual(ApplicationStatusEvent.objects.count(),1)

    def test_all_actors_and_direct_id_permissions(self):
        for user,status in [(self.user,403),(self.other,403),(self.foreign_company,404)]:
            self.authenticate(user);self.assertEqual(self.change().status_code,status)
        self.client.credentials();self.assertEqual(self.change().status_code,401)
        self.authenticate(self.company)
        self.company.companyprofile.state='pending';self.company.companyprofile.save(update_fields=['state'])
        self.assertEqual(self.change().status_code,403)
        self.assertEqual(Notification.objects.count(),1)

    def test_owner_approval_is_checked_again_inside_transaction(self):
        from .status_changes import transition,StatusInput
        body=StatusInput(data=self.body());body.is_valid(raise_exception=True)
        self.company.companyprofile.state='rejected';self.company.companyprofile.save(update_fields=['state'])
        from rest_framework.exceptions import PermissionDenied
        with self.assertRaises(PermissionDenied):transition(self.company,self.item.pk,body.validated_data)
        self.assertEqual(ApplicationStatusEvent.objects.count(),0)

    def test_notice_failure_rolls_back_and_created_notice_unique(self):
        with patch('candidate_dashboard.status_changes.Notification.objects.create',side_effect=IntegrityError('failure')):
            with self.assertRaises(IntegrityError):self.change()
        self.item.refresh_from_db();self.assertEqual((self.item.status,self.item.status_version),('submitted',0))
        self.assertEqual(ApplicationStatusEvent.objects.count(),0)
        with self.assertRaises(IntegrityError),transaction.atomic():Notification.objects.create(application=self.item,recipient=self.company,title='duplicada')
        self.assertEqual(Notification.objects.count(),1)

    def test_closed_archived_context_and_original_source_deletion(self):
        self.offer.status='archived';self.offer.save(update_fields=['status']);self.uploaded.delete()
        self.assertEqual(self.change().status_code,200)
        self.assertEqual(self.client.get(f'/api/company/applications/{self.item.pk}/cv/').content,bytes(self.item.cv_document))

    def test_existing_events_cannot_be_replaced_by_new_instance_or_upsert(self):
        from django.core.exceptions import ValidationError
        self.change();original=ApplicationStatusEvent.objects.get()
        fields={f.attname:getattr(original,f.attname) for f in original._meta.fields}
        replacement=ApplicationStatusEvent(**(fields|{'comment':'sobrescrito'}))
        with self.assertRaises(IntegrityError),transaction.atomic():replacement.save()
        with self.assertRaises(ValidationError):ApplicationStatusEvent.objects.bulk_create([replacement],update_conflicts=True,update_fields=['comment'],unique_fields=['id'])
        with self.assertRaises(ValidationError):ApplicationStatusEvent.objects.filter(pk=original.pk).update(comment='sobrescrito')
        original.refresh_from_db();self.assertEqual(original.comment,'')


@override_settings(PASSWORD_HASHERS=['django.contrib.auth.hashers.MD5PasswordHasher'])
class StatusConcurrencyTests(StatusFixture, TransactionTestCase):
    def test_simultaneous_conflicting_and_repeated_operations(self):
        barrier=Barrier(2);base=self.body()
        from rest_framework.authtoken.models import Token
        token=Token.objects.get(user=self.company).key
        def send(body):
            close_old_connections();client=APIClient();client.credentials(HTTP_AUTHORIZATION='Token '+token)
            try:barrier.wait(timeout=10);return client.post(self.url,body,format='json').status_code
            finally:close_old_connections()
        with ThreadPoolExecutor(2) as pool:results=list(pool.map(send,[base,base|{'target_status':'accepted','request_id':str(uuid4())}]))
        self.assertEqual(sorted(results),[200,409]);self.assertEqual(ApplicationStatusEvent.objects.count(),1)
        self.assertEqual(Notification.objects.count(),2)
        barrier=Barrier(2)
        # Replay the exact winner simultaneously: neither date nor notice changes.
        event=ApplicationStatusEvent.objects.get();body=base|{'request_id':str(event.request_id),'target_status':event.to_status}
        with ThreadPoolExecutor(2) as pool:results=list(pool.map(send,[body,body]))
        self.assertEqual(results,[200,200]);self.assertEqual(Notification.objects.count(),2)


class StatusMigrationTests(TransactionTestCase):
    def test_old_notices_dates_documents_and_unknown_change_date_are_preserved(self):
        executor=MigrationExecutor(connection);latest=executor.loader.graph.leaf_nodes()
        target=[x for x in latest if x[0]!='candidate_dashboard']+[('candidate_dashboard','0006_candidate_selection_projection')]
        try:
            executor.migrate(target);apps=executor.loader.project_state(target).apps
            U=apps.get_model('accounts','User');A=apps.get_model('candidate_dashboard','Application')
            O=apps.get_model('candidate_dashboard','JobOffer');N=apps.get_model('candidate_dashboard','Notification')
            user=U.objects.create(email='old@status.test',full_name='Anterior',role='candidato')
            company=U.objects.create(email='old-company@status.test',full_name='Empresa',role='empresa')
            offer=O.objects.create(company_id=company.pk,title='Conservada',company_name='QA',location='Pasto',contract_type='Indefinido',status='closed')
            app=A.objects.create(candidate_id=user.pk,offer_id=offer.pk,status='accepted',cv_document=b'original-qa',cv_sha256='a'*64)
            notice=N.objects.create(application_id=app.pk,recipient_id=company.pk,title='Alta anterior')
            generic=N.objects.create(recipient_id=user.pk,title='Aviso anterior sin vínculo')
            old_date=app.created_at;notice_date=notice.created_at
            executor=MigrationExecutor(connection);executor.migrate(latest)
            row=Application.objects.get(pk=app.pk);linked=Notification.objects.get(pk=notice.pk)
            self.assertEqual((row.created_at,row.status,bytes(row.cv_document),row.cv_sha256),(old_date,'accepted',b'original-qa','a'*64))
            self.assertEqual((row.status_version,row.status_modified_at,row.status_comment),(0,None,''))
            self.assertEqual((linked.created_at,linked.recipient_id,linked.event_kind,linked.status_event_id),(notice_date,company.pk,'application_created',None))
            self.assertEqual(Notification.objects.get(pk=generic.pk).event_kind,'legacy')
            self.assertEqual(ApplicationStatusEvent.objects.count(),0)
        finally:MigrationExecutor(connection).migrate(latest)
