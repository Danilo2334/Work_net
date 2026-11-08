"""HU018: preparación API de CV ficticios, colección Desktop y contraste privado."""
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
from hu017_api import fixtures as offer_fixtures

HERE = Path(__file__).resolve().parents[3] / 'backend/postman'


def configure(run):
    require(run.parent == HERE / '.local')
    spec=importlib.util.spec_from_file_location('hu018_qa_config',HERE/'qa.py')
    qa=importlib.util.module_from_spec(spec);spec.loader.exec_module(qa)
    selected,state=qa.load_run(run.name);require(selected==run)
    qa.configure(run,state)
    return qa


def client(actor):
    require(actor in ('candidate','other','company','other_company'))
    from accounts.models import User
    from rest_framework.authtoken.models import Token
    from rest_framework.test import APIClient
    user=User.objects.get(email=actor+'.postman@worknet.test')
    require(user.is_active and user.email_verified)
    api=APIClient(HTTP_HOST='127.0.0.1');api.credentials(HTTP_AUTHORIZATION='Token '+Token.objects.get_or_create(user=user)[0].key)
    return api,user


def put_sources(api, *, replaced=False, generated=True):
    from django.core.files.uploadedfile import SimpleUploadedFile
    from curriculum.views import initial_data
    raw=(HERE/'fixtures'/('curriculum-reemplazo.pdf' if replaced else 'curriculum-valido.pdf')).read_bytes()
    filename='cv-reemplazado-qa.pdf' if replaced else 'cv-subido-qa.pdf'
    response=api.put('/api/curriculum/uploaded/',{'file':SimpleUploadedFile(filename,raw,content_type='application/pdf')},format='multipart')
    require(response.status_code in (200,201))
    if generated:
        from accounts.models import User
        user=User.objects.get(email='candidate.postman@worknet.test')
        data=initial_data(user)
        data['education']=[{'qualification':'Formación HU018 QA','institution':'Institución ficticia QA'}]
        data['experience']=[{'position':'Desarrollo QA','company':'Equipo ficticio QA'}]
        data['skills']=[{'name':'Django','level':'avanzado'}]
        data['languages']=[{'name':'Español','level':'nativo'}]
        data['personal']['full_name']='CV reemplazado HU018 QA' if replaced else 'CV principal HU018 QA'
        data['certifications']=[{'title':'Certificación ficticia HU018 QA'}]
        response=api.put('/api/curriculum/generated/',{'template':'minimalista' if replaced else 'moderna','data':data},format='json')
        require(response.status_code in (200,201))


def fixtures(run):
    offer_fixtures(run)
    with (run/'.hu018-prepared').open('x',encoding='utf-8') as f:f.write('HU018: QA aislada; CV preparados por API existente, sin SMTP.\n')
    configure(run)
    from accounts.models import CompanyProfile,User
    from candidate_dashboard.models import CandidateProfile,JobOffer,SavedOffer
    from django.db import connection
    titles={3:'Oferta CV subido QA',4:'Oferta CV generado QA',5:'Oferta cambia a cerrada QA',6:'Oferta cambia a archivada QA',7:'Oferta respuesta perdida QA',8:'Oferta CV eliminado QA',9:'Oferta sin CV QA',10:'Oferta CV cambiado QA',11:'Oferta sesión revocada QA'}
    for pk,title in titles.items():JobOffer.objects.filter(pk=pk).update(title=title)
    other_company=User.objects.get(email='other_company.postman@worknet.test')
    CompanyProfile.objects.get_or_create(company=other_company,defaults={'legal_name':'Otra empresa ficticia HU018 QA','state':'approved','tax_id':'900000002-2'})
    api,own=client('candidate');put_sources(api)
    CandidateProfile.objects.filter(candidate=own).update(
        education=[{'qualification':'Formación HU018 QA','institution':'Institución ficticia QA'}],
        experience=[{'position':'Desarrollo QA','company':'Equipo ficticio QA'}],
        skills=[{'name':'Django','level':'avanzado'}])
    other_api,_=client('other');put_sources(other_api,generated=False)
    for pk in (3,4,5,6,17):SavedOffer.objects.get_or_create(candidate=own,offer_id=pk)
    context=api.get('/api/offers/3/application/');require(context.status_code==200)
    baseline={'choices':context.data['cv_options'],'uploaded_sha256':sha256((HERE/'fixtures/curriculum-valido.pdf').read_bytes()).hexdigest()}
    # Convertir datetimes del serializador sin tocar otros datos ni exportar entorno.
    (run/'hu018-baseline.json').write_text(json.dumps(baseline,default=str,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    connection.close();shutil.copy2(run/'qa.sqlite3',run/'initial.sqlite3')
    return {'offers':17,'active':13,'legacy_applications':2,'own_saved':6,'other_saved':2,'cv_sources':2}


def action(run, name):
    require((run/'.hu018-prepared').is_file());configure(run)
    api,_=client('candidate')
    if name in ('delete_uploaded','delete_generated'):
        path='/api/curriculum/'+name.removeprefix('delete_')+'/'
        r=api.delete(path);require(r.status_code==200)
        return {'actor_qa':'candidate','method':'DELETE','path':path,'status':r.status_code,'procedencia':'APIClient real; actor QA concurrente, no UI'}
    if name=='restore_sources':
        put_sources(api,replaced=True)
        return {'restored':True,'procedencia':'APIClient real de CV existentes; preparación QA'}
    if name=='change_generated':
        r=api.patch('/api/curriculum/generated/',{'template':'clasica'},format='json');require(r.status_code==200)
        return {'actor_qa':'candidate','method':'PATCH','path':'/api/curriculum/generated/','status':r.status_code,'procedencia':'APIClient real; cambio de versión concurrente QA'}
    require(name in ('close_stale','archive_stale'))
    api,_=client('company');offer=5 if name=='close_stale' else 6
    path=f'/api/company/offers/{offer}/transition/'
    r=api.post(path,{'action':'close' if offer==5 else 'archive','confirm':True},format='json');require(r.status_code==200)
    return {'actor_qa':'company','method':'POST','path':path,'status':r.status_code,'procedencia':'APIClient real; transición de actor QA concurrente, no UI'}


def contrast(run):
    require((run/'.hu018-prepared').is_file())
    from pypdf import PdfReader
    baseline=json.loads((run/'hu018-baseline.json').read_text(encoding='utf-8'))
    with connect(run) as db,sqlite3.connect(run/'initial.sqlite3') as initial:
        initial.row_factory=sqlite3.Row
        rows=lambda c,t:[dict(r) for r in c.execute('SELECT * FROM '+t+' ORDER BY id')]
        own=db.execute("SELECT id FROM accounts_user WHERE email='candidate.postman@worknet.test'").fetchone()[0]
        company=db.execute("SELECT id FROM accounts_user WHERE email='company.postman@worknet.test'").fetchone()[0]
        apps,original=rows(db,'candidate_dashboard_application'),rows(initial,'candidate_dashboard_application')
        old_ids={r['id'] for r in original};new=[r for r in apps if r['id'] not in old_ids]
        notices=rows(db,'candidate_dashboard_notification');out=[]
        for r in new:
            raw=bytes(r['cv_document']);require(sha256(raw).hexdigest()==r['cv_sha256'] and len(raw)==r['cv_size_bytes'])
            linked=[n for n in notices if n['application_id']==r['id']]
            require(len(linked)==1 and linked[0]['recipient_id']==company and len(linked[0]['title'])<=200)
            text='\n'.join(p.extract_text() for p in PdfReader(BytesIO(raw)).pages)
            if r['offer_id']==3:require(r['cv_source']=='uploaded' and r['cv_sha256']==baseline['uploaded_sha256'])
            if r['offer_id']==4:require(r['cv_source']=='generated' and 'CV principal HU018 QA' in text and r['cv_template']=='moderna')
            out.append({k:r[k] for k in ('id','offer_id','candidate_id','created_at','status','cv_source','cv_source_id','cv_source_updated_at','cv_filename','cv_template','cv_sha256','cv_size_bytes')})
        offers,old_offers=rows(db,'candidate_dashboard_joboffer'),rows(initial,'candidate_dashboard_joboffer')
        info=lambda seq:[{k:v for k,v in r.items() if k!='status'} for r in seq]
        duplicates=db.execute('SELECT candidate_id,offer_id,COUNT(*) FROM candidate_dashboard_application GROUP BY candidate_id,offer_id HAVING COUNT(*)>1').fetchall()
        indexes=list(db.execute("PRAGMA index_list('candidate_dashboard_application')"))
        unique=any(r['unique'] and [c['name'] for c in db.execute('PRAGMA index_info('+json.dumps(r['name'])+')')]==['candidate_id','offer_id'] for r in indexes)
        return {'offers':len(offers),'states':{str(r['id']):r['status'] for r in offers if r['id'] in (3,4,5,6)},
                'information_unchanged':info(offers)==info(old_offers),
                'other_offers_unchanged':[r for r in offers if r['id'] not in (3,4,5,6)]==[r for r in old_offers if r['id'] not in (3,4,5,6)],
                'legacy_applications_unchanged':[r for r in apps if r['id'] in old_ids]==original,
                'saved_unchanged':rows(db,'candidate_dashboard_savedoffer')==rows(initial,'candidate_dashboard_savedoffer'),
                'other_uploaded_unchanged':[r for r in rows(db,'curriculum_uploadedcurriculum') if r['candidate_id']!=own]==[r for r in rows(initial,'curriculum_uploadedcurriculum') if r['candidate_id']!=own],
                'other_generated_unchanged':[r for r in rows(db,'curriculum_generatedcurriculum') if r['candidate_id']!=own]==[r for r in rows(initial,'curriculum_generatedcurriculum') if r['candidate_id']!=own],
                'old_notifications_unchanged':[r for r in notices if r['application_id'] is None]==rows(initial,'candidate_dashboard_notification'),
                'applications':len(apps),'own_applications':len([r for r in apps if r['candidate_id']==own]),
                'new_applications':out,'new_notices':len([n for n in notices if n['application_id'] is not None]),
                'correct_recipient_and_one_notice_per_new':True,'snapshot_hashes_and_pdf_valid':True,
                'duplicates':len(duplicates),'database_unique_constraint':unique}


def collection(run,port):
    items=[]
    def add(name,method='GET',path='applications/',code=200,check='',actor='candidate',data=None):
        request={'method':method,'url':'{{base_url}}/'+path,'auth':{'type':'noauth'},'header':[{'key':'Accept','value':'application/json, application/pdf'}]}
        if actor:request['header'].append({'key':'Authorization','value':'Token {{'+actor+'_token}}'})
        if data is not None:request['header'].append({'key':'Content-Type','value':'application/json'});request['body']={'mode':'raw','raw':json.dumps(data,ensure_ascii=False)}
        tests=[f"pm.test('HTTP {code}',()=>pm.response.to.have.status({code}));"]
        if check:tests+=['const b=pm.response.headers.get(\'Content-Type\').includes(\'application/json\')?pm.response.json():null;',"pm.test('Caso y contrato HU018',()=>{"+check+'});']
        items.append({'name':f'HU018-P{len(items)+1:02} · '+name,'request':request,'event':[{'listen':'test','script':{'type':'text/javascript','exec':tests}}]})
    body=lambda source:{'cv_source':source,'cv_id':'{{'+source+'_id}}','cv_revision':'{{'+source+'_revision}}','confirm':True}
    # Los ID JSON deben ser números después de resolver las variables.
    def post(name,offer,source='uploaded',code=201,check='',data=None):
        add(name,'POST',f'offers/{offer}/application/',code,check,data=data or body(source))
        raw=items[-1]['request']['body']['raw']
        raw=raw.replace('"{{uploaded_id}}"','{{uploaded_id}}').replace('"{{generated_id}}"','{{generated_id}}').replace('"{{other_cv_id}}"','{{other_cv_id}}')
        items[-1]['request']['body']['raw']=raw
    options="pm.expect(b.cv_options.length).eq(2);for(const c of b.cv_options){pm.environment.set(c.source+'_id',c.id);pm.environment.set(c.source+'_revision',c.revision);}"
    created=lambda s:"pm.expect(b.created).eq(true);pm.expect(b.application.cv.source).eq('"+s+"');pm.expect(b.application.status).eq('submitted');pm.expect(b.application.created_at).a('string');pm.environment.set('app_"+s+"',b.application.id);pm.environment.set('hash_"+s+"',b.application.cv.sha256);"
    repeat=lambda s:"pm.expect(b.created).eq(false);pm.expect(b.application.id).eq(Number(pm.environment.get('app_"+s+"')));pm.expect(b.application.cv.sha256).eq(pm.environment.get('hash_"+s+"'));"
    pdf="pm.expect(pm.response.headers.get('Content-Type')).include('application/pdf');pm.expect(pm.response.text().startsWith('%PDF-')).eq(true);"
    add('Opciones propias y versión del CV',path='offers/3/application/',check=options)
    post('Postular con CV subido',3,check=created('uploaded'))
    post('Repetir envío subido sin duplicar',3,code=200,check=repeat('uploaded'))
    add('Consulta propia con trazabilidad',path='applications/{{app_uploaded}}/',check="pm.expect(b.application.cv.source).eq('uploaded');")
    add('PDF enviado subido privado',path='applications/{{app_uploaded}}/cv/',check=pdf)
    add('Opciones antes del CV generado',path='offers/4/application/',check=options)
    post('Postular con CV generado',4,'generated',check=created('generated'))
    post('Repetir envío generado sin aviso extra',4,'generated',200,repeat('generated'))
    add('PDF enviado generado privado',path='applications/{{app_generated}}/cv/',check=pdf)
    add('Historial propio con ambos CV y fecha',check="pm.expect(b.count).eq(4);pm.expect(b.applications.filter(a=>a.cv!==null).map(a=>a.cv.source).sort()).deep.eq(['generated','uploaded']);")
    add('Contador candidato actualizado',path='dashboard/candidate/',check='pm.expect(b.metrics.applications_count).eq(4);')
    add('Avisos al destinatario empresarial correcto',path='dashboard/company/',actor='company',check="pm.expect(b.metrics.applications).eq(4);pm.expect(b.notifications.length).eq(2);pm.expect(b.notifications.every(n=>n.title.includes('Candidato principal QA'))).eq(true);")
    add('Otra empresa no recibe avisos ni postulaciones',path='dashboard/company/',actor='other_company',check='pm.expect(b.notifications).deep.eq([]);pm.expect(b.metrics.applications).eq(0);')
    add('Otro candidato no hereda historial',actor='other',check='pm.expect(b.count).eq(0);')
    add('Postulación propia oculta a otro candidato',path='applications/{{app_uploaded}}/',actor='other',code=404)
    add('PDF enviado oculto a otro candidato',path='applications/{{app_uploaded}}/cv/',actor='other',code=404)
    add('Postulación oculta a empresa ajena',path='company/applications/{{app_uploaded}}/',actor='other_company',code=404)
    add('PDF oculto a empresa ajena',path='company/applications/{{app_uploaded}}/cv/',actor='other_company',code=404)
    add('Empresa destinataria consulta postulación',path='company/applications/{{app_uploaded}}/',actor='company',check="pm.expect(b.application.cv.source).eq('uploaded');")
    add('Empresa destinataria consulta copia privada',path='company/applications/{{app_uploaded}}/cv/',actor='company',check=pdf)
    add('Rol empresa no puede postular',path='offers/3/application/',actor='company',code=403)
    add('Sin sesión no puede enviar','POST','offers/7/application/',401,actor=None,data=body('uploaded'))
    post('No aceptar candidato enviado',7,code=400,data=body('uploaded')|{'candidate_id':2})
    post('Confirmación obligatoria',7,code=400,data=body('uploaded')|{'confirm':False})
    post('CV ajeno rechazado',7,code=400,data=body('uploaded')|{'cv_id':'{{other_cv_id}}'})
    post('Versión de CV desactualizada rechazada',7,code=400,data=body('uploaded')|{'cv_revision':'2000-01-01T00:00:00Z'})
    for pk,state in [(14,'cerrada'),(15,'archivada'),(17,'vencida'),(16,'borrador')]:post('Rechazar oferta '+state,pk,code=404)
    add('Formulario antes del cierre',path='offers/5/application/',check='pm.expect(b.offer.is_active).eq(true);')
    add('Cerrar después de abrir formulario','POST','company/offers/5/transition/',actor='company',data={'action':'close','confirm':True},check="pm.expect(b.offer.status).eq('closed');")
    post('Revalidar cierre al enviar',5,code=404)
    add('Formulario antes del archivado',path='offers/6/application/',check='pm.expect(b.offer.is_active).eq(true);')
    add('Archivar después de abrir formulario','POST','company/offers/6/transition/',actor='company',data={'action':'archive','confirm':True},check="pm.expect(b.offer.status).eq('archived');")
    post('Revalidar archivado al enviar',6,'generated',404)
    add('Editar fuente generada tras postular','PATCH','curriculum/generated/',data={'template':'minimalista'},check="pm.expect(b.curriculum.template).eq('minimalista');")
    add('Eliminar fuente subida tras postular','DELETE','curriculum/uploaded/',check='pm.expect(b.uploaded).eq(null);')
    post('CV eliminado ya no está disponible',8,code=400)
    add('Eliminar fuente generada tras postular','DELETE','curriculum/generated/',check='pm.expect(b.exists).eq(false);')
    post('CV generado ausente rechazado',9,'generated',400)
    add('Sin CV muestra opciones vacías',path='offers/9/application/',check='pm.expect(b.cv_options).deep.eq([]);')
    add('Copia subida persiste sin la fuente',path='applications/{{app_uploaded}}/cv/',check=pdf)
    add('Copia generada persiste sin la fuente',path='applications/{{app_generated}}/cv/',check=pdf)
    add('Cerrar oferta con postulación real','POST','company/offers/3/transition/',actor='company',data={'action':'close','confirm':True},check="pm.expect(b.offer.status).eq('closed');")
    add('Archivar oferta con postulación real','POST','company/offers/4/transition/',actor='company',data={'action':'archive','confirm':True},check="pm.expect(b.offer.status).eq('archived');")
    add('Historial y copias tras inactivación',check="pm.expect(b.count).eq(4);pm.expect(b.applications.find(a=>a.offer.id===3).offer.status).eq('closed');pm.expect(b.applications.find(a=>a.offer.id===4).offer.status).eq('archived');pm.expect(b.applications.filter(a=>a.cv!==null).every(a=>a.status==='submitted')).eq(true);")
    add('Empresa consulta CV tras archivar',path='company/applications/{{app_generated}}/',actor='company',check="pm.expect(b.application.cv.sha256).eq(pm.environment.get('hash_generated'));")
    for title in ('subido','generado'):add('Exclusión activa del CV '+title,path='offers/search/?q=Oferta%20CV%20'+title+'%20QA',check='pm.expect(b.count).eq(0);pm.expect(b.offers).deep.eq([]);')
    post('Reintento cerrado conserva registro y CV',3,code=200,check=repeat('uploaded'))
    add('Sin avisos duplicados tras reintentos',path='dashboard/company/',actor='company',check='pm.expect(b.notifications.length).eq(2);pm.expect(b.metrics.applications).eq(4);')
    add('Límite de página validado',path='applications/?page_size=51',code=400)
    add('No seleccionar otro candidato por parámetro',path='applications/?candidate_id=2',code=400)
    add('Empresa obtiene PDF conservado de archivada',path='company/applications/{{app_generated}}/cv/',actor='company',check=pdf)
    add('Metadatos de copia generada inmutables',path='applications/{{app_generated}}/',check="pm.expect(b.application.cv.template).eq('moderna');pm.expect(b.application.cv.sha256).eq(pm.environment.get('hash_generated'));")
    add('Historial paginado conserva anteriores sin inventar CV',path='applications/?page_size=2&page=2',check='pm.expect(b.count).eq(4);pm.expect(b.applications.length).eq(2);pm.expect(b.applications.every(a=>a.cv===null)).eq(true);')
    post('Origen de CV inválido rechazado',7,code=400,data=body('uploaded')|{'cv_source':'invalid'})
    guard=[f"if(pm.environment.get('base_url')!=='http://127.0.0.1:{port}/api'||pm.environment.get('qa_run_id')!=='{run.name}'||pm.environment.get('qa_confirmation')!=='SOLO_BASE_AISLADA'){{pm.execution.skipRequest();throw Error('Solo nueva QA aislada HU018');}}"]
    return {'info':{'_postman_id':str(uuid.uuid4()),'name':'HU018 · Postulación QA · '+run.name,'schema':'https://schema.getpostman.com/json/collection/v2.1.0/collection.json'},'event':[{'listen':'prerequest','script':{'type':'text/javascript','exec':guard}}],'item':items}


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('action',choices=['prepare','contrast']);parser.add_argument('--port',type=int,default=8098);parser.add_argument('--run');args=parser.parse_args()
    spec=importlib.util.spec_from_file_location('hu018_qa_prepare',HERE/'qa.py');qa=importlib.util.module_from_spec(spec);spec.loader.exec_module(qa)
    if args.action=='contrast':
        run,_=qa.load_run(args.run);print(json.dumps(contrast(run),ensure_ascii=True));return
    qa.prepare(args.port);run,_=qa.load_run();fixtures(run)
    from rest_framework.authtoken.models import Token
    env=json.loads((run/'local.postman_environment.json').read_text(encoding='utf-8'));values={v['key']:v for v in env['values']}
    for actor in ('candidate','company','other','other_company'):
        _,user=client(actor);require(user.check_password(values['qa_password']['value']))
        key=actor+'_token'
        if key not in values:
            values[key]={'key':key,'value':'','type':'secret','enabled':True};env['values'].append(values[key])
        values[key]['value']=Token.objects.get(user=user).key
    from curriculum.models import UploadedCurriculum
    _,other=client('other')
    env['values'].append({'key':'other_cv_id','value':UploadedCurriculum.objects.get(candidate=other).pk,'type':'default','enabled':True})
    qa.write(run/'local.postman_environment.json',env)
    folder=run/'import-hu018';folder.mkdir()
    col=collection(run,args.port);qa.write(folder/'HU018.postman_collection.json',col)
    shutil.copy2(run/'local.postman_environment.json',folder/'HU018.private.postman_environment.json')
    print('HU018 preparada:17 ofertas,2 postulaciones históricas,6 guardados propios,2 fuentes CV; '+str(len(col['item']))+' peticiones Desktop. Carpeta privada: '+str(folder))


if __name__=='__main__':main()
