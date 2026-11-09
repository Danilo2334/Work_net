from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
from uuid import uuid4
from django.db import close_old_connections, connection
from django.test import TestCase, TransactionTestCase, override_settings
from django.test.utils import CaptureQueriesContext
from rest_framework.test import APIClient
from .models import Application, Conversation, Message
from .test_applications import ApplicationFixture


class MessageFixture(ApplicationFixture):
    def setUp(self):
        super().setUp();self.submit();self.item=Application.objects.get()
        created=self.client.post('/api/conversations/',{'application_id':self.item.pk},format='json')
        self.conv=Conversation.objects.get(pk=created.data['conversation']['id'])
        self.url=f'/api/conversations/{self.conv.pk}/'

    def send(self,text='Mensaje QA',key=None,**extra):
        return self.client.post(self.url+'messages/',{'text':text,'client_message_id':str(key or uuid4())}|extra,format='json')

    def read(self,ids):return self.client.post(self.url+'read/',{'message_ids':ids},format='json')
    def summary(self):return self.client.get('/api/messages/summary/').data['unread_count']


@override_settings(PASSWORD_HASHERS=['django.contrib.auth.hashers.MD5PasswordHasher'])
class MessagingTests(MessageFixture,TestCase):
    def test_conversation_is_unique_per_real_application_and_has_canonical_contact(self):
        first=self.client.get(self.url);self.assertEqual(first.status_code,200)
        self.assertEqual((first.data['conversation']['contact']['id'],first.data['conversation']['offer']['id']),(self.company.pk,self.offer.pk))
        again=self.client.post('/api/conversations/',{'application_id':self.item.pk},format='json')
        self.assertEqual((again.status_code,again.data['created'],again.data['conversation']['id']),(200,False,self.conv.pk))
        self.authenticate(self.company)
        other=self.client.post('/api/conversations/',{'application_id':self.item.pk},format='json')
        self.assertEqual(other.data['conversation']['contact']['id'],self.user.pk)
        self.assertEqual(Conversation.objects.count(),1)
        self.assertEqual(self.client.get(self.url+'messages/').data['messages'],[])
        self.assertEqual(self.summary(),0)

    def test_bidirectional_real_text_dates_recipient_and_plain_content(self):
        text='<script>texto, no HTML</script>\nSegunda línea'
        a=self.send(text);self.assertEqual(a.status_code,201)
        self.assertEqual((a.data['message']['sender_id'],a.data['message']['recipient_id'],a.data['message']['text']),(self.user.pk,self.company.pk,text))
        self.assertIsNotNone(a.data['message']['created_at']);self.assertIsNone(a.data['message']['read_at'])
        self.assertEqual(self.summary(),0)
        self.authenticate(self.company);self.assertEqual(self.summary(),1)
        b=self.send('Respuesta empresa');self.assertEqual(b.status_code,201)
        self.assertEqual(b.data['message']['recipient_id'],self.user.pk)
        rows=self.client.get(self.url+'messages/').data['messages']
        self.assertEqual([m['text'] for m in rows],[text,'Respuesta empresa'])
        self.authenticate(self.user);self.assertEqual(self.summary(),1)

    def test_get_does_not_read_and_ack_only_received_ids_preserves_new_messages(self):
        a=self.send().data['message'];self.authenticate(self.company)
        viewed=self.client.get(self.url+'messages/').data['messages'];self.assertEqual(self.summary(),1)
        self.authenticate(self.user);b=self.send('Nuevo durante lectura').data['message']
        self.authenticate(self.company)
        ack=self.read([m['id'] for m in viewed]);self.assertEqual(ack.data,{'marked_read':1,'unread_count':1})
        stamp=Message.objects.get(pk=a['id']).read_at
        repeated=self.read([a['id']]);self.assertEqual(repeated.data['marked_read'],0)
        self.assertEqual(Message.objects.get(pk=a['id']).read_at,stamp)
        self.assertIsNone(Message.objects.get(pk=b['id']).read_at)
        self.assertEqual(self.summary(),1)
        self.assertEqual(self.read([b['id']]).data['unread_count'],0)

    def test_ack_rejects_sent_foreign_duplicate_boolean_or_unbounded_ids_atomically(self):
        sent=self.send().data['message'];self.authenticate(self.company);incoming=self.send('Empresa').data['message'];self.authenticate(self.user)
        self.assertEqual(self.read([incoming['id'],sent['id']]).status_code,404)
        self.assertIsNone(Message.objects.get(pk=incoming['id']).read_at)
        for ids in [[incoming['id'],incoming['id']],[True],list(range(1,52))]:self.assertEqual(self.read(ids).status_code,400)
        self.assertEqual(self.read([]).data['marked_read'],0)
        self.assertEqual(self.read([incoming['id']]).data['marked_read'],1)

    def test_retry_and_lost_response_get_are_idempotent_but_equal_text_new_key_is_valid(self):
        key=uuid4();first=self.send('Texto igual',key);again=self.send('Texto igual',key)
        self.assertEqual((first.status_code,again.status_code),(201,200));self.assertEqual(first.data['message'],again.data['message'])
        lookup=self.client.get(self.url+'messages/operations/'+str(key)+'/');self.assertEqual(lookup.data['message'],first.data['message'])
        self.assertEqual(self.send('Otro texto',key).status_code,409)
        self.assertEqual(self.send('Texto igual').status_code,201)
        self.assertEqual(Message.objects.count(),2)
        self.authenticate(self.company)
        self.assertEqual(self.client.get(self.url+'messages/operations/'+str(key)+'/').status_code,404)

    def test_queries_are_bounded_and_windows_are_stable_when_new_message_arrives(self):
        ids=[self.send(str(i)).data['message']['id'] for i in range(13)]
        p1=self.client.get(self.url+'messages/?page_size=5').data
        self.assertEqual([m['id'] for m in p1['messages']],ids[-5:])
        self.send('Nuevo fuera de ventana')
        p2=self.client.get(self.url+f'messages/?page_size=5&page=2&through_id={p1["through_id"]}').data
        self.assertEqual([m['id'] for m in p2['messages']],ids[-10:-5])
        self.assertFalse(set(m['id'] for m in p1['messages'])&set(m['id'] for m in p2['messages']))
        self.assertEqual((p1['count'],p2['count']),(13,13))
        self.assertEqual(self.client.get(self.url+'messages/?page_size=5').data['count'],14)
        for query in ['page_size=51','page=999','through_id=-1','sender_id=2','page=1&page=1']:
            self.assertEqual(self.client.get(self.url+'messages/?'+query).status_code,400,query)

    def test_authorized_search_order_page_reset_contract_and_no_n_plus_one(self):
        self.send('Primero')
        for title in ['Diseño QA','Backend QA','Sin coincidencia']:
            app=Application.objects.create(candidate=self.user,offer=self.make_offer(title=title))
            self.client.post('/api/conversations/',{'application_id':app.pk},format='json')
        with CaptureQueriesContext(connection) as queries:r=self.client.get('/api/conversations/?q=QA&page_size=2')
        self.assertEqual(r.status_code,200);self.assertEqual(r.data['count'],4)
        self.assertLessEqual(len(queries),7)
        p2=self.client.get('/api/conversations/?q=QA&page_size=2&page=2').data
        self.assertFalse(set(c['id'] for c in r.data['conversations'])&set(c['id'] for c in p2['conversations']))
        self.assertEqual(self.client.get('/api/conversations/?q=Backend').data['count'],1)
        self.assertEqual(self.client.get('/api/conversations/?q=inexistente').data['conversations'],[])
        self.assertEqual(self.client.get('/api/conversations/?q=Backend&q=QA').status_code,400)
        self.assertEqual(self.client.get('/api/conversations/?q='+'x'*101).status_code,400)

    def test_all_direct_operations_isolate_unrelated_candidate_company_and_anonymous(self):
        msg=self.send().data['message']
        for actor in [self.other,self.foreign_company]:
            self.authenticate(actor)
            self.assertEqual(self.client.get('/api/conversations/?q=QA').data['count'],0)
            self.assertEqual(self.summary(),0)
            self.assertEqual(self.client.post('/api/conversations/',{'application_id':self.item.pk},format='json').status_code,404)
            self.assertEqual(self.client.get(self.url).status_code,404)
            self.assertEqual(self.client.get(self.url+'messages/').status_code,404)
            self.assertEqual(self.send().status_code,404)
            self.assertEqual(self.read([msg['id']]).status_code,404)
        self.client.credentials();self.assertEqual(self.client.get('/api/conversations/').status_code,401)
        self.assertEqual(self.send().status_code,401)

    def test_pending_unverified_disabled_counterpart_and_restored_authorization(self):
        self.send();self.authenticate(self.company)
        self.company.companyprofile.state='pending';self.company.companyprofile.save(update_fields=['state'])
        for url in ['/api/conversations/',self.url,self.url+'messages/','/api/messages/summary/']:self.assertEqual(self.client.get(url).status_code,403)
        self.authenticate(self.user);self.assertEqual(self.client.get('/api/conversations/').data['count'],0)
        self.assertEqual(self.send().status_code,404)
        self.company.companyprofile.state='approved';self.company.companyprofile.save(update_fields=['state'])
        self.user.email_verified=False;self.user.save(update_fields=['email_verified'])
        self.assertEqual(self.client.get('/api/conversations/').status_code,403)
        self.user.email_verified=True;self.user.save(update_fields=['email_verified'])
        self.assertEqual(self.client.get('/api/conversations/').data['count'],1);self.assertEqual(Message.objects.count(),1)

    def test_text_validation_strict_inputs_and_no_arbitrary_participant_fields(self):
        for text in ['', '  \n\t ',None,33,'x'*4001,'bad\x00']:
            self.assertEqual(self.send(text).status_code,400,repr(text)[:30])
        self.assertEqual(self.send('texto',recipient_id=self.other.pk).status_code,400)
        self.assertEqual(self.send('texto',sender_id=self.company.pk).status_code,400)
        self.assertEqual(self.client.post('/api/conversations/',{'application_id':True},format='json').status_code,400)
        r=self.send('  Línea uno\r\nLínea dos  ');self.assertEqual(r.data['message']['text'],'Línea uno\nLínea dos')
        self.assertEqual(self.send('x'*4000).status_code,201)

    def test_closed_archived_and_final_status_preserve_conversation_and_content(self):
        self.send('Conservado')
        for offer_state in ['closed','archived']:
            self.offer.status=offer_state;self.offer.save(update_fields=['status'])
            Application.objects.filter(pk=self.item.pk).update(status='rejected')
            self.assertEqual(self.client.get(self.url).status_code,200)
            self.assertEqual(self.client.get(self.url+'messages/').data['messages'][0]['text'],'Conservado')
        self.authenticate(self.company);self.assertEqual(self.send('Respuesta conservada').status_code,201)


@override_settings(PASSWORD_HASHERS=['django.contrib.auth.hashers.MD5PasswordHasher'])
class MessagingConcurrencyTests(MessageFixture,TransactionTestCase):
    def test_two_simultaneous_retries_and_equal_legitimate_messages(self):
        from rest_framework.authtoken.models import Token
        token=Token.objects.get(user=self.user).key;key=str(uuid4());barrier=Barrier(2)
        def send(client_id):
            close_old_connections();client=APIClient();client.credentials(HTTP_AUTHORIZATION='Token '+token)
            try:barrier.wait(timeout=10);return client.post(self.url+'messages/',{'text':'Igual legítimo','client_message_id':client_id},format='json').status_code
            finally:close_old_connections()
        with ThreadPoolExecutor(2) as pool:results=list(pool.map(send,[key,key]))
        self.assertEqual(sorted(results),[200,201]);self.assertEqual(Message.objects.count(),1)
        barrier=Barrier(2)
        with ThreadPoolExecutor(2) as pool:results=list(pool.map(send,[str(uuid4()),str(uuid4())]))
        self.assertEqual(results,[201,201]);self.assertEqual(Message.objects.count(),3)
