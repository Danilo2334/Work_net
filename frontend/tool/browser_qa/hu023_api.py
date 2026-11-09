"""HU023: actores ficticios, avisos reales y contraste; solo otra base QA."""
import argparse
import importlib.util
import json
from pathlib import Path
import shutil
import sqlite3
import uuid
from hu016_api import connect, require
from hu018_api import HERE, configure, client
from hu01920_api import api_for, apply
from hu02122_api import fixtures as previous_fixtures, seed as previous_seed, call


def fixtures(run):
    previous_fixtures(run)
    with (run/'.hu023-prepared').open('x',encoding='utf-8') as f:f.write('HU023: nueva QA, sin datos personales reales.\n')
    from accounts.models import User, CompanyProfile
    from candidate_dashboard.models import Notification, JobOffer, visible_offers
    from django.core.files.uploadedfile import SimpleUploadedFile
    from django.db import connection
    from django.utils import timezone
    b=previous_seed(run)
    env=json.loads((run/'local.postman_environment.json').read_text(encoding='utf-8'))
    values={v['key']:v for v in env['values']};password=values['qa_password']['value']
    candidate,user=client('candidate');company,employer=client('company')
    # La lectura preparatoria es API real y precede a la instantánea inicial.
    for actor in [candidate,company]:
        while True:
            rows=call(actor,'GET','notifications/?status=unread&page_size=50')['notifications']
            if not rows:break
            call(actor,'POST','notifications/read/',{'notification_ids':[n['id'] for n in rows]})
    historical=[]
    for i in range(13):
        historical.append(Notification.objects.create(recipient=user,title=f'Aviso histórico de preparación QA {i+1:02}').pk)
    roles={}
    for role in ['approval','rejection','notice_applicant','reviewer']:
        is_company=role in ['approval','rejection']
        actor=User.objects.create_user(role+'.postman@worknet.test',password,
            full_name={'approval':'Empresa aprobación QA','rejection':'Empresa rechazo QA','notice_applicant':'Nueva candidatura de aviso QA','reviewer':'Revisor administrativo QA'}[role],
            role='empresa' if is_company else ('candidato' if role=='notice_applicant' else ''),
            email_verified=True,is_staff=role=='reviewer')
        roles[role]=actor
        if is_company:
            CompanyProfile.objects.create(company=actor,legal_name=actor.full_name,tax_id='990023001' if role=='approval' else '990023002',
                sector='Tecnología',location='Pasto QA',contact_email=actor.email,description='Empresa ficticia para aceptación HU023.',
                submitted_at=timezone.now(),state='pending')
    uploaded=api_for(roles['notice_applicant']).put('/api/curriculum/uploaded/',{
        'file':SimpleUploadedFile('cv-aviso-qa.pdf',(HERE/'fixtures/curriculum-valido.pdf').read_bytes(),content_type='application/pdf')},format='multipart')
    require(uploaded.status_code in [200,201])
    from rest_framework.authtoken.models import Token
    for role in ['candidate','company','other','other_company','draft',*roles]:
        actor=roles.get(role) or User.objects.get(email=role+'.postman@worknet.test')
        for key,value in [(role+'_email',actor.email),(role+'_token',Token.objects.get_or_create(user=actor)[0].key)]:
            if key not in values:
                values[key]={'key':key,'enabled':True,'type':'secret'};env['values'].append(values[key])
            values[key]['value']=value
    (run/'local.postman_environment.json').write_text(json.dumps(env,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    baseline=b|{'notification_preparation':'Avisos previos generados por API de preparación, leídos por API antes de esta instantánea;13 avisos legados ficticios preparados por ORM. No son acciones de una pantalla.',
        'historical_notice_ids':historical,'new_application_offer':visible_offers(JobOffer.objects.filter(company=employer)).order_by('pk').first().pk,
        'approval_profile':CompanyProfile.objects.get(company=roles['approval']).pk,'rejection_profile':CompanyProfile.objects.get(company=roles['rejection']).pk,
        'candidate_notices':call(candidate,'GET','notifications/')['count'],'candidate_unread':call(candidate,'GET','notifications/summary/')['unread_count'],
        'company_unread':call(company,'GET','notifications/summary/')['unread_count'],
        'notice_count':Notification.objects.count()}
    (run/'hu023-baseline.json').write_text(json.dumps(baseline,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    connection.close();shutil.copy2(run/'qa.sqlite3',run/'initial.sqlite3')
    return baseline


def seed(run):
    require((run/'.hu023-prepared').is_file())
    return json.loads((run/'hu023-baseline.json').read_text(encoding='utf-8'))


def action(run,name):
    configure(run);b=seed(run)
    from accounts.models import User
    from candidate_dashboard.models import Notification
    company,_=client('company')
    intent_file=run/'hu023-intents.private.json'
    intentions=json.loads(intent_file.read_text(encoding='utf-8')) if intent_file.exists() else {}
    def key(label):
        intentions.setdefault(label,str(uuid.uuid4()));intent_file.write_text(json.dumps(intentions),encoding='utf-8');return intentions[label]
    if name=='application':
        applicant=api_for(User.objects.get(email='notice_applicant.postman@worknet.test'))
        pk=apply(applicant,b['new_application_offer'],'uploaded')
        return {'actor_qa':'candidatura_ficticia_API','method':'POST','path':f'/api/offers/{b["new_application_offer"]}/application/','application_id':pk}
    if name=='status':
        pk=b['own_ids']['13'];r=call(company,'POST',f'company/applications/{pk}/status/',{
            'target_status':'in_review','expected_version':0,'request_id':key('status'),'confirm':True,'comment':'Revisión para aviso real HU023 QA'})
        return {'actor_qa':'empresa_ficticia_API','method':'POST','path':f'/api/company/applications/{pk}/status/','event':r['event'],'replayed':r['replayed']}
    if name in ['message','message_repeat','message_later','message_suppressed','message_suppressed_repeat','message_after_enable']:
        conv=b['conversation_ids']['3'];label='message' if name=='message_repeat' else 'message_suppressed' if name=='message_suppressed_repeat' else name
        r=call(company,'POST',f'conversations/{conv}/messages/',{
            'text':f'Mensaje empresarial real HU023 QA {label}','client_message_id':key(label)},200 if name.endswith('_repeat') else 201)
        return {'actor_qa':'empresa_ficticia_API','method':'POST','path':f'/api/conversations/{conv}/messages/','message_id':r['message']['id'],'created':r['created'],
                'notification_id':Notification.objects.filter(message_id=r['message']['id']).values_list('pk',flat=True).first()}
    if name in ['approve','reject']:
        actor=api_for(User.objects.get(email='reviewer.postman@worknet.test'))
        pk=b['approval_profile' if name=='approve' else 'rejection_profile']
        result=call(actor,'POST',f'admin/companies/{pk}/review/',{'decision':'approved' if name=='approve' else 'rejected','version':0,'reason':'' if name=='approve' else 'Documento ficticio incompleto QA'})
        return {'actor_qa':'administrador_ficticio_API','method':'POST','path':f'/api/admin/companies/{pk}/review/','state':result['company']['state']}
    if name=='revoke_other':
        actor,_=client('other');call(actor,'POST','logout/',{})
        return {'actor_qa':'titular_ficticio_API','method':'POST','path':'/api/logout/','revoked':True}
    require(False)


def contrast(run):
    baseline=seed(run)
    with connect(run) as db,sqlite3.connect(run/'initial.sqlite3') as initial:
        initial.row_factory=sqlite3.Row
        def rows(c,t):return [dict(r) for r in c.execute('SELECT * FROM '+t+' ORDER BY id')]
        for table in ['candidate_dashboard_candidateprofile','candidate_dashboard_joboffer','candidate_dashboard_savedoffer','curriculum_uploadedcurriculum','curriculum_generatedcurriculum']:
            require(rows(db,table)==rows(initial,table))
        before_apps=rows(initial,'candidate_dashboard_application');after_apps=rows(db,'candidate_dashboard_application')
        mutable={'status','status_version','status_modified_at','status_comment'}
        for old in before_apps:
            now=next(x for x in after_apps if x['id']==old['id'])
            if old['id']!=baseline['own_ids']['13']:require(now==old)
            else:require({k:v for k,v in now.items() if k not in mutable}=={k:v for k,v in old.items() if k not in mutable})
        before=rows(initial,'candidate_dashboard_notification');after=rows(db,'candidate_dashboard_notification');ids={r['id'] for r in before}
        newly_read=[]
        for old in before:
            now=next(r for r in after if r['id']==old['id'])
            require({k:v for k,v in old.items() if k!='read_at'}=={k:v for k,v in now.items() if k!='read_at'})
            if old['read_at'] is not None:require(now['read_at']==old['read_at'])
            elif now['read_at'] is not None:newly_read.append(old['id'])
        original_messages=rows(initial,'candidate_dashboard_message');messages=rows(db,'candidate_dashboard_message')
        require([m for m in messages if m['id'] in {x['id'] for x in original_messages}]==original_messages)
        new=[n for n in after if n['id'] not in ids]
        for n in new:
            if n['event_kind']=='message_received':
                message=next(m for m in messages if m['id']==n['message_id']);require(n['recipient_id']==message['recipient_id'])
            elif n['event_kind']=='application_status_changed':
                app=next(a for a in after_apps if a['id']==n['application_id']);require(n['recipient_id']==app['candidate_id'])
                event=db.execute('SELECT * FROM candidate_dashboard_applicationstatusevent WHERE id=?',(n['status_event_id'],)).fetchone()
                require(event['application_id']==app['id'] and event['version']==app['status_version'] and event['changed_at']==app['status_modified_at'])
                require(event['to_status']==app['status'] and event['comment']==app['status_comment'])
            elif n['event_kind']=='application_created':
                company=db.execute('SELECT o.company_id FROM candidate_dashboard_application a JOIN candidate_dashboard_joboffer o ON o.id=a.offer_id WHERE a.id=?',(n['application_id'],)).fetchone()[0];require(n['recipient_id']==company)
            elif n['event_kind']=='company_reviewed':
                company=db.execute('SELECT p.company_id FROM accounts_companyreview r JOIN accounts_companyprofile p ON p.id=r.profile_id WHERE r.id=?',(n['company_review_id'],)).fetchone()[0];require(n['recipient_id']==company)
            else:require(False)
        for field in ['message_id','status_event_id','company_review_id']:
            require(not db.execute('SELECT 1 FROM candidate_dashboard_notification WHERE '+field+' IS NOT NULL GROUP BY '+field+' HAVING COUNT(*)>1').fetchall())
        require(not db.execute('SELECT 1 FROM candidate_dashboard_message GROUP BY conversation_id,sender_id,client_message_id HAVING COUNT(*)>1').fetchall())
        return {'old_notice_content_dates_recipients_preserved':True,'old_read_timestamps_preserved':True,
            'new_messages_read':sum(m['read_at'] is not None for m in messages if m['id'] not in {x['id'] for x in original_messages}),
            'old_notice_ids_marked_read':newly_read,'new_notices':len(new),'new_notice_kinds':{k:sum(n['event_kind']==k for n in new) for k in ['application_created','application_status_changed','message_received','company_reviewed']},
            'old_messages_and_reads_unchanged':True,'new_messages':len(messages)-len(original_messages),
            'new_applications':len(after_apps)-len(before_apps),'original_application_dates_relations_pdfs_preserved':True,
            'profiles_offers_favorites_curricula_preserved':True,'duplicate_notices':0,'message_intent_duplicates':0,'recipients_verified':True}


def collection(run,port):
    b=seed(run);items=[]
    def add(name,path='notifications/',*,actor='candidate',method='GET',data=None,code=200,check=None):
        request={'method':method,'url':'{{base_url}}/'+path,'auth':{'type':'noauth'},'header':[]}
        if actor:request['header'].append({'key':'Authorization','value':'Token {{'+actor+'_token}}'})
        if data is not None:
            request['header'].append({'key':'Content-Type','value':'application/json'})
            request['body']={'mode':'raw','raw':json.dumps(data,ensure_ascii=False)}
        tests=[f"pm.test('HTTP {code}',()=>pm.response.to.have.status({code}));"]
        if check:tests+=['const b=pm.response.json();',"pm.test('Contrato HU023',()=>{"+check+"});"]
        items.append({'name':f'HU023-P{len(items)+1:02} · '+name,'request':request,'event':[{'listen':'test','script':{'type':'text/javascript','exec':tests}}]})
    def ack(name,ids,**kw):add(name,'notifications/read/',method='POST',data={'notification_ids':ids},**kw)
    add('Contador inicial propio','notifications/summary/',check="pm.expect(b.unread_count).eq(13);")
    add('Historial privado primera página',check=f"pm.expect(b.count).eq({b['candidate_notices']});pm.expect(b.notifications.length).eq(10);pm.expect(b.unread_count).eq(13);pm.collectionVariables.set('anchor',b.through_id);pm.collectionVariables.set('page1',JSON.stringify(b.notifications.map(n=>n.id)));pm.expect(pm.response.headers.get('Cache-Control')).include('no-store');")
    add('Segunda página estable','notifications/?page=2&through_id={{anchor}}',check="pm.expect(b.page).eq(2);pm.expect(b.notifications.every(n=>!JSON.parse(pm.collectionVariables.get('page1')).includes(n.id))).eq(true);")
    add('Historial vacío de otro titular',actor='other',check='pm.expect(b.count).eq(0);pm.expect(b.unread_count).eq(0);')
    legacy=b['historical_notice_ids'][-1]
    ack('Lectura explícita propia',[legacy],check='pm.expect(b.marked_read).eq(1);pm.expect(b.unread_count).eq(12);')
    add('Fecha de lectura conservada','notifications/?status=read',check=f"const n=b.notifications.find(n=>n.id==={legacy});pm.expect(n.read_at).not.eq(null);pm.collectionVariables.set('read_date',n.read_at);")
    ack('Repetir lectura no modifica fecha',[legacy],check='pm.expect(b.marked_read).eq(0);pm.expect(b.unread_count).eq(12);')
    add('Lectura previa conserva instante','notifications/?status=read',check=f"pm.expect(b.notifications.find(n=>n.id==={legacy}).read_at).eq(pm.collectionVariables.get('read_date'));")
    from accounts.models import User
    from candidate_dashboard.models import Notification
    foreign=Notification.objects.filter(recipient__email='company.postman@worknet.test').order_by('pk').first().pk
    ack('Lote mixto ajeno rechazado atómicamente',[b['historical_notice_ids'][0],foreign],code=404)
    ack('Tercero no marca aviso privado',[legacy],actor='other',code=404)
    for name,ids in [('Vacío',[]),('Duplicado',[legacy,legacy]),('Cadena',[str(legacy)]),('Booleano',[True]),('Máximo50',list(range(1,52)))]:ack('Validación lectura '+name,ids,code=400)
    for query in ['page=0','page_size=51','page=999','status=otro','recipient_id=1','page=1&page=1','through_id=99999999999999999999999999999']:
        add('Parámetro inválido '+query.split('=')[0],'notifications/?'+query,code=400)
    from hu01920_api import api_for
    applicant=api_for(User.objects.get(email='notice_applicant.postman@worknet.test'))
    context=call(applicant,'GET',f'offers/{b["new_application_offer"]}/application/')
    choice=next(x for x in context['cv_options'] if x['source']=='uploaded')
    add('Nueva postulación genera aviso empresarial',f'offers/{b["new_application_offer"]}/application/',actor='notice_applicant',method='POST',code=201,data={
        'cv_source':'uploaded','cv_id':choice['id'],'cv_revision':choice['revision'],'confirm':True},check="pm.expect(b.created).eq(true);pm.collectionVariables.set('new_application',b.application.id);")
    add('Empresa recibe su aviso real',actor='company',check="pm.expect(b.unread_count).eq(1);pm.expect(b.notifications[0].event_kind).eq('application_created');pm.expect(b.notifications[0].application_id).eq(Number(pm.collectionVariables.get('new_application')));")
    status={'target_status':'in_review','expected_version':0,'request_id':str(uuid.uuid4()),'confirm':True,'comment':'Revisión empresarial para aviso HU023 QA'}
    status_path=f'company/applications/{b["own_ids"]["13"]}/status/'
    add('Cambio confirmado genera aviso candidato',status_path,actor='company',method='POST',data=status,check="pm.expect(b.application.status).eq('in_review');pm.expect(b.replayed).eq(false);")
    add('Repetición no duplica cambio ni aviso',status_path,actor='company',method='POST',data=status,check='pm.expect(b.replayed).eq(true);')
    add('Aviso real de cambio recibido',check="pm.expect(b.notifications[0].event_kind).eq('application_status_changed');pm.expect(b.unread_count).eq(13);")
    conversation=b['conversation_ids']['3'];msgpath=f'conversations/{conversation}/messages/'
    def message(label):return {'text':'Mensaje empresarial HU023 QA '+label,'client_message_id':str(uuid.uuid4())}
    first=message('primero');later=message('posterior');suppressed=message('suprimido');enabled=message('habilitado')
    add('Empresa envía primer mensaje real',msgpath,actor='company',method='POST',code=201,data=first,check="pm.expect(b.created).eq(true);pm.expect(b.message.read_at).eq(null);")
    add('Repetición de mensaje conserva una intención',msgpath,actor='company',method='POST',data=first,check='pm.expect(b.created).eq(false);')
    add('Destinatario recibe aviso de mensaje',check="pm.expect(b.notifications[0].event_kind).eq('message_received');pm.expect(b.unread_count).eq(14);pm.collectionVariables.set('message_notice',b.notifications[0].id);")
    # El cuerpo usa una variable numérica sin comillas para mantener IDs enteros.
    ack('Marcar aviso de mensaje recibido',['PLACEHOLDER'],check='pm.expect(b.marked_read).eq(1);pm.expect(b.unread_count).eq(13);')
    items[-1]['request']['body']['raw']='{"notification_ids":[{{message_notice}}]}'
    add('Leer aviso no marca el mensaje','messages/summary/',check='pm.expect(b.unread_count).eq(1);')
    add('Otro mensaje llega después de consultar',msgpath,actor='company',method='POST',code=201,data=later,check='pm.expect(b.created).eq(true);')
    ack('Repetir lectura no consume aviso nuevo',['PLACEHOLDER'],check='pm.expect(b.marked_read).eq(0);pm.expect(b.unread_count).eq(14);')
    items[-1]['request']['body']['raw']='{"notification_ids":[{{message_notice}}]}'
    add('Preferencias aplicables a eventos futuros','notifications/preferences/',check="pm.expect(b.scope).eq('future_events_only');pm.expect(b.preferences.message_received).eq(true);")
    add('Deshabilitar avisos de mensajes futuros','notifications/preferences/',method='PATCH',data={'message_received':False},check='pm.expect(b.preferences.message_received).eq(false);')
    add('Mensaje persiste con aviso deshabilitado',msgpath,actor='company',method='POST',code=201,data=suppressed,check='pm.expect(b.created).eq(true);')
    add('Historial previo no se borra ni se amplía',check=f"pm.expect(b.count).eq({b['candidate_notices']+3});pm.expect(b.unread_count).eq(14);")
    add('Habilitar avisos futuros','notifications/preferences/',method='PATCH',data={'message_received':True},check='pm.expect(b.preferences.message_received).eq(true);')
    add('Reintento no crea retroactivamente un aviso',msgpath,actor='company',method='POST',data=suppressed,check='pm.expect(b.created).eq(false);')
    add('Historial no reconstruye aviso suprimido',check=f"pm.expect(b.count).eq({b['candidate_notices']+3});")
    add('Nuevo mensaje posterior vuelve a avisar',msgpath,actor='company',method='POST',code=201,data=enabled,check='pm.expect(b.created).eq(true);')
    add('Aviso posterior permitido y contador',check=f"pm.expect(b.count).eq({b['candidate_notices']+4});pm.expect(b.unread_count).eq(15);pm.expect(b.notifications[0].event_kind).eq('message_received');")
    for role,action in [('approval','approved'),('rejection','rejected')]:
        profile=b[role+'_profile']
        data={'decision':action,'version':0,'reason':'' if action=='approved' else 'Documento ficticio incompleto QA'}
        add('Decisión administrativa '+action,f'admin/companies/{profile}/review/',actor='reviewer',method='POST',data=data,check=f"pm.expect(b.company.state).eq('{action}');")
        add('Repetir decisión no duplica aviso '+action,f'admin/companies/{profile}/review/',actor='reviewer',method='POST',data=data,code=409)
        add('Empresa consulta su decisión '+action,actor=role,check="pm.expect(b.count).eq(1);pm.expect(b.unread_count).eq(1);pm.expect(b.notifications[0].event_kind).eq('company_reviewed');")
    add('Cuenta rechazada conserva restricción dashboard','dashboard/company/',actor='rejection',code=403)
    for data in [{'message_received':'false'},{'company_reviewed':1},{'recipient_id':b['company_id']},{}]:
        add('Preferencia inválida o ajena','notifications/preferences/',method='PATCH',data=data,code=400)
    for path,method,data in [('notifications/','GET',None),('notifications/read/','POST',{'notification_ids':[legacy]}),('notifications/preferences/','GET',None)]:
        add('Sesión ausente '+path,path,actor=None,method=method,data=data,code=401)
    add('Centro no permite crear avisos arbitrarios',method='POST',data={'title':'No permitido'},code=405)
    first_name=items[0]['name']
    guard=[f"if(pm.environment.get('base_url')!=='http://127.0.0.1:{port}/api'||pm.environment.get('qa_run_id')!=='{run.name}'||pm.environment.get('qa_confirmation')!=='SOLO_BASE_AISLADA'){{pm.execution.skipRequest();throw Error('Solo otra QA HU023');}}",
        'if(pm.info.iteration>0){pm.execution.skipRequest();throw Error("Solo una iteración");}',
        f"if(pm.info.requestName==={json.dumps(first_name,ensure_ascii=False)}){{if(pm.collectionVariables.get('qa_consumed')){{pm.execution.skipRequest();throw Error('Base ya consumida');}}pm.collectionVariables.set('qa_consumed','{run.name}');}}"]
    return {'info':{'_postman_id':str(uuid.uuid4()),'name':'HU023 · Notificaciones QA · '+run.name,'schema':'https://schema.getpostman.com/json/collection/v2.1.0/collection.json'},
        'event':[{'listen':'prerequest','script':{'type':'text/javascript','exec':guard}}],'item':items}


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('action',choices=['prepare','contrast']);parser.add_argument('--port',type=int,default=8101);parser.add_argument('--run');args=parser.parse_args()
    spec=importlib.util.spec_from_file_location('hu023_prepare',HERE/'qa.py');qa=importlib.util.module_from_spec(spec);spec.loader.exec_module(qa)
    if args.action=='contrast':run,_=qa.load_run(args.run);print(json.dumps(contrast(run),ensure_ascii=True));return
    qa.prepare(args.port);run,_=qa.load_run();configure(run);fixtures(run)
    folder=run/'import-hu023';folder.mkdir();col=collection(run,args.port)
    qa.write(folder/'HU023.postman_collection.json',col)
    shutil.copy2(run/'local.postman_environment.json',folder/'HU023.private.postman_environment.json')
    print('HU023 preparada; '+str(len(col['item']))+' peticiones. Carpeta privada: '+str(folder))


if __name__=='__main__':main()
