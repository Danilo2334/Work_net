"""HU017: fixtures, colección Desktop y contraste sobre otra QA exclusiva."""
import argparse
import hashlib
import importlib.util
import json
import shutil
import sqlite3
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

from hu016_api import connect, require

HERE = Path(__file__).resolve().parents[3] / 'backend/postman'


def fixtures(run):
    require(hashlib.sha256((run/'qa.sqlite3').read_bytes()).digest() == hashlib.sha256((run/'initial.sqlite3').read_bytes()).digest())
    with connect(run) as db:
        require(db.execute('SELECT count(*) FROM candidate_dashboard_joboffer').fetchone()[0] == 2)
        require(db.execute('SELECT count(*) FROM candidate_dashboard_savedoffer').fetchone()[0] == 1)
        with (run/'.hu017-prepared').open('x',encoding='utf-8') as marker:
            marker.write('17 ofertas ficticias; SavedOffer existente; otras relaciones conservadas.\n')
        company=db.execute("SELECT id FROM accounts_user WHERE email='company.postman@worknet.test'").fetchone()[0]
        other=db.execute("SELECT id FROM accounts_user WHERE email='other.postman@worknet.test'").fetchone()[0]
        date=(datetime.now(timezone.utc)-timedelta(days=2)).replace(tzinfo=None).isoformat(sep=' ')
        for i in range(3,18):
            state={14:'closed',15:'archived',16:'draft'}.get(i,'published')
            expiry='2000-01-01 00:00:00' if i==17 else None
            title=f'Favorito QA {i:02}' if i<14 else f'Inactiva QA {i:02}'
            db.execute('INSERT INTO candidate_dashboard_joboffer (title,company_id,company_name,status,published_at,expires_at,description,requirements,salary,location,category,contract_type) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)',
                       (title,company,'Empresa ficticia QA',state,date,expiry,'Descripción QA','Requisitos QA',3000000,'Pasto','Tecnología','Indefinido'))
        for offer in (1,3):
            db.execute('INSERT INTO candidate_dashboard_savedoffer (candidate_id,offer_id,created_at) VALUES (?,?,?)',(other,offer,date))
    shutil.copy2(run/'qa.sqlite3',run/'initial.sqlite3')
    return {'offers':17,'active':13,'own_saved':1,'other_saved':2}


def contrast(run):
    require((run/'.hu017-prepared').is_file())
    with connect(run) as db, sqlite3.connect(run/'initial.sqlite3') as before:
        before.row_factory=sqlite3.Row
        rows=lambda c,t:[dict(r) for r in c.execute('SELECT * FROM '+t+' ORDER BY id')]
        offers,initial=rows(db,'candidate_dashboard_joboffer'),rows(before,'candidate_dashboard_joboffer')
        other=db.execute("SELECT id FROM accounts_user WHERE email='other.postman@worknet.test'").fetchone()[0]
        own=db.execute("SELECT id FROM accounts_user WHERE email='candidate.postman@worknet.test'").fetchone()[0]
        saved=rows(db,'candidate_dashboard_savedoffer');original=rows(before,'candidate_dashboard_savedoffer')
        info=lambda seq:[{k:v for k,v in r.items() if k!='status'} for r in seq]
        duplicate=db.execute('SELECT candidate_id,offer_id,COUNT(*) FROM candidate_dashboard_savedoffer GROUP BY candidate_id,offer_id HAVING COUNT(*)>1').fetchall()
        indexes=list(db.execute("PRAGMA index_list('candidate_dashboard_savedoffer')"))
        unique=any(r['unique'] and [c['name'] for c in db.execute('PRAGMA index_info('+json.dumps(r['name'])+')')]==['candidate_id','offer_id'] for r in indexes)
        return dict(offers=len(offers),states={str(r['id']):r['status'] for r in offers[:2]},information_unchanged=info(offers)==info(initial),
            other_offers_unchanged=offers[2:]==initial[2:],applications_unchanged=rows(db,'candidate_dashboard_application')==rows(before,'candidate_dashboard_application'),
            other_saved_unchanged=[r for r in saved if r['candidate_id']==other]==[r for r in original if r['candidate_id']==other],
            own_saved=[r['offer_id'] for r in saved if r['candidate_id']==own],other_saved=[r['offer_id'] for r in saved if r['candidate_id']==other],
            duplicates=len(duplicate),database_unique_constraint=unique)


def collection(run,port):
    items=[]
    def add(name,method='GET',path='offers/saved/',code=200,check='',token='candidate_token',data=None):
        request={'method':method,'url':'{{base_url}}/'+path,'auth':{'type':'noauth'},'header':[{'key':'Accept','value':'application/json'}]}
        if token:request['header'].append({'key':'Authorization','value':'Token {{'+token+'}}'})
        if data is not None:
            request['header'].append({'key':'Content-Type','value':'application/json'})
            request['body']={'mode':'raw','raw':json.dumps(data)}
        tests=[f"pm.test('HTTP {code}',()=>pm.response.to.have.status({code}));"]
        if check:tests+=['const b=pm.response.json();',"pm.test('Caso y contrato HU017',()=>{"+check+"});"]
        items.append({'name':f'HU017-P{len(items)+1:02} · '+name,'request':request,'event':[{'listen':'test','script':{'type':'text/javascript','exec':tests}}]})
    saved=lambda count:"pm.expect(b.count).eq("+str(count)+");pm.expect(new Set(b.offers.map(o=>o.id)).size).eq(b.offers.length);for(const o of b.offers)pm.expect(o.is_saved).eq(true);"
    member=lambda id,state:f"pm.expect(b.offer_id).eq({id});pm.expect(b.is_saved).eq({str(state).lower()});"
    add('Guardado inicial y contrato',check=saved(1)+"pm.expect(b.offers[0].id).eq(1);pm.expect(b.offers[0].availability).eq('active');pm.expect(b.offers[0].is_active).eq(true);")
    add('Búsqueda antes de guardar',path='offers/search/?q=Oferta%20Django%20QA',check="pm.expect(b.count).eq(1);pm.expect(b.offers[0].is_saved).eq(false);")
    add('Agregar oferta activa','PUT','offers/2/saved/',check=member(2,True))
    add('Repetir agregado idempotente','PUT','offers/2/saved/',check=member(2,True))
    add('Consultar sin duplicados',check=saved(2)+"pm.expect(b.offers.map(o=>o.id).sort()).deep.eq([1,2]);")
    add('Búsqueda sincronizada',path='offers/search/?q=Oferta%20Django%20QA',check="pm.expect(b.count).eq(1);pm.expect(b.offers[0].is_saved).eq(true);")
    add('Contador dashboard',path='dashboard/candidate/',check="pm.expect(b.metrics.saved_offers_count).eq(2);")
    add('Quitar favorito','DELETE','offers/2/saved/',check=member(2,False))
    add('Repetir retiro idempotente','DELETE','offers/2/saved/',check=member(2,False))
    add('Consulta posterior al retiro',check=saved(1)+"pm.expect(b.offers[0].id).eq(1);")
    add('Otro candidato solo sus favoritos',token='other_token',check=saved(2)+"pm.expect(b.offers.map(o=>o.id).sort()).deep.eq([1,3]);")
    add('Retirar relación ajena no la modifica','DELETE','offers/3/saved/',check=member(3,False))
    add('Relaciones ajenas conservadas',token='other_token',check=saved(2)+"pm.expect(b.offers.map(o=>o.id).sort()).deep.eq([1,3]);")
    add('Rol empresa rechazado',code=403,token='company_token')
    add('Sin sesión',code=401,token=None)
    add('No aceptar candidato en cuerpo','PUT','offers/2/saved/',400,"pm.expect(b).property('detail');",data={'candidate_id':2})
    add('No seleccionar candidato ajeno',path='offers/saved/?candidate_id=2',code=400,check="pm.expect(b).property('candidate_id');")
    add('Página inválida',path='offers/saved/?page=2',code=400,check="pm.expect(b).property('page');")
    add('Guardar antes de archivar','PUT','offers/2/saved/',check=member(2,True))
    add('Cerrar oferta guardada HU015','POST','company/offers/1/transition/',check="pm.expect(b.offer.status).eq('closed');",token='company_token',data={'action':'close','confirm':True})
    add('Archivar oferta guardada HU015','POST','company/offers/2/transition/',check="pm.expect(b.offer.status).eq('archived');",token='company_token',data={'action':'archive','confirm':True})
    add('Inactivas conservadas con estado actual',check=saved(2)+"pm.expect(b.offers.map(o=>o.status).sort()).deep.eq(['archived','closed']);for(const o of b.offers)pm.expect(o.is_active).eq(false);")
    add('Cerrada excluida de búsqueda HU016',path='offers/search/?q=Oferta%20Flutter%20QA',check="pm.expect(b.count).eq(0);pm.expect(b.offers).deep.eq([]);")
    add('Archivada excluida de búsqueda HU016',path='offers/search/?q=Oferta%20Django%20QA',check="pm.expect(b.count).eq(0);pm.expect(b.offers).deep.eq([]);")
    add('Repetir guardado propio ahora inactivo','PUT','offers/1/saved/',check=member(1,True))
    add('Retirar cerrada propia','DELETE','offers/1/saved/',check=member(1,False))
    add('Retirar archivada propia','DELETE','offers/2/saved/',check=member(2,False))
    add('Lista vacía real',check=saved(0)+"pm.expect(b.offers).deep.eq([]);pm.expect(b.total_pages).eq(0);")
    add('Otro candidato conserva incluso la cerrada',token='other_token',check=saved(2)+"pm.expect(b.offers.find(o=>o.id===1).availability).eq('closed');")
    add('No crear guardado nuevo sobre cerrada','PUT','offers/1/saved/',404,"pm.expect(b).property('detail');")
    add('Cerrada nunca guardada rechazada','PUT','offers/14/saved/',404,"pm.expect(b).property('detail');")
    add('Vencida nunca guardada rechazada','PUT','offers/17/saved/',404,"pm.expect(b).property('detail');")
    add('Oferta inexistente rechazada','PUT','offers/999999/saved/',404,"pm.expect(b).property('detail');")
    add('Retiro inexistente idempotente','DELETE','offers/999999/saved/',check=member(999999,False))
    add('Tamaño de página inválido',path='offers/saved/?page_size=51',code=400,check="pm.expect(b).property('page_size');")
    add('Dashboard final e inactivas excluidas',path='dashboard/candidate/',check="pm.expect(b.metrics.saved_offers_count).eq(0);pm.expect(b.recent_jobs.every(o=>o.id!==1&&o.id!==2)).eq(true);")
    guard=[f"if(pm.environment.get('base_url')!=='http://127.0.0.1:{port}/api'||pm.environment.get('qa_run_id')!=='{run.name}'||pm.environment.get('qa_confirmation')!=='SOLO_BASE_AISLADA'){{pm.execution.skipRequest();throw Error('Solo nueva QA aislada HU017');}}"]
    return {'info':{'_postman_id':str(uuid.uuid4()),'name':'HU017 · Favoritos QA · '+run.name,'schema':'https://schema.getpostman.com/json/collection/v2.1.0/collection.json'},'event':[{'listen':'prerequest','script':{'type':'text/javascript','exec':guard}}],'item':items}


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('action',choices=['prepare','contrast']);parser.add_argument('--port',type=int,default=8097);parser.add_argument('--run');args=parser.parse_args()
    spec=importlib.util.spec_from_file_location('worknet_qa_hu017',HERE/'qa.py');qa=importlib.util.module_from_spec(spec);spec.loader.exec_module(qa)
    if args.action=='contrast':
        run,_=qa.load_run(args.run);print(json.dumps(contrast(run),ensure_ascii=False));return
    qa.prepare(args.port);run,_=qa.load_run();fixtures(run)
    from accounts.models import User
    from rest_framework.authtoken.models import Token
    env=json.loads((run/'local.postman_environment.json').read_text(encoding='utf-8'));values={v['key']:v for v in env['values']}
    for key in ['candidate','company','other']:
        user=User.objects.get(email=values[key+'_email']['value']);require(user.check_password(values['qa_password']['value']));values[key+'_token']['value']=Token.objects.get_or_create(user=user)[0].key
    qa.write(run/'local.postman_environment.json',env);folder=run/'import-hu017';folder.mkdir()
    qa.write(folder/'HU017.postman_collection.json',collection(run,args.port));shutil.copy2(run/'local.postman_environment.json',folder/'HU017.private.postman_environment.json')
    print('HU017 preparada:17ofertas,13activas,1guardado propio/2ajenos;36casosDesktop. Carpeta privada: '+str(folder))


if __name__=='__main__':main()
