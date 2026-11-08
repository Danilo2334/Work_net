"""HU021/HU022: nuevas QA aisladas; actores y contraste de eventos/mensajes reales."""
import argparse
from hashlib import sha256
import importlib.util
import json
from pathlib import Path
import shutil
import sqlite3
import uuid

from hu016_api import connect, require
from hu018_api import HERE, configure, client
from hu01920_api import fixtures as previous_fixtures, api_for


def call(api, method, path, data=None, expected=200):
    response=getattr(api,method.lower())('/api/'+path, data, format='json') if data is not None else getattr(api,method.lower())('/api/'+path)
    require(response.status_code==expected)
    return response.data


def fixtures(run):
    previous_fixtures(run)
    with (run/'.hu02122-prepared').open('x',encoding='utf-8') as f:f.write('HU021/HU022: otra QA, solo actores ficticios.\n')
    from django.db import connection
    from accounts.models import User
    from candidate_dashboard.models import Application,CandidateProfile,Conversation,Message,Notification,JobOffer,active_offers
    previous=json.loads((run/'hu01920-baseline.json').read_text(encoding='utf-8'))
    api,own=client('candidate');company,company_user=client('company')
    profile=CandidateProfile.objects.get(candidate=own)
    profile.languages=[{'name':'Español','level':'nativo'}];profile.save(update_fields=['languages'])
    convs={}
    for item in Application.objects.filter(candidate=own).exclude(pk=previous['own_ids']['13']).order_by('pk'):
        result=call(api,'POST','conversations/',{'application_id':item.pk},201)
        convs[str(item.offer_id)]=result['conversation']['id']
    foreign_app=Application.objects.get(pk=previous['foreign_application'])
    foreign=call(api_for(foreign_app.candidate),'POST','conversations/',{'application_id':foreign_app.pk},201)['conversation']['id']
    extra=Application.objects.filter(offer_id=3).exclude(candidate=own).order_by('pk').first()
    extra_conv=call(company,'POST','conversations/',{'application_id':extra.pk},201)['conversation']['id']
    message_ids=[];recipient_ids={'candidate':[],'company':[]}
    for i in range(23):
        actor=company if i%2==0 else api
        r=call(actor,'POST',f'conversations/{convs["4"]}/messages/',{'text':f'Mensaje previo ficticio QA {i+1:02}', 'client_message_id':str(uuid.uuid4())},201)
        message_ids.append(r['message']['id']);recipient_ids['candidate' if i%2==0 else 'company'].append(r['message']['id'])
    for role,ids in recipient_ids.items():
        actor=api if role=='candidate' else company
        r=call(actor,'POST',f'conversations/{convs["4"]}/read/',{'message_ids':ids});require(r['unread_count']==0)
    dashboard=call(api,'GET','dashboard/candidate/');company_dashboard=call(company,'GET','dashboard/company/')
    require(dashboard['profile_completion']['percentage']==100)
    baseline=previous|{'conversations':Conversation.objects.count(),'candidate_conversations':12,'company_conversations':13,
        'conversation_ids':convs,'foreign_conversation':foreign,'extra_company_conversation':extra_conv,
        'pagination_message_ids':message_ids,'messages':Message.objects.count(),'status_events':0,
        'candidate_id':own.pk,'company_id':company_user.pk,'notices':Notification.objects.count(),
        'candidate_metrics':dashboard['metrics'],'company_metrics':company_dashboard['metrics'],
        'actor_qa':'Preparación nueva por APIClient existente. Estados previos son fixtures con fecha de transición desconocida; no se atribuyen a UI empresarial. Conversaciones y 23 mensajes previos se prepararon y leyeron por la API HU022.'}
    require(baseline['conversations']==14 and baseline['messages']==23)
    (run/'hu02122-baseline.json').write_text(json.dumps(baseline,default=str,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    connection.close();shutil.copy2(run/'qa.sqlite3',run/'initial.sqlite3')
    return baseline


def seed(run):
    require((run/'.hu02122-prepared').is_file())
    return json.loads((run/'hu02122-baseline.json').read_text(encoding='utf-8'))


def action(run,name):
    b=seed(run);configure(run)
    company,_=client('company')
    if name=='concurrent_review':
        pk=b['own_ids']['11'];r=call(company,'POST',f'company/applications/{pk}/status/',{
            'target_status':'in_review','expected_version':0,'request_id':str(uuid.uuid4()),
            'comment':'Revisión concurrente QA identificada','confirm':True})
        return {'actor_qa':'empresa_ficticia_concurrente','method':'POST','path':f'/api/company/applications/{pk}/status/',
                'event':r['event'],'procedencia':'Cambio real mediante API HU021 por otro actor QA; no ORM ni una operación de esta pantalla.'}
    if name=='message_during_read':
        from candidate_dashboard.models import Conversation
        conv=Conversation.objects.get(application_id=b['own_ids']['13']).pk;r=call(company,'POST',f'conversations/{conv}/messages/',{
            'text':'Mensaje nuevo durante lectura QA','client_message_id':str(uuid.uuid4())},201)
        return {'actor_qa':'empresa_ficticia_concurrente','method':'POST','path':f'/api/conversations/{conv}/messages/',
                'message_id':r['message']['id'],'procedencia':'Otro actor API real entre consulta y confirmación de lectura; no inyección de respuesta.'}
    if name in ('message_outside_window','candidate_pending'):
        from candidate_dashboard.models import Conversation
        api,_=client('candidate')
        conv=b['conversation_ids']['4'] if name=='message_outside_window' else Conversation.objects.get(application_id=b['own_ids']['13']).pk
        text='Nuevo fuera de ventana QA' if name=='message_outside_window' else 'Pendiente real para probar recuperación de lectura QA'
        r=call(api,'POST',f'conversations/{conv}/messages/',{'text':text,'client_message_id':str(uuid.uuid4())},201)
        return {'actor_qa':'candidato_ficticio_concurrente','method':'POST','path':f'/api/conversations/{conv}/messages/',
                'message_id':r['message']['id'],'procedencia':'Mensaje real mediante API HU022 del otro actor; no fue escrito desde esta pantalla.'}
    if name=='delete_sources':
        from hu01920_api import action as previous_action
        return previous_action(run,'replace_delete_sources')
    require(False)


def contrast(run):
    b=seed(run)
    from pypdf import PdfReader
    from io import BytesIO
    with connect(run) as db,sqlite3.connect(run/'initial.sqlite3') as initial:
        initial.row_factory=sqlite3.Row
        def rows(c,table):return [dict(r) for r in c.execute('SELECT * FROM '+table+' ORDER BY id')]
        apps=rows(db,'candidate_dashboard_application');old=rows(initial,'candidate_dashboard_application')
        old_ids={r['id'] for r in old};new=[r for r in apps if r['id'] not in old_ids]
        variable={'status','status_version','status_comment','status_modified_at'}
        unchanged=lambda seq:[{k:v for k,v in r.items() if k not in variable} for r in seq]
        require(unchanged([r for r in apps if r['id'] in old_ids])==unchanged(old))
        events=rows(db,'candidate_dashboard_applicationstatusevent')
        notices=rows(db,'candidate_dashboard_notification');original_notices=rows(initial,'candidate_dashboard_notification')
        require([r for r in notices if r['id'] in {x['id'] for x in original_notices}]==original_notices)
        for item in apps:
            own_events=[e for e in events if e['application_id']==item['id']]
            require([e['version'] for e in own_events]==list(range(1,len(own_events)+1)))
            require(item['status_version']==len(own_events))
            if own_events:
                e=own_events[-1];require((item['status'],item['status_comment'],item['status_modified_at'])==(e['to_status'],e['comment'],e['changed_at']))
            elif item['id'] in old_ids:
                previous=next(r for r in old if r['id']==item['id']);require(item==previous)
            if item['cv_source']:
                raw=bytes(item['cv_document']);require(sha256(raw).hexdigest()==item['cv_sha256'] and len(raw)==item['cv_size_bytes'])
                require(len(PdfReader(BytesIO(raw)).pages)>0)
        for event in events:
            app=next(r for r in apps if r['id']==event['application_id'])
            owner=db.execute('SELECT company_id FROM candidate_dashboard_joboffer WHERE id=?',(app['offer_id'],)).fetchone()[0]
            require(event['actor_id']==owner)
            linked=[r for r in notices if r['status_event_id']==event['id']]
            require(len(linked)==1 and linked[0]['recipient_id']==app['candidate_id'] and linked[0]['event_kind']=='application_status_changed')
        for app in apps:
            created=[r for r in notices if r['application_id']==app['id'] and r['event_kind']=='application_created']
            if app['id'] in old_ids:require(created==[r for r in original_notices if r['application_id']==app['id']])
            else:require(len(created)==1)
        require(len(notices)-len(original_notices)==len(events)+len(new))
        require(len(new)<=1)
        other_id=db.execute("SELECT id FROM accounts_user WHERE email='other.postman@worknet.test'").fetchone()[0]
        require(all(r['candidate_id']==other_id and r['offer_id']==12 for r in new))
        messages=rows(db,'candidate_dashboard_message');previous_messages=rows(initial,'candidate_dashboard_message')
        require([r for r in messages if r['id'] in {x['id'] for x in previous_messages}]==previous_messages)
        convs=rows(db,'candidate_dashboard_conversation');prior_convs=rows(initial,'candidate_dashboard_conversation')
        for c in prior_convs:
            current=next(x for x in convs if x['id']==c['id'])
            require((current['application_id'],current['created_at'])==(c['application_id'],c['created_at']))
        for m in messages:
            c=next(x for x in convs if x['id']==m['conversation_id']);app=next(x for x in apps if x['id']==c['application_id'])
            owner=db.execute('SELECT company_id FROM candidate_dashboard_joboffer WHERE id=?',(app['offer_id'],)).fetchone()[0]
            require({m['sender_id'],m['recipient_id']}=={app['candidate_id'],owner})
            require(isinstance(m['text'],str) and 1<=len(m['text'])<=4000)
        require(not db.execute('SELECT 1 FROM candidate_dashboard_message GROUP BY conversation_id,sender_id,client_message_id HAVING COUNT(*)>1').fetchall())
        require(not db.execute('SELECT 1 FROM candidate_dashboard_application GROUP BY candidate_id,offer_id HAVING COUNT(*)>1').fetchall())
        conserved={}
        for table in ('candidate_dashboard_candidateprofile','candidate_dashboard_joboffer','candidate_dashboard_savedoffer'):
            conserved[table]=rows(db,table)==rows(initial,table);require(conserved[table])
        return {'offers':len(rows(db,'candidate_dashboard_joboffer')),'applications':len(apps),'new_applications':len(new),
            'status_events':len(events),'new_status_notices':len(events),'new_created_notices':len(new),
            'conversations':len(convs),'new_conversations':len(convs)-len(prior_convs),'messages':len(messages),'new_messages':len(messages)-len(previous_messages),
            'message_intent_duplicates':0,'application_duplicates':0,'old_application_content_dates_relations_and_pdfs_unchanged':True,
            'old_notices_unchanged':True,'old_messages_and_read_dates_unchanged':True,'new_status_notice_recipient_version_and_atomic_relation_correct':True,
            'legacy_application_status_dates_not_invented':True,'conserved':conserved,
            'principal_sources_remaining':sum(db.execute('SELECT COUNT(*) FROM '+table+' WHERE candidate_id=?',(b['candidate_id'],)).fetchone()[0] for table in ('curriculum_uploadedcurriculum','curriculum_generatedcurriculum'))}


def collection(run,port):
    b=seed(run);own=b['own_ids'];conv=b['conversation_ids'];items=[];counts={'HU021':0,'HU022':0}
    def add(tag,name,path,*,actor='company',method='GET',data=None,code=200,check=None,pdf=False):
        counts[tag]+=1
        request={'method':method,'url':'{{base_url}}/'+path,'auth':{'type':'noauth'},'header':[]}
        if actor:request['header'].append({'key':'Authorization','value':'Token {{'+actor+'_token}}'})
        if data is not None:
            request['header'].append({'key':'Content-Type','value':'application/json'})
            request['body']={'mode':'raw','raw':json.dumps(data,ensure_ascii=False)}
        tests=[f"pm.test('HTTP {code}',()=>pm.response.to.have.status({code}));"]
        if pdf:tests.append("pm.test('PDF enviado privado',()=>{pm.expect(pm.response.headers.get('Content-Type')).include('application/pdf');pm.expect(pm.response.headers.get('Cache-Control')).include('no-store');pm.expect(pm.response.text().startsWith('%PDF-')).eq(true);});")
        elif check:tests+=['const b=pm.response.json();',"pm.test('Contrato "+tag+"',()=>{"+check+"});"]
        items.append({'name':f'{tag}-P{counts[tag]:02} · '+name,'request':request,'event':[{'listen':'test','script':{'type':'text/javascript','exec':tests}}]})
    def s(name,path=None,**kw):add('HU021',name,path or f'company/applications/{own["3"]}/status/',**kw)
    def m(name,path='conversations/',**kw):add('HU022',name,path,**kw)
    def state(target,version,rid=None,comment=None,confirm=True):
        data={'target_status':target,'expected_version':version,'request_id':rid or str(uuid.uuid4()),'confirm':confirm}
        if comment is not None:data['comment']=comment
        return data
    review=state('in_review',0,comment='Revisión empresarial real QA')
    accepted=state('accepted',1)
    s('Contexto y documento original',check="pm.expect(b.application.status).eq('submitted');pm.expect(b.application.status_change.version).eq(0);pm.collectionVariables.set('original_date',b.application.created_at);pm.collectionVariables.set('uploaded_hash',b.application.cv.sha256);")
    s('Cancelar confirmación conserva datos',method='POST',data=state('in_review',0,confirm=False),code=400)
    s('Estado sin cambios tras cancelar',check="pm.expect(b.application.status).eq('submitted');pm.expect(b.application.status_change.modified_at).eq(null);pm.expect(b.application.status_change.comment).eq('');")
    s('Cambiar a En revisión con comentario',method='POST',data=review,check="pm.expect(b.replayed).eq(false);pm.expect(b.application.status).eq('in_review');pm.expect(b.application.status_change.comment).eq('Revisión empresarial real QA');pm.expect(b.application.status_change.version).eq(1);pm.expect(b.event.changed_at).eq(b.application.status_change.modified_at);pm.collectionVariables.set('review_date',b.event.changed_at);")
    s('Reintento mismo UUID no duplica aviso',method='POST',data=review,check="pm.expect(b.replayed).eq(true);pm.expect(b.application.status_change.modified_at).eq(pm.collectionVariables.get('review_date'));")
    s('UUID reutilizado con otro comentario',method='POST',data=review|{'comment':'Otro comentario'},code=409)
    s('Consultar operación aceptada sin reenviar',f'company/applications/{own["3"]}/status/operations/{review["request_id"]}/',check="pm.expect(b.replayed).eq(true);pm.expect(b.event.to_status).eq('in_review');")
    s('Aviso real al destinatario candidato','dashboard/candidate/',actor='candidate',check=f"pm.expect(b.metrics.pending_notifications_count).eq({b['candidate_metrics']['pending_notifications_count']+1});pm.expect(b.notifications[0].event_kind).eq('application_status_changed');pm.expect(b.notifications[0].application_id).eq({own['3']});pm.expect(b.notifications[0].title).include('En revisión');pm.expect(b.notifications[0].created_at).not.eq(null);")
    s('Historial candidato refleja cambio','applications/?page_size=50',actor='candidate',check=f"const a=b.applications.find(a=>a.id==={own['3']});pm.expect(a.status).eq('in_review');pm.expect(a.status_change.comment).eq('Revisión empresarial real QA');pm.expect(a.created_at).eq(pm.collectionVariables.get('original_date'));")
    s('Versión obsoleta no sobrescribe',method='POST',data=state('accepted',0),code=409)
    s('Cambiar a Aceptada sin comentario',method='POST',data=accepted,check="pm.expect(b.application.status).eq('accepted');pm.expect(b.application.status_change.comment).eq('');pm.expect(b.application.status_change.version).eq(2);pm.expect(b.application.created_at).eq(pm.collectionVariables.get('original_date'));pm.expect(b.application.cv.sha256).eq(pm.collectionVariables.get('uploaded_hash'));")
    s('Repetir decisión no altera fecha ni avisos',method='POST',data=state('accepted',2),code=409)
    s('Decisión final no se reabre',method='POST',data=state('rejected',2),code=409)
    s('CV generado antes de transición',f'company/applications/{own["4"]}/status/',check="pm.collectionVariables.set('generated_hash',b.application.cv.sha256);pm.collectionVariables.set('generated_original_date',b.application.created_at);pm.expect(b.application.status_change.modified_at).eq(null);")
    s('Cambiar a Rechazada con comentario',f'company/applications/{own["4"]}/status/',method='POST',data=state('rejected',0,comment='Decisión empresarial QA'),check="pm.expect(b.application.status).eq('rejected');pm.expect(b.application.status_change.version).eq(1);pm.expect(b.application.status_change.comment).eq('Decisión empresarial QA');pm.expect(b.application.cv.sha256).eq(pm.collectionVariables.get('generated_hash'));pm.expect(b.application.created_at).eq(pm.collectionVariables.get('generated_original_date'));")
    s('Tres avisos sin duplicar alta HU018','dashboard/candidate/',actor='candidate',check=f"pm.expect(b.metrics.pending_notifications_count).eq({b['candidate_metrics']['pending_notifications_count']+3});pm.expect(b.notifications.filter(n=>n.event_kind==='application_status_changed').length).eq(3);")
    for actor,code in [('other_company',404),('candidate',403),('draft',403),(None,401)]:
        s('Permiso de cambio '+str(actor),method='POST',actor=actor,data=state('accepted',0),code=code)
    s('Identificador de otra empresa',f'company/applications/{b["foreign_application"]}/status/',method='POST',data=state('accepted',0),code=404)
    for changes in [{'expected_version':True},{'expected_version':'0'},{'target_status':'submitted'},{'comment':None},{'comment':33},{'comment':'x'*2001},{'request_id':'invalid'},{'candidate_id':b['candidate_id']}]:
        s('Parámetro de estado inválido '+next(iter(changes)),f'company/applications/{own["13"]}/status/',method='POST',data=state('in_review',0)|changes,code=400)
    s('Query no permitida',f'company/applications/{own["13"]}/status/?page=1',method='POST',data=state('in_review',0),code=400)
    s('Transición propia adicional con aviso',f'company/applications/{own["13"]}/status/',method='POST',data=state('in_review',0,comment='Lectura y aviso sin modificar CV'),check="pm.expect(b.application.status_change.version).eq(1);pm.expect(b.application.status).eq('in_review');")
    s('Modificar fuente generada','curriculum/generated/',actor='candidate',method='PATCH',data={'template':'minimalista'},check="pm.expect(b.curriculum.template).eq('minimalista');")
    for source in ['uploaded','generated']:
        s('Eliminar fuente '+source,'curriculum/'+source+'/',actor='candidate',method='DELETE',check='pm.expect(b).to.be.an("object");')
    for offer,source in [(3,'uploaded'),(4,'generated')]:
        s('Metadatos enviados intactos '+source,f'company/applications/{own[str(offer)]}/',check=f"pm.expect(b.application.cv.sha256).eq(pm.collectionVariables.get('{source}_hash'));")
        s('PDF enviado intacto '+source,f'company/applications/{own[str(offer)]}/cv/',pdf=True)
    s('Histórico sin fecha inventada','company/applications/1/',check="pm.expect(b.application.cv).eq(null);pm.expect(b.application.status_change.modified_at).eq(null);pm.expect(b.application.status_change.version).eq(0);")
    c=conv['3'];path=f'conversations/{c}/';pag=f'conversations/{conv["4"]}/messages/'
    m('Resumen inicial sin mensajes pendientes','messages/summary/',actor='candidate',check='pm.expect(b.unread_count).eq(0);')
    m('Lista empresarial autorizada',check=f"pm.expect(b.count).eq({b['company_conversations']});pm.expect(b.conversations.some(c=>c.id==={b['foreign_conversation']})).eq(false);")
    m('Conversación nueva por postulación real',method='POST',actor='candidate',data={'application_id':own['13']},code=201,check=f"pm.expect(b.created).eq(true);pm.expect(b.conversation.contact.id).eq({b['company_id']});pm.collectionVariables.set('new_conversation',b.conversation.id);")
    m('Crear de nuevo devuelve la conversación original',method='POST',actor='company',data={'application_id':own['13']},check="pm.expect(b.created).eq(false);pm.expect(b.conversation.id).eq(Number(pm.collectionVariables.get('new_conversation')));")
    m('Búsqueda autorizada y paginada','conversations/?q=Candidato&page_size=10',check='pm.expect(b.count).eq(13);pm.expect(b.conversations.length).eq(10);pm.collectionVariables.set("conversation_page1",JSON.stringify(b.conversations.map(c=>c.id)));')
    m('Página dos conserva búsqueda','conversations/?q=Candidato&page_size=10&page=2',check='pm.expect(b.conversations.length).eq(3);pm.expect(b.conversations.every(c=>!JSON.parse(pm.collectionVariables.get("conversation_page1")).includes(c.id))).eq(true);')
    m('Búsqueda vacía','conversations/?q=Inexistente',check='pm.expect(b.count).eq(0);')
    m('Contacto empresa y contexto correcto',path,actor='candidate',check=f"pm.expect(b.conversation.contact.id).eq({b['company_id']});pm.expect(b.conversation.application_id).eq({own['3']});pm.expect(b.conversation.offer.id).eq(3);")
    m('Conversación inicialmente vacía',path+'messages/',actor='candidate',check='pm.expect(b.count).eq(0);pm.expect(b.messages).deep.eq([]);')
    first={'text':'Hola candidato, conversación empresarial real QA','client_message_id':str(uuid.uuid4())}
    m('Empresa envía texto al candidato',path+'messages/',method='POST',data=first,code=201,check=f"pm.expect(b.created).eq(true);pm.expect(b.message.sender_id).eq({b['company_id']});pm.expect(b.message.recipient_id).eq({b['candidate_id']});pm.expect(b.message.created_at).not.eq(null);pm.expect(b.message.read_at).eq(null);pm.collectionVariables.set('message1',b.message.id);")
    m('Reintento mismo mensaje no duplica',path+'messages/',method='POST',data=first,check="pm.expect(b.created).eq(false);pm.expect(b.message.id).eq(Number(pm.collectionVariables.get('message1')));")
    m('UUID con texto diferente es conflicto',path+'messages/',method='POST',data=first|{'text':'Texto distinto'},code=409)
    m('Recibo propio por GET de operación',path+'messages/operations/'+first['client_message_id']+'/',check="pm.expect(b.message.id).eq(Number(pm.collectionVariables.get('message1')));")
    m('Candidato tiene un pendiente','messages/summary/',actor='candidate',check='pm.expect(b.unread_count).eq(1);')
    m('Consultar no marca lectura',path+'messages/',actor='candidate',check='pm.expect(b.messages.length).eq(1);pm.expect(b.messages[0].read_at).eq(null);')
    reply={'text':'Respuesta real del candidato QA','client_message_id':str(uuid.uuid4())}
    m('Candidato responde a la empresa',path+'messages/',actor='candidate',method='POST',data=reply,code=201,check=f"pm.expect(b.message.sender_id).eq({b['candidate_id']});pm.expect(b.message.recipient_id).eq({b['company_id']});pm.collectionVariables.set('message2',b.message.id);")
    m('Empresa tiene un pendiente','messages/summary/',check='pm.expect(b.unread_count).eq(1);')
    # Las sustituciones de IDs son solo variables QA de esta colección; nunca credenciales.
    def read_data(variable):return {'message_ids':['{{'+variable+'}}']}
    def read_item(name,actor,var,check=None,code=200):
        m(name,path+'read/',actor=actor,method='POST',data=read_data(var),check=check,code=code)
        raw=items[-1]['request']['body']['raw'];items[-1]['request']['body']['raw']=raw.replace('"{{'+var+'}}"','{{'+var+'}}')
    read_item('Confirmar solo el mensaje consultado','candidate','message1','pm.expect(b.marked_read).eq(1);pm.expect(b.unread_count).eq(0);')
    m('Fecha de lectura registrada',path+'messages/',actor='candidate',check="pm.collectionVariables.set('read_date',b.messages.find(m=>m.id===Number(pm.collectionVariables.get('message1'))).read_at);pm.expect(pm.collectionVariables.get('read_date')).not.eq(null);")
    later={'text':'Nuevo mensaje entre consulta y lectura QA','client_message_id':str(uuid.uuid4())}
    m('Nuevo mensaje durante lectura',path+'messages/',method='POST',data=later,code=201,check="pm.collectionVariables.set('message3',b.message.id);")
    read_item('Repetir lectura no consume el mensaje nuevo','candidate','message1','pm.expect(b.marked_read).eq(0);pm.expect(b.unread_count).eq(1);')
    m('Conservar pendiente nuevo y fecha anterior',path+'messages/',actor='candidate',check="pm.expect(b.messages.find(m=>m.id===Number(pm.collectionVariables.get('message1'))).read_at).eq(pm.collectionVariables.get('read_date'));pm.expect(b.messages.find(m=>m.id===Number(pm.collectionVariables.get('message3'))).read_at).eq(null);")
    read_item('Leer el nuevo recibido','candidate','message3','pm.expect(b.marked_read).eq(1);pm.expect(b.unread_count).eq(0);')
    read_item('Empresa lee la respuesta recibida','company','message2','pm.expect(b.marked_read).eq(1);pm.expect(b.unread_count).eq(0);')
    m('Mismo texto con clave nueva es legítimo',path+'messages/',method='POST',data=first|{'client_message_id':str(uuid.uuid4())},code=201,check='pm.expect(b.created).eq(true);')
    m('Ventana cronológica de mensajes previos',pag+'?page_size=10',actor='candidate',check='pm.expect(b.count).eq(23);pm.expect(b.messages.length).eq(10);pm.collectionVariables.set("message_anchor",b.through_id);pm.collectionVariables.set("messages_page1",JSON.stringify(b.messages.map(m=>m.id)));')
    m('Llegada nueva fuera de ventana',pag,method='POST',data={'text':'Nuevo fuera de ventana fija QA','client_message_id':str(uuid.uuid4())},code=201,check='pm.expect(b.created).eq(true);')
    m('Segunda ventana estable con ancla',pag+'?page_size=10&page=2&through_id={{message_anchor}}',actor='candidate',check='pm.expect(b.count).eq(23);pm.expect(b.messages.every(m=>!JSON.parse(pm.collectionVariables.get("messages_page1")).includes(m.id))).eq(true);')
    m('Actualizar incluye mensaje nuevo',pag+'?page_size=10',actor='candidate',check='pm.expect(b.count).eq(24);')
    for text in ['', '  \n ',None,33,'x'*4001]:m('Texto rechazado '+str(type(text).__name__),path+'messages/',method='POST',data={'text':text,'client_message_id':str(uuid.uuid4())},code=400)
    m('Límite de 4000 caracteres',path+'messages/',method='POST',data={'text':'L'*4000,'client_message_id':str(uuid.uuid4())},code=201,check='pm.expect(b.message.text.length).eq(4000);')
    for field in ['sender_id','recipient_id']:m('Identidad no inyectable '+field,path+'messages/',method='POST',data=first|{field:b['candidate_id']},code=400)
    for query in ['page_size=51','page=999','sender_id=1','page=1&page=1']:
        m('Parámetro de mensaje inválido '+query,path+'messages/?'+query,code=400)
    for query in ['q=QA&q=Otro','q='+'x'*101,'recipient_id=1']:
        m('Búsqueda inválida '+query[:30],'conversations/?'+query,code=400)
    read_item('No leer mensajes enviados por el mismo usuario','company','message1',code=404)
    foreign_path=f'conversations/{b["foreign_conversation"]}/'
    for actor in ['candidate','company']:
        m('Detalle ajeno '+actor,foreign_path,actor=actor,code=404)
        m('Mensajes ajenos '+actor,foreign_path+'messages/',actor=actor,code=404)
        m('Enviar en conversación ajena '+actor,foreign_path+'messages/',actor=actor,method='POST',data=first,code=404)
        m('Leer conversación ajena '+actor,foreign_path+'read/',actor=actor,method='POST',data={'message_ids':[]},code=404)
    m('Crear desde postulación ajena',actor='other',method='POST',data={'application_id':own['3']},code=404)
    m('Tercero no ve conversaciones',actor='other',check='pm.expect(b.count).eq(0);')
    m('Otra empresa solo ve su contexto',actor='other_company',check='pm.expect(b.count).eq(1);')
    for actor,code in [('draft',403),(None,401)]:
        m('Rol o sesión no autorizado '+str(actor),path+'messages/',actor=actor,code=code)
        m('Envío no autorizado '+str(actor),path+'messages/',actor=actor,method='POST',data=first,code=code)
    m('Consulta de oferta cerrada conserva contacto',path,actor='candidate',check=f"pm.expect(b.conversation.application_id).eq({own['3']});pm.expect(b.conversation.contact.role).eq('empresa');")
    m('Consulta de archivada conserva mensajes',f'conversations/{conv["4"]}/',check=f"pm.expect(b.conversation.application_id).eq({own['4']});")
    first_name=items[0]['name']
    guard=[f"if(pm.environment.get('base_url')!=='http://127.0.0.1:{port}/api'||pm.environment.get('qa_run_id')!=='{run.name}'||pm.environment.get('qa_confirmation')!=='SOLO_BASE_AISLADA'){{pm.execution.skipRequest();throw Error('Solo otra QA HU021/HU022');}}",
           'if(pm.info.iteration>0){pm.execution.skipRequest();throw Error("Solo una iteración de esta base");}',
           f"if(pm.info.requestName==={json.dumps(first_name,ensure_ascii=False)}){{if(pm.collectionVariables.get('qa_consumed')){{pm.execution.skipRequest();throw Error('Esta base ya fue consumida; prepara otra');}}pm.collectionVariables.set('qa_consumed','{run.name}');}}"]
    return {'info':{'_postman_id':str(uuid.uuid4()),'name':'HU021–HU022 · Estados y mensajes QA · '+run.name,'schema':'https://schema.getpostman.com/json/collection/v2.1.0/collection.json'},
            'event':[{'listen':'prerequest','script':{'type':'text/javascript','exec':guard}}],'item':items}


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('action',choices=['prepare','contrast']);parser.add_argument('--port',type=int,default=8100);parser.add_argument('--run');args=parser.parse_args()
    spec=importlib.util.spec_from_file_location('hu02122_prepare',HERE/'qa.py');qa=importlib.util.module_from_spec(spec);spec.loader.exec_module(qa)
    if args.action=='contrast':run,_=qa.load_run(args.run);print(json.dumps(contrast(run),ensure_ascii=True));return
    qa.prepare(args.port);run,_=qa.load_run();fixtures(run)
    from accounts.models import User
    from rest_framework.authtoken.models import Token
    env=json.loads((run/'local.postman_environment.json').read_text(encoding='utf-8'));values={v['key']:v for v in env['values']}
    for actor in ('candidate','other','company','other_company','draft'):
        user=User.objects.get(email=actor+'.postman@worknet.test');require(user.check_password(values['qa_password']['value']))
        key=actor+'_token'
        if key not in values:values[key]={'key':key,'type':'secret','enabled':True};env['values'].append(values[key])
        values[key]['value']=Token.objects.get_or_create(user=user)[0].key
    qa.write(run/'local.postman_environment.json',env)
    folder=run/'import-hu021-hu022';folder.mkdir();col=collection(run,args.port)
    qa.write(folder/'HU021-HU022.postman_collection.json',col)
    shutil.copy2(run/'local.postman_environment.json',folder/'HU021-HU022.private.postman_environment.json')
    print('HU021/HU022 preparada; '+str(len(col['item']))+' peticiones. Carpeta privada: '+str(folder))


if __name__=='__main__':main()
