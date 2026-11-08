"""HU019/HU020: QA exclusiva, estados preparados por actor QA y API Desktop."""
import argparse
from hashlib import sha256
import importlib.util
from io import BytesIO
import json
from pathlib import Path
import shutil
import sqlite3
import uuid

from hu016_api import connect, require
from hu018_api import HERE, configure, fixtures as previous_fixtures, client, put_sources


def api_for(user):
    from rest_framework.authtoken.models import Token
    from rest_framework.test import APIClient
    api = APIClient(HTTP_HOST='127.0.0.1')
    api.credentials(HTTP_AUTHORIZATION='Token ' + Token.objects.get_or_create(user=user)[0].key)
    return api


def apply(api, offer, source):
    context = api.get(f'/api/offers/{offer}/application/'); require(context.status_code == 200)
    choice = next(c for c in context.data['cv_options'] if c['source'] == source)
    r = api.post(f'/api/offers/{offer}/application/', {'cv_source': source, 'cv_id': choice['id'],
                 'cv_revision': str(choice['revision']), 'confirm': True}, format='json')
    require(r.status_code == 201)
    return r.data['application']['id']


def fixtures(run):
    previous_fixtures(run)
    (run/'.hu01920-prepared').write_text('HU019/HU020: estados de fixture por actor QA, sin flujo HU021.\n', encoding='utf-8')
    from django.core.files.uploadedfile import SimpleUploadedFile
    from django.db import connection
    from django.utils import timezone
    from accounts.models import User
    from candidate_dashboard.models import Application, CandidateProfile, JobOffer
    from curriculum.views import initial_data
    api, own = client('candidate')
    # Perfil actual conocido; no procede del PDF congelado.
    profile = CandidateProfile.objects.get(candidate=own)
    profile.experience = [{'position':'Ingeniera Backend','company':'Equipo ficticio QA','description':'APIs Django'}]
    profile.education = [{'qualification':'Ingeniería de Sistemas','institution':'Instituto QA'}]
    profile.skills = [{'name':'Python','level':'avanzado'},{'name':'Django'}]
    profile.save(update_fields=['experience','education','skills'])
    states = ['submitted','in_review','accepted','rejected']
    own_ids = {}
    for offer in range(3,14):
        pk = apply(api, offer, 'generated' if offer == 4 else 'uploaded')
        state = 'submitted' if offer == 13 else states[(offer-3)%4]
        Application.objects.filter(pk=pk).update(status=state)
        own_ids[str(offer)] = pk
    private = json.loads((run/'local.postman_environment.json').read_text(encoding='utf-8'))
    password = next(v['value'] for v in private['values'] if v['key']=='qa_password')
    raw = (HERE/'fixtures/curriculum-valido.pdf').read_bytes()
    extra = []
    for i in range(1,14):
        user = User.objects.create_user(f'postulante.{i:02}@hu020.invalid', password,
                    full_name=f'Postulante QA {i:02}',role='candidato',email_verified=True)
        if i != 13:
            CandidateProfile.objects.create(candidate=user,
                experience=[{'position':'Backend QA' if i<=8 else 'Ventas QA','company':'Empresa de práctica QA'}],
                education=[] if i==12 else [{'qualification':'Ingeniería' if i<=5 else 'Bachillerato','institution':'Instituto QA'}],
                skills=[] if i==11 else [{'name':'Python' if i%2 and i<=9 else 'Excel'}])
        actor = api_for(user)
        source = 'uploaded' if i%2 else 'generated'
        if source=='uploaded':
            r=actor.put('/api/curriculum/uploaded/',{'file':SimpleUploadedFile(f'cv-qa-{i:02}.pdf',raw,content_type='application/pdf')},format='multipart')
        else:
            r=actor.put('/api/curriculum/generated/',{'template':'moderna','data':initial_data(user)},format='json')
        require(r.status_code in (200,201))
        extra.append((user,apply(actor,3,source)))
    _, foreign_company = client('other_company')
    foreign_offer = JobOffer.objects.create(company=foreign_company,title='Oferta de otra empresa QA',
         company_name='Otra empresa QA',status='published',published_at=timezone.now(),location='Pasto',contract_type='Fijo')
    foreign_app = apply(api_for(extra[0][0]),foreign_offer.pk,'uploaded')
    company_api,_ = client('company')
    for offer,action in ((3,'close'),(4,'archive')):
        r=company_api.post(f'/api/company/offers/{offer}/transition/',{'action':action,'confirm':True},format='json')
        require(r.status_code==200)
    baseline={'offers':18,'own_offers':17,'own_applications':13,'applications':27,'selected_applicants':14,
              'own_ids':own_ids,'foreign_offer':foreign_offer.pk,'foreign_application':foreign_app,
              'filters':{'experience_Backend':9,'education_Ingenieria':6,'skill_Python':6,'combined':4,'experience_QA':13},
              'controlled_state_target':own_ids['13'],
              'actor_qa':'Preparador de fixtures: altas por APIClient existente y catálogo persistido por ORM, no flujo empresarial HU021.'}
    (run/'hu01920-baseline.json').write_text(json.dumps(baseline,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    connection.close();shutil.copy2(run/'qa.sqlite3',run/'initial.sqlite3')
    return baseline


def seed(run):
    require((run/'.hu01920-prepared').is_file())
    return json.loads((run/'hu01920-baseline.json').read_text(encoding='utf-8'))


def action(run,name):
    baseline=seed(run);configure(run)
    if name in ('review','accept','reject'):
        from candidate_dashboard.models import Application
        item=Application.objects.get(pk=baseline['controlled_state_target'])
        before=item.status;item.status={'review':'in_review','accept':'accepted','reject':'rejected'}[name]
        item.save(update_fields=['status'])
        return {'actor_qa':'estado_controlado_HU019','operacion':'ORM.save(update_fields=[status])',
                'application_id':item.pk,'antes':before,'despues':item.status,
                'procedencia':'Actor QA identificado; no operación de pantalla/API empresarial HU021, sin comentario ni notificación de cambio.'}
    require(name=='replace_delete_sources')
    api,_=client('candidate');put_sources(api,replaced=True)
    for source in ('uploaded','generated'):
        r=api.delete('/api/curriculum/'+source+'/');require(r.status_code==200)
    return {'actor_qa':'candidate_ficticio','operacion':'APIClient PUT de reemplazo y DELETE de ambas fuentes CV',
            'procedencia':'APIs reales de documentos existentes para verificar las copias enviadas, no acciones realizadas desde esta pantalla.'}


def contrast(run):
    baseline=seed(run)
    from pypdf import PdfReader
    with connect(run) as db,sqlite3.connect(run/'initial.sqlite3') as initial:
        initial.row_factory=sqlite3.Row
        def rows(c,table):return [dict(r) for r in c.execute('SELECT * FROM '+table+' ORDER BY id')]
        apps=rows(db,'candidate_dashboard_application');old=rows(initial,'candidate_dashboard_application')
        old_ids={r['id'] for r in old};new=[r for r in apps if r['id'] not in old_ids]
        stripped=lambda seq:[{k:v for k,v in r.items() if k!='status'} for r in seq]
        require(stripped([r for r in apps if r['id'] in old_ids])==stripped(old))
        original_statuses={r['id']:r['status'] for r in old}
        require(all(r['status']==original_statuses[r['id']] for r in apps if r['id'] in old_ids and r['id']!=baseline['controlled_state_target']))
        for row in apps:
            require(row['status'] in ('submitted','in_review','accepted','rejected'))
            if row['cv_source']:
                raw=bytes(row['cv_document']);require(sha256(raw).hexdigest()==row['cv_sha256'] and len(raw)==row['cv_size_bytes'])
                require(len(PdfReader(BytesIO(raw)).pages)>0)
        notices=rows(db,'candidate_dashboard_notification');old_notices=rows(initial,'candidate_dashboard_notification')
        require([r for r in notices if r['id'] in {x['id'] for x in old_notices}]==old_notices)
        for item in new:
            linked=[r for r in notices if r['application_id']==item['id']]
            owner=db.execute('SELECT company_id FROM candidate_dashboard_joboffer WHERE id=?',(item['offer_id'],)).fetchone()[0]
            require(len(linked)==1 and linked[0]['recipient_id']==owner)
        unchanged={}
        for table in ('candidate_dashboard_candidateprofile','candidate_dashboard_joboffer','candidate_dashboard_savedoffer'):
            unchanged[table]=rows(db,table)==rows(initial,table);require(unchanged[table])
        own=db.execute("SELECT id FROM accounts_user WHERE email='candidate.postman@worknet.test'").fetchone()[0]
        other=db.execute("SELECT id FROM accounts_user WHERE email='other.postman@worknet.test'").fetchone()[0]
        require(all(r['candidate_id']==other and r['offer_id']==7 for r in new))
        require(len(new)<=1)
        require(not db.execute('SELECT 1 FROM candidate_dashboard_application GROUP BY candidate_id,offer_id HAVING COUNT(*)>1').fetchall())
        return {'offers':len(rows(db,'candidate_dashboard_joboffer')),'applications':len(apps),'own_applications':len([r for r in apps if r['candidate_id']==own]),
                'new_applications':len(new),'new_notices':len(notices)-len(old_notices),'duplicates':0,
                'old_application_content_dates_relations_and_pdfs_unchanged':True,'old_notices_unchanged':True,
                'profiles_offers_and_saved_unchanged':all(unchanged.values()),'snapshot_hashes_and_pdf_valid':True,
                'controlled_status':next(r['status'] for r in apps if r['id']==baseline['controlled_state_target']),
                'legacy_without_cv':len([r for r in apps if not r['cv_source']]),
                'sources_remaining':{source:db.execute('SELECT COUNT(*) FROM curriculum_'+source+'curriculum WHERE candidate_id=?',(own,)).fetchone()[0] for source in ('uploaded','generated')}}


def collection(run,port):
    b=seed(run);own=b['own_ids'];items=[];counts={'HU019':0,'HU020':0}
    def add(tag,name,path,actor='candidate',code=200,check='',method='GET',data=None,pdf=False):
        counts[tag]+=1
        request={'method':method,'url':'{{base_url}}/'+path,'auth':{'type':'noauth'},
                 'header':[{'key':'Accept','value':'application/json, application/pdf'}]}
        if actor:request['header'].append({'key':'Authorization','value':'Token {{'+actor+'_token}}'})
        if data is not None:
            request['header'].append({'key':'Content-Type','value':'application/json'})
            request['body']={'mode':'raw','raw':json.dumps(data,ensure_ascii=False)}
        tests=[f"pm.test('HTTP {code}',()=>pm.response.to.have.status({code}));"]
        if pdf:tests.append("pm.test('PDF privado original',()=>{pm.expect(pm.response.headers.get('Content-Type')).include('application/pdf');pm.expect(pm.response.headers.get('Cache-Control')).include('no-store');pm.expect(pm.response.text().startsWith('%PDF-')).eq(true);});")
        elif check:tests+=['const b=pm.response.json();',"pm.test('Caso y contrato "+tag+"',()=>{"+check+"});"]
        items.append({'name':f'{tag}-P{counts[tag]:02} · '+name,'request':request,'event':[{'listen':'test','script':{'type':'text/javascript','exec':tests}}]})
    def h(name,path='applications/',**kw):add('HU019',name,path,**kw)
    def c(name,path,**kw):add('HU020',name,path,actor=kw.pop('actor','company'),**kw)
    h('Historial propio con cuatro estados','applications/?page_size=50',check="pm.expect(b.count).eq(13);pm.expect(new Set(b.applications.map(a=>a.status)).size).eq(4);pm.expect(b.applications.every(a=>a.offer.title&&a.offer.company_name&&a.created_at)).eq(true);")
    for offer,state in [(13,'submitted'),(4,'in_review'),(5,'accepted'),(6,'rejected')]:
        h('Detalle estado '+state,f'applications/{own[str(offer)]}/',check=f"pm.expect(b.application.status).eq('{state}');")
    for offer,source in [(3,'uploaded'),(4,'generated')]:
        h('Documento elegido '+source,f'applications/{own[str(offer)]}/',check=f"pm.expect(b.application.cv.source).eq('{source}');pm.collectionVariables.set('hash_{source}',b.application.cv.sha256);")
        h('PDF propio '+source,f'applications/{own[str(offer)]}/cv/',pdf=True)
    h('Página uno estable','applications/?page_size=10',check="pm.expect(b.applications.length).eq(10);pm.expect(b.next_page).eq(2);pm.collectionVariables.set('history_page1',JSON.stringify(b.applications.map(a=>a.id)));")
    h('Página dos y registros históricos','applications/?page_size=10&page=2',check="pm.expect(b.applications.length).eq(3);pm.expect(b.applications.filter(a=>a.cv===null).length).eq(2);pm.expect(b.applications.every(a=>!JSON.parse(pm.collectionVariables.get('history_page1')).includes(a.id))).eq(true);")
    h('Otro candidato vacío',actor='other',check='pm.expect(b.count).eq(0);')
    h('Detalle ajeno privado',f'applications/{own["13"]}/',actor='other',code=404)
    h('PDF ajeno privado',f'applications/{own["3"]}/cv/',actor='other',code=404)
    for q in ('page_size=51','candidate_id=2','page=1&page=1','page=999'):
        h('Parámetro inválido '+q,'applications/?'+q,code=400)
    h('Sin sesión',actor=None,code=401)
    h('Sin flujo de cambio HU021',f'applications/{own["13"]}/',method='PATCH',data={'status':'accepted'},code=405)
    base='company/offers/3/applications/'
    c('Seleccionar solo ofertas propias','company/applicant-offers/',check=f"pm.expect(b.count).eq(17);pm.expect(b.offers.some(o=>o.id==={b['foreign_offer']})).eq(false);")
    c('Postulantes propios con nombres y página',base,check="pm.expect(b.count).eq(14);pm.expect(b.applications.length).eq(10);pm.expect(b.applications.every(a=>a.candidate.full_name)).eq(true);pm.collectionVariables.set('applicants_page1',JSON.stringify(b.applications.map(a=>a.id)));")
    c('Página dos sin duplicados',base+'?page=2',check="pm.expect(b.applications.length).eq(4);pm.expect(b.applications.every(a=>!JSON.parse(pm.collectionVariables.get('applicants_page1')).includes(a.id))).eq(true);")
    for q,count in [('experience=BACKEND',9),('education=INGENIERIA',6),('skill=pYtHoN',6),('experience=Backend&education=Ingenieria&skill=Python',4),('education=Doctorado',0)]:
        c('Filtro '+q,base+'?'+q,check=f"pm.expect(b.count).eq({count});pm.expect(b.filter_scope).eq('current_profile');")
    c('Orden por nombre',base+'?order=name',check="pm.expect(b.applications[0].candidate.full_name).eq('Candidato principal QA');")
    c('Orden por fecha más antigua',base+'?order=oldest',check=f"pm.expect(b.applications[0].id).eq({own['3']});")
    for q in ('order=invalid','page_size=51','page=999','skill=Python&skill=Excel','candidate_id=1','education=%0Aotro'):
        c('Parámetro rechazado '+q,base+'?'+q,code=400)
    c('Oferta de otra empresa',f'company/offers/{b["foreign_offer"]}/applications/',code=404)
    for suffix in ('','profile/','cv/'):
        c('Identificador ajeno '+(suffix or 'detalle'),f'company/applications/{b["foreign_application"]}/'+suffix,code=404)
    c('Otra empresa solo ve su oferta','company/applicant-offers/',actor='other_company',check='pm.expect(b.count).eq(1);')
    c('Candidato no consulta postulantes',base,actor='candidate',code=403)
    c('Empresa pendiente no consulta',base,actor='draft',code=403)
    c('Consulta sin sesión',base,actor=None,code=401)
    c('Perfil propio autorizado',f'company/applications/{own["3"]}/profile/',check="pm.expect(b.profile.skills.some(s=>s.name==='Python')).eq(true);pm.expect(b.candidate.full_name).eq('Candidato principal QA');")
    for offer in (3,4):
        c('Consulta de oferta conservada '+str(offer),f'company/offers/{offer}/applications/',check=f"pm.expect(b.offer.status).eq('{ 'closed' if offer==3 else 'archived'}');")
    c('Histórico sin CV inventado','company/applications/1/',check='pm.expect(b.application.cv).eq(null);')
    c('Histórico sin documento','company/applications/1/cv/',code=404)
    c('Cambiar plantilla fuente','curriculum/generated/',actor='candidate',method='PATCH',data={'template':'minimalista'},check="pm.expect(b.curriculum.template).eq('minimalista');")
    c('Eliminar fuente subida','curriculum/uploaded/',actor='candidate',method='DELETE',check='pm.expect(b.uploaded).eq(null);')
    c('Eliminar fuente generada','curriculum/generated/',actor='candidate',method='DELETE',check='pm.expect(b.exists).eq(false);')
    for offer,source in [(3,'uploaded'),(4,'generated')]:
        c('Metadatos originales conservados '+source,f'company/applications/{own[str(offer)]}/',check=f"pm.expect(b.application.cv.sha256).eq(pm.collectionVariables.get('hash_{source}'));"+("pm.expect(b.application.cv.template).eq('moderna');" if source=='generated' else ''))
        c('PDF enviado permanece '+source,f'company/applications/{own[str(offer)]}/cv/',pdf=True)
    return {'info':{'_postman_id':str(uuid.uuid4()),'name':'HU019–HU020 · Historial y postulantes QA · '+run.name,'schema':'https://schema.getpostman.com/json/collection/v2.1.0/collection.json'},
            'event':[{'listen':'prerequest','script':{'type':'text/javascript','exec':[
              f"if(pm.environment.get('base_url')!=='http://127.0.0.1:{port}/api'||pm.environment.get('qa_run_id')!=='{run.name}'||pm.environment.get('qa_confirmation')!=='SOLO_BASE_AISLADA'){{pm.execution.skipRequest();throw Error('Solo QA nueva HU019/HU020');}}"]}}], 'item':items}


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('action',choices=['prepare','contrast']);parser.add_argument('--port',type=int,default=8099);parser.add_argument('--run');args=parser.parse_args()
    spec=importlib.util.spec_from_file_location('hu01920_qa_prepare',HERE/'qa.py');qa=importlib.util.module_from_spec(spec);spec.loader.exec_module(qa)
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
    folder=run/'import-hu019-hu020';folder.mkdir()
    col=collection(run,args.port);qa.write(folder/'HU019-HU020.postman_collection.json',col)
    shutil.copy2(run/'local.postman_environment.json',folder/'HU019-HU020.private.postman_environment.json')
    print('HU019/HU020 preparada; '+str(len(col['item']))+' peticiones. Carpeta privada: '+str(folder))


if __name__=='__main__':main()
