from unittest.mock import patch
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier, local
from uuid import uuid4
from django.db import IntegrityError, transaction
from django.db.migrations.executor import MigrationExecutor
from django.db import connection
from django.db import close_old_connections
from django.db.models import QuerySet
from django.test.utils import CaptureQueriesContext
from rest_framework.test import APIClient
from django.test import TestCase, TransactionTestCase, override_settings
from django.utils import timezone
from accounts.models import CompanyProfile, CompanyReview, User
from .models import Notification, NotificationPreference, Message, ApplicationStatusEvent
from .test_messaging import MessageFixture


@override_settings(PASSWORD_HASHERS=['django.contrib.auth.hashers.MD5PasswordHasher'])
class NotificationTests(MessageFixture, TestCase):
    root='/api/notifications/'

    def listing(self,query=''):return self.client.get(self.root+query)
    def ack(self,ids):return self.client.post(self.root+'read/',{'notification_ids':ids},format='json')
    def prefs(self,**values):return self.client.patch(self.root+'preferences/',values,format='json')

    def test_all_four_domain_events_have_unique_sources_and_derived_recipients(self):
        creation=Notification.objects.get(event_kind='application_created');self.assertEqual(creation.recipient_id,self.company.pk)
        self.authenticate(self.company)
        key=str(uuid4());body=dict(target_status='in_review',expected_version=0,request_id=key,confirm=True)
        url=f'/api/company/applications/{self.item.pk}/status/'
        self.assertEqual(self.client.post(url,body,format='json').status_code,200)
        self.assertEqual(self.client.post(url,body,format='json').status_code,200)
        status=Notification.objects.get(event_kind='application_status_changed');self.assertEqual(status.recipient_id,self.user.pk)
        sent=self.send('Aviso de mensaje');self.assertEqual(sent.status_code,201)
        notice=Notification.objects.get(event_kind='message_received');self.assertEqual(notice.recipient_id,self.user.pk)
        msg=Message.objects.get();self.assertEqual(notice.message_id,msg.pk)
        self.send('Aviso de mensaje',key=msg.client_message_id)
        self.assertEqual(Notification.objects.filter(message=msg).count(),1)
        admin=User.objects.create_user('admin@notice.test','QA123456!',is_staff=True,email_verified=True)
        profile=CompanyProfile.objects.get(company=self.company);profile.state='pending';profile.submitted_at=timezone.now();profile.save()
        self.authenticate(admin)
        r=self.client.post(f'/api/admin/companies/{profile.pk}/review/',dict(decision='rejected',reason='Documento QA incompleto',version=profile.version),format='json')
        self.assertEqual(r.status_code,200)
        review=CompanyReview.objects.get(action='rejected')
        self.assertEqual(Notification.objects.get(company_review=review).recipient_id,self.company.pk)
        self.assertEqual(self.client.post(f'/api/admin/companies/{profile.pk}/review/',dict(decision='approved',version=profile.version),format='json').status_code,409)
        self.assertEqual(Notification.objects.filter(company_review=review).count(),1)

    def test_rejected_and_pending_company_can_read_own_but_not_dashboard(self):
        self.authenticate(self.company)
        for state in ['pending','rejected']:
            CompanyProfile.objects.filter(company=self.company).update(state=state)
            r=self.listing();self.assertEqual(r.status_code,200);self.assertEqual(r.data['count'],1)
            self.assertEqual(self.client.get('/api/dashboard/company/').status_code,403)
        self.assertEqual(self.ack([Notification.objects.get().pk]).data['unread_count'],0)

    def test_history_anchor_pages_unread_and_no_implicit_read(self):
        notices=[Notification.objects.create(recipient=self.user,title=f'Aviso QA {i}') for i in range(12)]
        r=self.listing('?page_size=10');self.assertEqual((r.data['count'],r.data['unread_count'],len(r.data['notifications'])),(12,12,10))
        anchor=r.data['through_id'];seen={x['id'] for x in r.data['notifications']}
        new=Notification.objects.create(recipient=self.user,title='Llegada posterior')
        tail=self.listing(f'?page=2&page_size=10&through_id={anchor}').data
        self.assertEqual((tail['count'],len(tail['notifications'])),(12,2))
        self.assertFalse(seen & {x['id'] for x in tail['notifications']});self.assertEqual(tail['unread_count'],13)
        self.assertNotIn(new.pk,seen)
        self.ack([notices[0].pk]);self.assertEqual(self.listing('?status=read').data['count'],1)
        self.assertEqual(self.listing('?status=unread').data['count'],12)
        self.assertEqual(self.client.get(self.root+'summary/').data['unread_count'],12)

    def test_listing_does_not_load_frozen_pdf_or_message_text(self):
        self.authenticate(self.company)
        with CaptureQueriesContext(connection) as queries:
            response=self.listing()
        self.assertEqual(response.status_code,200)
        sql=' '.join(q['sql'] for q in queries.captured_queries)
        self.assertNotIn('cv_document',sql)
        self.assertNotIn('"candidate_dashboard_message"."text"',sql)
        self.assertEqual(response.data['notifications'][0]['offer_id'],self.offer.pk)

    def test_read_is_owned_atomic_idempotent_and_independent_from_message(self):
        self.authenticate(self.company);sent=self.send().data['message'];self.authenticate(self.user)
        own=Notification.objects.get(message_id=sent['id']);foreign=Notification.objects.get(event_kind='application_created')
        self.assertEqual(self.ack([own.pk,foreign.pk]).status_code,404)
        own.refresh_from_db();self.assertIsNone(own.read_at)
        self.assertEqual(self.ack([own.pk]).data['marked_read'],1);own.refresh_from_db();first=own.read_at
        later=Notification.objects.create(recipient=self.user,title='Posterior')
        self.assertEqual(self.ack([own.pk]).data,{'marked_read':0,'unread_count':1})
        own.refresh_from_db();self.assertEqual(first,own.read_at)
        self.assertIsNone(Message.objects.get(pk=sent['id']).read_at)
        later.refresh_from_db();self.assertIsNone(later.read_at)

    def test_preferences_future_only_preserve_history_and_no_retroactive_replay(self):
        self.authenticate(self.company);old=self.send('Primero').data['message'];self.authenticate(self.user)
        self.assertEqual(self.prefs(message_received=False).status_code,200)
        self.authenticate(self.company);new=self.send('Suprimido').data['message'];self.authenticate(self.user)
        self.assertEqual(self.listing().data['count'],1)
        self.assertTrue(Notification.objects.filter(message_id=old['id']).exists());self.assertFalse(Notification.objects.filter(message_id=new['id']).exists())
        self.assertEqual(self.prefs(message_received=True).status_code,200)
        self.authenticate(self.company);self.send('Suprimido',key=new['client_message_id'])
        self.assertFalse(Notification.objects.filter(message_id=new['id']).exists())
        self.send('Otro evento');self.assertEqual(Notification.objects.filter(recipient=self.user).count(),2)

    def test_preferences_do_not_change_legacy_push_or_other_account_and_validate_strictly(self):
        self.user.push_notifications=False;self.user.save(update_fields=['push_notifications'])
        response=self.prefs(application_created=False);self.assertEqual(response.data['scope'],'future_events_only')
        self.user.refresh_from_db();self.assertFalse(self.user.push_notifications)
        self.assertEqual(NotificationPreference.objects.count(),1)
        for payload in [{},{'message_received':'false'},{'recipient':self.other.pk},{'company_reviewed':1}]:
            self.assertEqual(self.client.patch(self.root+'preferences/',payload,format='json').status_code,400)
        self.authenticate(self.other);self.assertTrue(self.client.get(self.root+'preferences/').data['preferences']['application_created'])

    def test_suppressed_status_and_application_still_persist_and_replay_without_notice(self):
        self.prefs(application_status_changed=False)
        self.authenticate(self.company);self.prefs(application_created=False)
        body=dict(target_status='accepted',expected_version=0,request_id=str(uuid4()),confirm=True)
        url=f'/api/company/applications/{self.item.pk}/status/'
        self.assertEqual(self.client.post(url,body,format='json').status_code,200)
        self.assertEqual(ApplicationStatusEvent.objects.count(),1);self.assertFalse(Notification.objects.filter(event_kind='application_status_changed').exists())
        self.authenticate(self.user);other=self.make_offer();self.assertEqual(self.submit(offer=other).status_code,201)
        self.assertFalse(Notification.objects.filter(application__offer=other).exists())

    def test_transaction_failure_rolls_back_message_and_activity(self):
        before=self.conv.last_activity_at
        with patch('candidate_dashboard.notification_events.Notification.objects.create',side_effect=RuntimeError('fallo local controlado')):
            with self.assertRaises(RuntimeError):self.send()
        self.assertEqual(Message.objects.count(),0);self.conv.refresh_from_db();self.assertEqual(self.conv.last_activity_at,before)

    def test_unique_message_notice_and_context_database_constraints(self):
        self.send();msg=Message.objects.get();notice=Notification.objects.get(message=msg)
        with self.assertRaises(IntegrityError),transaction.atomic():
            Notification.objects.create(recipient=self.company,event_kind='message_received',message=msg,title='Duplicado')
        with self.assertRaises(IntegrityError),transaction.atomic():
            Notification.objects.create(recipient=self.user,event_kind='message_received',title='Sin contexto')
        self.assertEqual(Notification.objects.get(pk=notice.pk).title,notice.title)

    def test_invalid_params_methods_and_session(self):
        for query in ['?page=0','?page_size=51','?status=x','?page=2','?page=1&page=1','?owner=1','?through_id=-1','?through_id=999999999999999999999999999999']:
            self.assertEqual(self.listing(query).status_code,400,query)
        for ids in [[],[True],[1,1],['1'],list(range(1,52))]:self.assertEqual(self.ack(ids).status_code,400)
        self.assertEqual(self.client.post(self.root,{},format='json').status_code,405)
        self.user.email_verified=False;self.user.save(update_fields=['email_verified']);self.assertEqual(self.listing().status_code,403)
        self.user.is_active=False;self.user.save(update_fields=['is_active']);self.assertEqual(self.listing().status_code,401)
        self.client.credentials();self.assertEqual(self.listing().status_code,401)


@override_settings(PASSWORD_HASHERS=['django.contrib.auth.hashers.MD5PasswordHasher'])
class ConcurrentNotificationPreferencesTests(MessageFixture,TransactionTestCase):
    def test_first_partial_preferences_writes_conserve_both_values_under_contention(self):
        auth=self.client._credentials['HTTP_AUTHORIZATION']
        barrier=Barrier(2);thread=local();original=QuerySet.create
        def create(query,**values):
            if query.model is NotificationPreference and connection.vendor=='sqlite' and not getattr(thread,'waited',False):
                thread.waited=True;barrier.wait(timeout=10)
            return original(query,**values)
        def update(key):
            close_old_connections()
            try:
                client=APIClient();client.credentials(HTTP_AUTHORIZATION=auth)
                return client.patch('/api/notifications/preferences/',{key:False},format='json').status_code
            finally:close_old_connections()
        with patch.object(QuerySet,'create',create),ThreadPoolExecutor(max_workers=2) as pool:
            responses=list(pool.map(update,['message_received','company_reviewed']))
        self.assertEqual(responses,[200,200]);self.assertEqual(NotificationPreference.objects.count(),1)
        item=NotificationPreference.objects.get(user=self.user)
        self.assertFalse(item.message_received);self.assertFalse(item.company_reviewed)
        self.assertTrue(item.application_created);self.assertTrue(item.application_status_changed)


class NotificationMigrationTests(TransactionTestCase):
    def test_0008_to_0009_preserves_existing_ids_dates_recipients_types_and_reads(self):
        executor=MigrationExecutor(connection)
        # Resolve the historical migration by its actual prefix, keeping this test
        # compatible with the existing descriptive migration filename.
        name=next(n for app,n in executor.loader.disk_migrations if app=='candidate_dashboard' and n.startswith('0008_'))
        old=[('candidate_dashboard',name)]+[x for x in executor.loader.graph.leaf_nodes() if x[0]=='accounts'];executor.migrate(old)
        try:
            state=executor.loader.project_state(old).apps;U=state.get_model('accounts','User');N=state.get_model('candidate_dashboard','Notification')
            user=U.objects.create(email='legacy-notice@qa.test',full_name='Legado',email_verified=True,role='empresa')
            notice=N.objects.create(recipient=user,title='Aviso anterior',read_at=timezone.now())
            original=N.objects.values().get(pk=notice.pk)
            executor=MigrationExecutor(connection);executor.migrate(executor.loader.graph.leaf_nodes())
            current=Notification.objects.values().get(pk=notice.pk)
            self.assertEqual({k:current[k] for k in original},original)
            self.assertIsNone(current['message_id']);self.assertIsNone(current['company_review_id'])
        finally:
            executor=MigrationExecutor(connection);executor.migrate(executor.loader.graph.leaf_nodes())
