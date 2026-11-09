"""HU024: estadísticas contrastadas por SQL, en otra QA con actores ficticios."""
import argparse
import importlib.util
import json
from pathlib import Path
import shutil
import sqlite3
import uuid
from datetime import datetime, timezone
from hu016_api import require
from hu018_api import HERE, configure, client
from hu01920_api import api_for, apply
from hu02122_api import call
from hu023_api import fixtures as previous_fixtures, seed as previous_seed, action as previous_action

STATES=('submitted','in_review','accepted','rejected','other')


def sql_statistics(run, *, initial=False):
    require((run/'.hu024-prepared').is_file())
    with sqlite3.connect(run/('initial.sqlite3' if initial else 'qa.sqlite3')) as db:
        db.row_factory=sqlite3.Row
        user=lambda name:db.execute('SELECT id FROM accounts_user WHERE email=?',(name+'.postman@worknet.test',)).fetchone()[0]
        def counts(where, key):
            rows=db.execute('SELECT a.status,COUNT(*) n FROM candidate_dashboard_application a JOIN candidate_dashboard_joboffer o ON o.id=a.offer_id WHERE '+where+' GROUP BY a.status',(key,)).fetchall()
            states={s:0 for s in STATES}
            for r in rows:states[r['status'] if r['status'] in STATES[:-1] else 'other']+=r['n']
            return {'applications_count':sum(states.values()),'states':states}
        def company(name):
            key=user(name);now=datetime.now(timezone.utc).replace(tzinfo=None).isoformat(' ')
            offers=[]
            for o in db.execute('SELECT id,title,status,expires_at FROM candidate_dashboard_joboffer WHERE company_id=? ORDER BY id DESC',(key,)):
                active=o['status']=='published' and (o['expires_at'] is None or o['expires_at']>now)
                offers.append({'id':o['id'],'title':o['title'],'status':o['status'],'is_active':active,**counts('o.id=?',o['id'])})
            return {**counts('o.company_id=?',key),'active_offers_count':sum(o['is_active'] for o in offers),'offers':offers,'offer_count':len(offers)}
        return {'candidate':counts('a.candidate_id=?',user('candidate')),'other':counts('a.candidate_id=?',user('other')),
                'company':company('company'),'stats_empty':company('stats_empty')}


def fixtures(run):
    previous_fixtures(run)
    with (run/'.hu024-prepared').open('x',encoding='utf-8') as f:f.write('HU024: base nueva, datos ficticios y correo a archivos.\n')
    from accounts.models import User,CompanyProfile
    from candidate_dashboard.models import JobOffer,active_offers
    from django.db import connection
    from rest_framework.authtoken.models import Token
    private=json.loads((run/'local.postman_environment.json').read_text(encoding='utf-8'))
    password=next(v['value'] for v in private['values'] if v['key']=='qa_password')
    empty=User.objects.create_user('stats_empty.postman@worknet.test',password,full_name='Empresa estadísticas vacías QA',role='empresa',email_verified=True)
    CompanyProfile.objects.create(company=empty,legal_name=empty.full_name,state='approved',tax_id='990024001')
    private['values'] += [{'key':'stats_empty_email','value':empty.email,'type':'secret','enabled':True},
                          {'key':'stats_empty_token','value':Token.objects.get_or_create(user=empty)[0].key,'type':'secret','enabled':True}]
    (run/'local.postman_environment.json').write_text(json.dumps(private,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    b=previous_seed(run);_,company=client('company')
    close=active_offers(JobOffer.objects.filter(company=company)).exclude(pk__in=[b['new_application_offer'],13]).order_by('pk').first().pk
    connection.close();shutil.copy2(run/'qa.sqlite3',run/'initial.sqlite3')
    expected=sql_statistics(run);require(expected['candidate']['applications_count']==13 and expected['other']['applications_count']==0)
    b={'offers':18,'applications':27,'messages':23,'notifications':63,'close_offer':close,'status_target':b['own_ids']['13'],
       'application_offer':b['new_application_offer'],'initial_statistics_sql':expected,
       'actor_qa':'Estados iniciales históricos son fixtures; altas/CV/mensajes previos por preparadores API. Los conteos esperados se calculan con SQL independiente del endpoint HU024.'}
    (run/'hu024-baseline.json').write_text(json.dumps(b,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    return b


def seed(run):
    require((run/'.hu024-prepared').is_file())
    return json.loads((run/'hu024-baseline.json').read_text(encoding='utf-8'))


def action(run,name):
    configure(run);b=seed(run)
    if name=='status':return previous_action(run,'status')
    if name=='close':
        actor,_=client('company');r=call(actor,'POST',f'company/offers/{b["close_offer"]}/transition/',{'action':'close','confirm':True})
        return {'actor_qa':'empresa_ficticia_API','method':'POST','path':f'/api/company/offers/{b["close_offer"]}/transition/','status':'closed'}
    if name=='application':
        actor,_=client('other');pk=apply(actor,b['application_offer'],'uploaded')
        return {'actor_qa':'otro_candidato_ficticio_API','method':'POST','path':f'/api/offers/{b["application_offer"]}/application/','application_id':pk}
    if name=='revoke_empty':
        from accounts.models import User
        r=call(api_for(User.objects.get(email='stats_empty.postman@worknet.test')),'POST','logout/',{})
        return {'actor_qa':'empresa_vacía_API','method':'POST','path':'/api/logout/','revoked':True}
    require(False)


def contrast(run):
    b=seed(run)
    with sqlite3.connect(run/'qa.sqlite3') as db,sqlite3.connect(run/'initial.sqlite3') as old:
        db.row_factory=old.row_factory=sqlite3.Row
        rows=lambda c,t:[dict(r) for r in c.execute('SELECT * FROM '+t+' ORDER BY id')]
        for table in ['accounts_user','accounts_companyprofile','candidate_dashboard_candidateprofile','curriculum_generatedcurriculum','curriculum_uploadedcurriculum','candidate_dashboard_savedoffer','candidate_dashboard_conversation','candidate_dashboard_message','candidate_dashboard_notificationpreference']:
            require(rows(db,table)==rows(old,table))
        changed=[]
        offers=rows(db,'candidate_dashboard_joboffer')
        for a,z in zip(rows(old,'candidate_dashboard_joboffer'),offers):
            if a!=z:
                require(a['id']==b['close_offer'] and z['status']=='closed')
                require({k:v for k,v in a.items() if k!='status'}=={k:v for k,v in z.items() if k!='status'})
                changed.append(a['id'])
        require(len(offers)==18)
        apps=rows(db,'candidate_dashboard_application');before=rows(old,'candidate_dashboard_application');initial_ids={x['id'] for x in before}
        mutable={'status','status_version','status_modified_at','status_comment'}
        for a in before:
            z=next(x for x in apps if x['id']==a['id'])
            if a!=z:
                require(a['id']==b['status_target'] and z['status']=='in_review' and z['status_version']==1)
                require({k:v for k,v in a.items() if k not in mutable}=={k:v for k,v in z.items() if k not in mutable})
        new=[x for x in apps if x['id'] not in initial_ids];require(len(new)<=1)
        other=db.execute("SELECT id FROM accounts_user WHERE email='other.postman@worknet.test'").fetchone()[0]
        require(all(a['candidate_id']==other and a['offer_id']==b['application_offer'] and a['status']=='submitted' for a in new))
        notices=rows(db,'candidate_dashboard_notification');old_notices=rows(old,'candidate_dashboard_notification');ids={n['id'] for n in old_notices}
        require([n for n in notices if n['id'] in ids]==old_notices)
        new_notices=[n for n in notices if n['id'] not in ids]
        for n in new_notices:
            app=next(a for a in apps if a['id']==n['application_id'])
            if n['event_kind']=='application_status_changed':require(n['recipient_id']==app['candidate_id'] and app['id']==b['status_target'])
            elif n['event_kind']=='application_created':
                company=db.execute('SELECT company_id FROM candidate_dashboard_joboffer WHERE id=?',(app['offer_id'],)).fetchone()[0]
                require(n['recipient_id']==company and app['id'] in {a['id'] for a in new})
            else:require(False)
        require(not db.execute('SELECT 1 FROM candidate_dashboard_application GROUP BY candidate_id,offer_id HAVING COUNT(*)>1').fetchall())
        return {'new_applications':len(new),'new_notices':len(new_notices),'new_status_events':db.execute('SELECT COUNT(*) FROM candidate_dashboard_applicationstatusevent').fetchone()[0],
                'closed_offer_ids':changed,'old_notices_and_reads_unchanged':True,'old_application_dates_relations_pdfs_unchanged':True,
                'profiles_accounts_cv_favorites_messages_preferences_unchanged':True,'duplicates':0,'statistics_sql':sql_statistics(run)}


def collection(run,port):
    b=seed(run);e=b['initial_statistics_sql'];items=[]
    def add(name,path,*,actor='candidate',method='GET',data=None,code=200,check=None):
        request={'method':method,'url':'{{base_url}}/'+path,'auth':{'type':'noauth'},'header':[]}
        if actor:request['header'].append({'key':'Authorization','value':'Token {{'+actor+'_token}}'})
        if data is not None:
            request['header'].append({'key':'Content-Type','value':'application/json'});request['body']={'mode':'raw','raw':json.dumps(data,ensure_ascii=False)}
        tests=[f"pm.test('HTTP {code}',()=>pm.response.to.have.status({code}));"]
        if check:tests+=['const b=pm.response.json();',"pm.test('Contrato HU024',()=>{"+check+"});"]
        items.append({'name':f'HU024-P{len(items)+1:02} · '+name,'request':request,'event':[{'listen':'test','script':{'type':'text/javascript','exec':tests}}]})
    def stats(name,actor='candidate',query='',check=''):
        role='candidate' if actor in ['candidate','other'] else 'company'
        add(name,f'statistics/{role}/'+query,actor=actor,check=check)
    stats('Candidato conteos completos',check=f"pm.expect(b.applications_count).eq(13);pm.expect(b.states).deep.eq({json.dumps(e['candidate']['states'])});pm.expect(pm.response.headers.get('Cache-Control')).include('no-store');")
    company=e['company'];total=company['applications_count'];active=company['active_offers_count']
    stats('Empresa totales y primera página',actor='company',check=f"pm.expect(b.applications_count).eq({total});pm.expect(b.states).deep.eq({json.dumps(company['states'])});pm.expect(b.active_offers_count).eq({active});pm.expect(b.offers.count).eq(17);pm.expect(b.offers.rows.length).eq(10);pm.collectionVariables.set('page1',JSON.stringify(b.offers.rows.map(o=>o.id)));")
    stats('Segunda página conserva totales e incluye cerradas',actor='company',query='?page=2&page_size=10',check=f"pm.expect(b.applications_count).eq({total});pm.expect(b.offers.rows.length).eq(7);pm.expect(b.offers.rows.every(o=>!JSON.parse(pm.collectionVariables.get('page1')).includes(o.id))).eq(true);pm.expect(b.offers.rows.find(o=>o.id===3).applications_count).eq(14);pm.expect(b.offers.rows.find(o=>o.id===4).status).eq('archived');")
    stats('Candidato vacío',actor='other',check='pm.expect(b.applications_count).eq(0);pm.expect(Object.values(b.states).reduce((a,x)=>a+x,0)).eq(0);')
    stats('Empresa sin ofertas ni postulaciones',actor='stats_empty',check='pm.expect(b.active_offers_count).eq(0);pm.expect(b.applications_count).eq(0);pm.expect(b.offers.rows).deep.eq([]);')
    add('Dashboard empresarial coincide','dashboard/company/',actor='company',check=f'pm.expect(b.metrics.applications).eq({total});pm.expect(b.metrics.active_offers).eq({active});')
    change={'target_status':'in_review','expected_version':0,'request_id':str(uuid.uuid4()),'confirm':True,'comment':'Cambio real para estadísticas HU024 QA'}
    add('Cambio real de estado',f'company/applications/{b["status_target"]}/status/',actor='company',method='POST',data=change,check="pm.expect(b.application.status).eq('in_review');")
    after={**e['candidate']['states']};after['submitted']-=1;after['in_review']+=1
    stats('Candidato refleja cambio persistido',check=f"pm.expect(b.applications_count).eq(13);pm.expect(b.states).deep.eq({json.dumps(after)});")
    cstates={**company['states']};cstates['submitted']-=1;cstates['in_review']+=1
    stats('Empresa refleja mismos estados',actor='company',check=f"pm.expect(b.applications_count).eq({total});pm.expect(b.states).deep.eq({json.dumps(cstates)});")
    actor,_=client('other');context=call(actor,'GET',f'offers/{b["application_offer"]}/application/');choice=next(x for x in context['cv_options'] if x['source']=='uploaded')
    add('Nueva postulación real de otro candidato',f'offers/{b["application_offer"]}/application/',actor='other',method='POST',code=201,data={'cv_source':'uploaded','cv_id':choice['id'],'cv_revision':choice['revision'],'confirm':True},check='pm.expect(b.created).eq(true);')
    stats('Otro candidato refleja su nueva postulación',actor='other',check='pm.expect(b.applications_count).eq(1);pm.expect(b.states.submitted).eq(1);')
    stats('Empresa incorpora la nueva postulación',actor='company',check=f'pm.expect(b.applications_count).eq({total+1});')
    add('Cierre real conserva postulaciones',f'company/offers/{b["close_offer"]}/transition/',actor='company',method='POST',data={'action':'close','confirm':True})
    stats('Activas disminuyen sin borrar historial',actor='company',check=f'pm.expect(b.active_offers_count).eq({active-1});pm.expect(b.applications_count).eq({total+1});')
    add('Dashboard actualizado coherente','dashboard/company/',actor='company',check=f'pm.expect(b.metrics.applications).eq({total+1});pm.expect(b.metrics.active_offers).eq({active-1});')
    add('Regresión aviso real al candidato','notifications/',check="pm.expect(b.notifications[0].event_kind).eq('application_status_changed');pm.expect(b.unread_count).eq(14);")
    add('Regresión aviso real empresarial','notifications/',actor='company',check="pm.expect(b.notifications[0].event_kind).eq('application_created');pm.expect(b.unread_count).eq(1);")
    for actor,role in [('candidate','company'),('company','candidate'),('reviewer','company'),('rejection','company')]:
        add('Rol o aprobación sin permiso',f'statistics/{role}/',actor=actor,code=403)
    add('Candidato no admite IDs inyectados','statistics/candidate/?candidate_id=1',code=400)
    for query in ['page=0','page_size=51','page=999','page=1&page=1','page=NaN','company_id=1','status=accepted']:
        add('Parámetro inválido '+query.split('=')[0],'statistics/company/?'+query,actor='company',code=400)
    for role in ['candidate','company']:add('Sesión ausente '+role,f'statistics/{role}/',actor=None,code=401)
    add('Estadísticas no permiten escritura','statistics/company/',actor='company',method='POST',data={},code=405)
    add('Revocar sesión vacía por API real','logout/',actor='stats_empty',method='POST',data={})
    add('Sesión revocada rechazada','statistics/company/',actor='stats_empty',code=401)
    first=items[0]['name']
    guard=[f"if(pm.environment.get('base_url')!=='http://127.0.0.1:{port}/api'||pm.environment.get('qa_run_id')!=='{run.name}'||pm.environment.get('qa_confirmation')!=='SOLO_BASE_AISLADA'){{pm.execution.skipRequest();throw Error('Solo otra QA HU024');}}",
           'if(pm.info.iteration>0){pm.execution.skipRequest();throw Error("Solo una iteración");}',
           f"if(pm.info.requestName==={json.dumps(first,ensure_ascii=False)}){{if(pm.collectionVariables.get('qa_consumed')){{pm.execution.skipRequest();throw Error('Base consumida');}}pm.collectionVariables.set('qa_consumed','{run.name}');}}"]
    return {'info':{'_postman_id':str(uuid.uuid4()),'name':'HU024 · Estadísticas QA · '+run.name,'schema':'https://schema.getpostman.com/json/collection/v2.1.0/collection.json'},'event':[{'listen':'prerequest','script':{'type':'text/javascript','exec':guard}}],'item':items}


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('action',choices=['prepare','contrast']);parser.add_argument('--port',type=int,default=8102);parser.add_argument('--run');args=parser.parse_args()
    spec=importlib.util.spec_from_file_location('hu024_prepare',HERE/'qa.py');qa=importlib.util.module_from_spec(spec);spec.loader.exec_module(qa)
    if args.action=='contrast':run,_=qa.load_run(args.run);print(json.dumps(contrast(run),ensure_ascii=True));return
    qa.prepare(args.port);run,_=qa.load_run();configure(run);fixtures(run)
    folder=run/'import-hu024';folder.mkdir();col=collection(run,args.port)
    qa.write(folder/'HU024.postman_collection.json',col);shutil.copy2(run/'local.postman_environment.json',folder/'HU024.private.postman_environment.json')
    print('HU024 preparada; '+str(len(col['item']))+' peticiones. Carpeta privada: '+str(folder))
if __name__=='__main__':main()
