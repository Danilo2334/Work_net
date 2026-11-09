"""HU025: fixtures ficticias, contraste SQL independiente y colección Desktop."""
import argparse
import csv
from datetime import datetime
from hashlib import sha256
import importlib.util
from io import StringIO
import json
import re
from pathlib import Path
import shutil
import sqlite3
import unicodedata
from urllib.parse import parse_qs
import uuid

from hu016_api import require
from hu018_api import HERE, configure
from hu01920_api import fixtures as previous_fixtures, seed as previous_seed


def fixtures(run):
    previous_fixtures(run)
    with (run/'.hu025-prepared').open('x',encoding='utf-8') as f:f.write('HU025: otra base QA, datos ficticios y correo a archivos.\n')
    from accounts.models import User
    from candidate_dashboard.models import Application
    from django.db import connection
    from rest_framework.authtoken.models import Token
    User.objects.filter(email='candidate.postman@worknet.test').update(full_name='Ángela, "QA" <&>')
    names=['=1+1 QA','  +SUM(1,2) QA','@QA ñ','-1+2 QA']
    for i in range(1,14):
        user=User.objects.get(email=f'postulante.{i:02}@hu020.invalid')
        user.full_name=names[i-1] if i<=4 else f'Postulante HU025 {i:02} '+('Nombre extenso Áé & QA '*5)
        user.full_name=user.full_name[:150];user.save(update_fields=['full_name'])
    env=json.loads((run/'local.postman_environment.json').read_text(encoding='utf-8'));values={v['key']:v for v in env['values']}
    for role in ['candidate','company','admin','draft','other_company']:
        actor=User.objects.get(email=role+'.postman@worknet.test');key=role+'_token'
        if key not in values:values[key]={'key':key,'enabled':True,'type':'secret'};env['values'].append(values[key])
        values[key]['value']=Token.objects.get_or_create(user=actor)[0].key
    (run/'local.postman_environment.json').write_text(json.dumps(env,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    connection.close();shutil.copy2(run/'qa.sqlite3',run/'initial.sqlite3')
    b={**previous_seed(run),'special_names':'Fórmulas, espacios, tildes, comillas/comas y nombres extensos preparados; nombres de CV y documentos enviados originales conservados. Datos ficticios.'}
    (run/'hu025-baseline.json').write_text(json.dumps(b,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    return b


def seed(run):
    require((run/'.hu025-prepared').is_file())
    return json.loads((run/'hu025-baseline.json').read_text(encoding='utf-8'))


def norm(value):
    return ''.join(c for c in unicodedata.normalize('NFKD',value.casefold()) if not unicodedata.combining(c)).strip()


def expected_rows(run,offer=3,query=''):
    seed(run);params={k:v[0] for k,v in parse_qs(query).items()}
    with sqlite3.connect(run/'qa.sqlite3') as db:
        db.row_factory=sqlite3.Row
        clauses=['a.offer_id=?'];values=[offer]
        for key,field in [('experience','experience'),('education','education'),('skill','skills')]:
            if params.get(key):clauses.append('instr(p.selection_'+field+',?)>0');values.append(norm(params[key]))
        order={'newest':'a.created_at DESC,a.id DESC','oldest':'a.created_at,a.id',
               'name':'LOWER(u.full_name),u.id,a.id','name_desc':'LOWER(u.full_name) DESC,u.id DESC,a.id DESC'}[params.get('order','newest')]
        rows=db.execute('SELECT a.id,a.created_at,a.status,a.cv_filename,u.full_name,o.title FROM candidate_dashboard_application a JOIN accounts_user u ON u.id=a.candidate_id JOIN candidate_dashboard_joboffer o ON o.id=a.offer_id LEFT JOIN candidate_dashboard_candidateprofile p ON p.candidate_id=u.id WHERE '+' AND '.join(clauses)+' ORDER BY '+order,values).fetchall()
        return [[str(offer),r['title'],str(r['id']),r['full_name'],datetime.fromisoformat(r['created_at']).strftime('%Y-%m-%d %H:%M:%S UTC'),
                 {'submitted':'Enviada','in_review':'En revisión','accepted':'Aceptada','rejected':'Rechazada'}.get(r['status'],r['status']),r['cv_filename'] or 'No registrado'] for r in rows]


def neutral(value):
    text=''.join(' ' if unicodedata.category(c).startswith('C') else c for c in value)
    return "'"+text if text.lstrip().startswith(('=','+','-','@')) else text


def validate_download(run,artifacts,filename,offer,query):
    require(Path(filename).name==filename and filename.startswith('HU025-') and Path(filename).suffix in ('.csv','.pdf'))
    path=artifacts/filename;raw=path.read_bytes();expected=expected_rows(run,int(offer),query);require(bool(expected))
    result={'file':filename,'bytes':len(raw),'sha256':sha256(raw).hexdigest(),'row_count':len(expected),'query':query,'sql_equal':True}
    if filename.endswith('.csv'):
        require(raw.startswith(b'\xef\xbb\xbf'));rows=list(csv.reader(StringIO(raw.decode('utf-8-sig'))))
        require(rows[0]==['Oferta ID','Oferta','Postulación ID','Nombre','Fecha UTC','Estado','CV enviado'])
        require(rows[1:]==[[neutral(v) for v in row] for row in expected])
        result['application_ids']=[int(row[2]) for row in rows[1:]]
        result['comparison']='CSV: todas las filas, siete campos y orden, con neutralización de fórmulas'
        result['formula_cells_neutralized']=sum(x[3].lstrip().startswith(('=','+','-','@')) for x in expected)
    else:
        from pypdf import PdfReader
        reader=PdfReader(path);text='\n'.join(p.extract_text() for p in reader.pages)
        compact=lambda v:''.join(v.split())
        require(f'{len(expected)} coincidencias.' in text and 'Todas las páginas' in text)
        require(compact(expected[0][0]+' - '+expected[0][1]) in compact(text))
        # En esta fixture los IDs son la única celda con una línea exclusivamente numérica.
        matches=list(re.finditer(r'(?m)^([1-9]\d*)\s*$',text))
        actual_ids=[int(m.group(1)) for m in matches]
        require(actual_ids==[int(row[2]) for row in expected])
        for i,row in enumerate(expected):
            block=compact(text[matches[i].end():matches[i+1].start() if i+1<len(matches) else len(text)])
            require(all(compact(row[k]) in block for k in [3,4,5,6]))
        result['application_ids']=actual_ids
        result['comparison']='PDF: IDs extraídos y orden, nombre/fecha UTC/estado/CV por bloque de fila; oferta, conteo y páginas'
        require(all('Página ' in p.extract_text() for p in reader.pages));result['pages']=len(reader.pages)
    require('@worknet.test' not in raw.decode('utf-8',errors='ignore'))
    return result


def contrast(run):
    seed(run)
    with sqlite3.connect(run/'qa.sqlite3') as db,sqlite3.connect(run/'initial.sqlite3') as old:
        tables=[r[0] for r in old.execute("SELECT name FROM sqlite_master WHERE type='table' AND (name LIKE 'candidate_dashboard_%' OR name LIKE 'curriculum_%' OR name='accounts_companyprofile')")]
        for table in tables:require(db.execute('SELECT * FROM '+table+' ORDER BY rowid').fetchall()==old.execute('SELECT * FROM '+table+' ORDER BY rowid').fetchall())
        users='SELECT id,email,full_name,role,is_active,is_staff,is_superuser,email_verified,password FROM accounts_user ORDER BY id'
        require(db.execute(users).fetchall()==old.execute(users).fetchall())
        require(not db.execute('SELECT 1 FROM candidate_dashboard_application GROUP BY offer_id,candidate_id HAVING COUNT(*)>1').fetchall())
        return {'offers':18,'applications':27,'selected_applicants':14,'all_business_tables_unchanged':True,'accounts_unchanged':True,'private_cv_bytes_dates_relations_unchanged':True,'duplicates':0,'new_business_records':0}


def collection(run,port):
    b=seed(run);items=[]
    def add(name,path,actor='company',code=200,check='',raw_check=False,method='GET'):
        request={'method':method,'url':'{{base_url}}/'+path,'auth':{'type':'noauth'},'header':[]}
        if actor:request['header'].append({'key':'Authorization','value':'Token {{'+actor+'_token}}'})
        if method=='POST':request['header'].append({'key':'Content-Type','value':'application/json'});request['body']={'mode':'raw','raw':'{}'}
        tests=[f"pm.test('HTTP {code}',()=>pm.response.to.have.status({code}));"]
        if check:tests += ([] if raw_check else ['const b=pm.response.json();'])+["pm.test('Contrato HU025',()=>{"+check+"});"]
        items.append({'name':f'HU025-P{len(items)+1:02} · '+name,'request':request,'event':[{'listen':'test','script':{'type':'text/javascript','exec':tests}}]})
    def export(name,kind,query=''):
        expected=expected_rows(run,3,query);check=f"pm.expect(pm.response.headers.get('X-Export-Count')).eq('{len(expected)}');pm.expect(pm.response.headers.get('Content-Disposition')).eq('attachment; filename=\"postulantes-oferta-3.{kind}\"');pm.expect(pm.response.headers.get('X-Export-Scope')).eq('all_filtered_applicants');pm.expect(pm.response.headers.get('Cache-Control')).include('no-store');"
        if kind=='csv':
            # CSV con comillas duplicadas y saltos, sin depender de un split por coma.
            check+="const s=pm.response.text().replace(/^\\uFEFF/,'');let rows=[],row=[],cell='',quoted=false;for(let i=0;i<s.length;i++){const c=s[i];if(c==='\"'){if(quoted&&s[i+1]==='\"'){cell+='\"';i++;}else quoted=!quoted;}else if(c===','&&!quoted){row.push(cell);cell='';}else if(c==='\\n'&&!quoted){row.push(cell.replace(/\\r$/,''));rows.push(row);row=[];cell='';}else cell+=c;}pm.expect(rows.slice(1)).deep.eq("+json.dumps([[neutral(v) for v in row] for row in expected],ensure_ascii=False)+");"
        else:check+="pm.expect(pm.response.headers.get('Content-Type')).include('application/pdf');pm.expect(pm.response.text().slice(0,5)).eq('%PDF-');"
        add(name,f'company/offers/3/applications/export/?file_type={kind}'+('&'+query if query else ''),check=check,raw_check=True)
    add('Listado cerrado propio primera página','company/offers/3/applications/?page_size=10',check='pm.expect(b.count).eq(14);pm.expect(b.applications.length).eq(10);')
    export('CSV todas las páginas y caracteres especiales','csv')
    export('PDF autorizado multipágina','pdf')
    for query in ['experience=Backend','education=Ingenieria','skill=Python','experience=Backend&education=Ingenieria&skill=Python']:
        export('CSV filtro '+query.split('=')[0],'csv',query)
    for order in ['oldest','name','name_desc']:
        export('CSV orden estable '+order,'csv','order='+order)
    export('PDF filtrado y ordenado','pdf','skill=Python&order=name')
    add('Página dos no cambia el total','company/offers/3/applications/?page=2&page_size=10',check='pm.expect(b.count).eq(14);pm.expect(b.applications.length).eq(4);')
    add('Sin coincidencias informa sin descargar','company/offers/3/applications/export/?file_type=csv&skill=Ausente',code=400)
    for q in ['file_type=exe','file_type=csv&page=2','file_type=pdf&page_size=10','file_type=csv&skill=Python&skill=Excel','file_type=pdf&order=otro','file_type=csv&email=si','file_type=csv&skill=%0A']:
        add('Parámetro rechazado '+q.split('=')[0],'company/offers/3/applications/export/?'+q,code=400)
    for actor in ['candidate','admin','draft']:
        add('Rol o aprobación no autorizada','company/offers/3/applications/export/?file_type=csv',actor=actor,code=403)
    add('Oferta ajena','company/offers/'+str(b['foreign_offer'])+'/applications/export/?file_type=pdf',code=404)
    add('Sin sesión','company/offers/3/applications/export/?file_type=csv',actor=None,code=401)
    add('Exportar no admite escritura','company/offers/3/applications/export/?file_type=csv',method='POST',code=405)
    add('Revocar sesión real','logout/',method='POST')
    add('Sesión revocada','company/offers/3/applications/export/?file_type=pdf',code=401)
    guard=[f"if(pm.environment.get('base_url')!=='http://127.0.0.1:{port}/api'||pm.environment.get('qa_run_id')!=='{run.name}'||pm.environment.get('qa_confirmation')!=='SOLO_BASE_AISLADA'){{pm.execution.skipRequest();throw Error('Solo QA HU025');}}",
      "if(pm.info.iteration>0){pm.execution.skipRequest();throw Error('Solo una iteración');}",
      f"if(pm.info.requestName==={json.dumps(items[0]['name'],ensure_ascii=False)}){{if(pm.collectionVariables.get('qa_consumed')){{pm.execution.skipRequest();throw Error('Base consumida');}}pm.collectionVariables.set('qa_consumed','{run.name}');}}"]
    return {'info':{'_postman_id':str(uuid.uuid4()),'name':'HU025 · Exportación QA · '+run.name,'schema':'https://schema.getpostman.com/json/collection/v2.1.0/collection.json'},'event':[{'listen':'prerequest','script':{'type':'text/javascript','exec':guard}}],'item':items}


def main():
    parser=argparse.ArgumentParser();parser.add_argument('action',choices=['prepare','contrast']);parser.add_argument('--port',type=int,default=8103);parser.add_argument('--run');args=parser.parse_args()
    spec=importlib.util.spec_from_file_location('hu025_prepare',HERE/'qa.py');qa=importlib.util.module_from_spec(spec);spec.loader.exec_module(qa)
    if args.action=='contrast':run,_=qa.load_run(args.run);print(json.dumps(contrast(run)));return
    qa.prepare(args.port);run,_=qa.load_run();configure(run);fixtures(run)
    folder=run/'import-hu025';folder.mkdir();col=collection(run,args.port)
    qa.write(folder/'HU025.postman_collection.json',col);shutil.copy2(run/'local.postman_environment.json',folder/'HU025.private.postman_environment.json')
    print('HU025 preparada; '+str(len(col['item']))+' peticiones. Carpeta privada: '+str(folder))
if __name__=='__main__':main()
