"""QA HU016 exclusiva; reutiliza qa.py y nunca conecta a bases del usuario."""
import argparse
import hashlib
import importlib.util
import json
import platform
import shutil
import sqlite3
import statistics
import time
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parents[3] / 'backend/postman'


def require(value):
    if not value:
        raise ValueError('HU016_QA_GUARD_REJECTED')


def connect(run):
    state = json.loads((run / 'state.json').read_text(encoding='utf-8'))
    require(state['qa_marker'] == 'WORKNET_POSTMAN_AISLADO')
    require(Path(state['database']).resolve() == run / 'qa.sqlite3')
    db = sqlite3.connect((run / 'qa.sqlite3').as_uri() + '?mode=rw', uri=True)
    db.row_factory = sqlite3.Row
    return db


def fixtures(run):
    require(hashlib.sha256((run/'qa.sqlite3').read_bytes()).digest() == hashlib.sha256((run/'initial.sqlite3').read_bytes()).digest())
    with connect(run) as db:
        require(db.execute('SELECT count(*) FROM candidate_dashboard_joboffer').fetchone()[0] == 2)
        with (run / '.hu016-prepared').open('x', encoding='utf-8') as marker:
            marker.write('1024 ofertas ficticias; sin SMTP ni sesiones personales.\n')
        company = db.execute("SELECT id FROM accounts_user WHERE email='company.postman@worknet.test'").fetchone()[0]
        other = db.execute("SELECT id FROM accounts_user WHERE email='other_company.postman@worknet.test'").fetchone()[0]
        db.execute('UPDATE accounts_user SET is_active=0 WHERE id=?', (other,))
        now = datetime.now(timezone.utc).replace(tzinfo=None)
        date = lambda days: (now - timedelta(days=days)).isoformat(sep=' ')
        def offer(title, **overrides):
            values = dict(title=title, company_id=company, company_name='Empresa ficticia QA', status='published',
                published_at=date(3), expires_at=None, description='Descripción QA', requirements='Pruebas',
                salary=1500000, location='Pasto', category='Tecnología', contract_type='Indefinido')
            values.update(overrides)
            db.execute('INSERT INTO candidate_dashboard_joboffer (' + ','.join(values) + ') VALUES (' + ','.join('?' for _ in values) + ')', tuple(values.values()))
        for i in range(24):
            title = 'Python Django líder QA' if i == 0 else 'Python Django reciente QA' if i == 1 else f'Python QA {i:02}'
            offer(title, requirements='Python Django' if i == 0 else 'Pruebas', description='Python Django' if i == 0 else 'Django QA',
                  salary=None if i == 23 else (i+1)*1000000, location='Pasto' if i % 2 == 0 else 'Bogotá',
                  category='Tecnología' if i % 2 == 0 else 'Educación', contract_type='Indefinido' if i % 2 == 0 else 'Fijo',
                  published_at=date(2 if i == 0 else 0.5 if i == 1 else 3))
        for status in ['closed','archived','draft']:
            offer('Python inactiva ' + status + ' QA', status=status)
        offer('Python vencida QA', expires_at=date(1))
        offer('Python futura QA', published_at=date(-1))
        offer('Python sin publicación QA', published_at=None)
        offer('Python empresa inactiva QA', company_id=other)
        offer('TÉCNICO QA C++ [A]', location='BOGOTÁ', salary=0, contract_type='Fijo')
        for i in range(990):
            offer(f'Operación QA {i:03}', location='Cali', category='Operaciones', contract_type='Obra o labor', published_at=date(10))
        require(db.execute('SELECT count(*) FROM candidate_dashboard_joboffer').fetchone()[0] == 1024)
    shutil.copy2(run/'qa.sqlite3', run/'initial.sqlite3')
    return {'offers': 1024, 'visible': 1017, 'python': 24}


def contrast(run):
    require((run/'.hu016-prepared').is_file())
    with connect(run) as db, sqlite3.connect(run/'initial.sqlite3') as initial:
        initial.row_factory = sqlite3.Row
        rows = lambda c, table: [dict(r) for r in c.execute('SELECT * FROM '+table+' ORDER BY id')]
        offers, before = rows(db,'candidate_dashboard_joboffer'), rows(initial,'candidate_dashboard_joboffer')
        info = lambda seq: [{k:v for k,v in row.items() if k != 'status'} for row in seq]
        return dict(offers=len(offers), states={str(r['id']):r['status'] for r in offers[:2]},
            information_unchanged=info(offers)==info(before), other_offers_unchanged=offers[2:]==before[2:],
            applications_unchanged=rows(db,'candidate_dashboard_application')==rows(initial,'candidate_dashboard_application'),
            saved_unchanged=rows(db,'candidate_dashboard_savedoffer')==rows(initial,'candidate_dashboard_savedoffer'))


def collection(run, port):
    items = []
    def add(label, query='', code=200, assertion='', token='candidate_token', method='GET', path='offers/search/', data=None):
        checks = [f"pm.test('HTTP {code}',()=>pm.response.to.have.status({code}));"]
        if assertion:
            checks += ["const b=pm.response.json();", "pm.test('Contrato y caso HU016',()=>{"+assertion+"});"]
        request = dict(method=method, header=[{'key':'Accept','value':'application/json'}],
                       url='{{base_url}}/'+path+('?' + query if query else ''),
                       auth={'type':'noauth'})
        if token:
            # Mismo formato de las colecciones existentes: referencia privada,
            # sin importar una API key literal ni provocar un alta en Vault.
            request['header'].append({'key':'Authorization','value':'Token {{'+token+'}}'})
        if data is not None:
            request['header'].append({'key':'Content-Type','value':'application/json'})
            request['body']={'mode':'raw','raw':json.dumps(data)}
        items.append({'name':f'HU016-P{len(items)+1:02} · '+label, 'request':request, 'event':[{'listen':'test','script':{'type':'text/javascript','exec':checks}}]})
    add('Listado activo y contrato', assertion="pm.expect(b.count).eq(1017);pm.expect(b.offers).length(10);pm.expect(b.total_pages).eq(102);for(const o of b.offers){for(const k of ['title','company_name','location','contract_type','salary','published_at'])pm.expect(o).property(k);}")
    add('Relevancia determinista','q=Python',assertion="pm.expect(b.count).eq(24);pm.expect(b.offers[0].title).eq('Python Django líder QA');pm.expect(b.offers.some(o=>o.salary===null)).eq(true);pm.collectionVariables.set('first_ids',JSON.stringify(b.offers.map(o=>o.id)));")
    add('Palabras combinadas AND','q=Python%20Django',assertion="pm.expect(b.count).eq(24);pm.expect(b.offers[0].relevance).eq(16);pm.expect(b.offers[1].title).eq('Python Django reciente QA');")
    add('Ubicación parcial','location=pas',assertion="pm.expect(b.count).eq(14);for(const o of b.offers)pm.expect(o.location).eq('Pasto');")
    add('Rango salarial inclusivo','q=Python&salary_min=3000000&salary_max=5000000',assertion="pm.expect(b.count).eq(3);for(const o of b.offers)pm.expect(Number(o.salary)).within(3000000,5000000);")
    add('Todos los filtros combinados','q=Python%20Django&location=Pasto&salary_min=3000000&salary_max=5000000&category=Tecnolog%C3%ADa&contract_type=Indefinido',assertion="pm.expect(b.count).eq(2);pm.expect(b.offers.map(o=>o.salary)).deep.eq(['5000000.00','3000000.00']);")
    add('Categoría','q=Python&category=Educaci%C3%B3n',assertion="pm.expect(b.count).eq(12);for(const o of b.offers)pm.expect(o.category).eq('Educación');")
    add('Contrato','q=Python&contract_type=Fijo',assertion="pm.expect(b.count).eq(12);for(const o of b.offers)pm.expect(o.contract_type).eq('Fijo');")
    add('Fecha de publicación','q=Python&sort=date',assertion="pm.expect(b.offers[0].title).eq('Python Django reciente QA');for(let i=1;i<b.offers.length;i++)pm.expect(Date.parse(b.offers[i-1].published_at)).at.least(Date.parse(b.offers[i].published_at));")
    add('Segunda página sin duplicados','q=Python&page=2',assertion="pm.expect(b.page).eq(2);pm.expect(b.next_page).eq(3);pm.expect(b.previous_page).eq(1);const old=JSON.parse(pm.collectionVariables.get('first_ids'));for(const o of b.offers)pm.expect(old).not.include(o.id);pm.collectionVariables.set('second_ids',JSON.stringify(b.offers.map(o=>o.id)));")
    add('Última página sin duplicados','q=Python&page=3',assertion="pm.expect(b.offers).length(4);pm.expect(b.next_page).eq(null);const old=[...JSON.parse(pm.collectionVariables.get('first_ids')),...JSON.parse(pm.collectionVariables.get('second_ids'))];for(const o of b.offers)pm.expect(old).not.include(o.id);")
    add('Vacío real','q=NoExisteOfertaHU016',assertion="pm.expect(b.count).eq(0);pm.expect(b.offers).deep.eq([]);pm.expect(b.total_pages).eq(0);")
    add('Unicode y caracteres literales','q=t%C3%A9cnico%20C%2B%2B%20%5BA%5D&location=Bogot%C3%A1',assertion="pm.expect(b.count).eq(1);pm.expect(b.offers[0].title).eq('TÉCNICO QA C++ [A]');pm.expect(b.offers[0].salary).eq('0.00');")
    for label,query,field in [('Rango invertido','salary_min=5&salary_max=3','salary_max'),('Negativo','salary_min=-1','salary_min'),('No finito','salary_min=NaN','salary_min'),('Precisión','salary_min=1.001','salary_min'),('Categoría inválida','category=Inventada','category'),('Orden inválido','sort=salary','sort'),('Página fuera de rango','q=Python&page=4','page'),('Límite superior','page_size=51','page_size'),('Parámetro repetido','q=Python&q=Django','q'),('Parámetro desconocido','owner=1','owner')]:
        add(label,query,400,f"pm.expect(b).property('{field}');")
    add('Sin sesión',code=401,token=None)
    add('Rol empresa rechazado',code=403,token='company_token')
    add('Cerrar oferta con relaciones HU015',code=200,token='company_token',method='POST',path='company/offers/1/transition/',data={'action':'close','confirm':True},assertion="pm.expect(b.offer.status).eq('closed');")
    add('Cerrada excluida del buscador','q=Flutter',assertion="pm.expect(b.count).eq(0);pm.expect(b.offers).deep.eq([]);")
    add('Archivar oferta con relaciones HU015',code=200,token='company_token',method='POST',path='company/offers/2/transition/',data={'action':'archive','confirm':True},assertion="pm.expect(b.offer.status).eq('archived');")
    add('Archivada excluida del buscador','q=Oferta%20Django%20QA',assertion="pm.expect(b.count).eq(0);")
    add('Listado posterior conserva el conjunto','sort=date',assertion="pm.expect(b.count).eq(1015);pm.expect(b.offers.every(o=>o.id!==1&&o.id!==2)).eq(true);")
    guards=[f"const expected='{run.name}';",f"if(pm.environment.get('base_url')!=='http://127.0.0.1:{port}/api'||pm.environment.get('qa_run_id')!==expected||pm.environment.get('qa_confirmation')!=='SOLO_BASE_AISLADA'){{pm.execution.skipRequest();throw new Error('Solo corrida QA HU016 nueva y explícita');}}"]
    return {'info':{'_postman_id':str(uuid.uuid4()),'name':'HU016 · Búsqueda QA · '+run.name,'schema':'https://schema.getpostman.com/json/collection/v2.1.0/collection.json'},'event':[{'listen':'prerequest','script':{'type':'text/javascript','exec':guards}}],'item':items}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['prepare','contrast'])
    parser.add_argument('--port',type=int,default=8096)
    parser.add_argument('--run')
    args=parser.parse_args()
    spec=importlib.util.spec_from_file_location('worknet_qa_hu016',HERE/'qa.py')
    qa=importlib.util.module_from_spec(spec);spec.loader.exec_module(qa)
    if args.action == 'contrast':
        run,_=qa.load_run(args.run)
        print(json.dumps(contrast(run),ensure_ascii=False));return
    qa.prepare(args.port)
    run,state=qa.load_run()
    fixtures(run)
    from accounts.models import User
    from rest_framework.authtoken.models import Token
    from rest_framework.test import APIClient
    from django.db import connection
    from django.test.utils import CaptureQueriesContext
    import django
    env=json.loads((run/'local.postman_environment.json').read_text(encoding='utf-8'))
    values={v['key']:v for v in env['values']}
    for key in ['candidate','company']:
        user=User.objects.get(email=values[key+'_email']['value'])
        require(user.check_password(values['qa_password']['value']))
        values[key+'_token']['value']=Token.objects.get_or_create(user=user)[0].key
    qa.write(run/'local.postman_environment.json',env)
    client=APIClient();client.credentials(HTTP_AUTHORIZATION='Token '+values['candidate_token']['value'])
    measurements=[]
    for i in range(31):
        start=time.perf_counter()
        with CaptureQueriesContext(connection) as queries:
            response=client.get('/api/offers/search/',{'q':'Python Django','sort':'relevance','page':2},HTTP_HOST='127.0.0.1')
        require(response.status_code==200 and response.data['count']==24)
        if i:measurements.append((time.perf_counter()-start)*1000)
    report=dict(date=datetime.now(timezone.utc).isoformat(),offers=1024,visible=1017,matching=24,page_size=10,
        samples=30,warmup=1,method='APIClient Django real, SQLite local, sin red ni navegador; q=Python Django&page=2',
        median_ms=round(statistics.median(measurements),3),p95_ms=round(sorted(measurements)[28],3),max_ms=round(max(measurements),3),
        sql_queries=len(queries),offer_queries=sum('candidate_dashboard_joboffer' in q['sql'] for q in queries),
        python=platform.python_version(),django=django.get_version(),os=platform.system()+' '+platform.release(),mail='archivos, sin SMTP')
    qa.write(run/'performance.json',report)
    folder=run/'import-hu016';folder.mkdir()
    qa.write(folder/'HU016.postman_collection.json',collection(run,args.port))
    shutil.copy2(run/'local.postman_environment.json',folder/'HU016.private.postman_environment.json')
    print('Preparada HU016: 1024 ofertas; 1017 visibles; 30 peticiones Desktop; entorno privado en '+str(folder))


if __name__=='__main__':
    main()
