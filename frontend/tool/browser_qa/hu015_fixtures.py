"""Preparación y contraste HU015 en la base nueva del preparador QA existente."""
import hashlib
import shutil
from datetime import datetime, timezone
from bridge import require, connect, snapshot


def execute(root, run, config, action):
    require(config.get('suite') == 'hu015')
    if action == 'hu015_prepare':
        require(hashlib.sha256((run/'qa.sqlite3').read_bytes()).digest() == hashlib.sha256((run/'initial.sqlite3').read_bytes()).digest())
        require(len(snapshot(run)['offers']) == 2 and not snapshot(run)['curricula'])
        with (root/'.hu015-prepared').open('x', encoding='utf-8') as marker:
            marker.write('Fixtures ficticias; las acciones de producto se ejecutan desde la interfaz.\n')
        with connect(run/'qa.sqlite3') as db:
            db.execute("UPDATE candidate_dashboard_joboffer SET description='Descripción inicial QA',requirements='Requisitos iniciales QA',salary=1000000,category='Tecnología'")
            other=db.execute("SELECT id FROM accounts_user WHERE email='other_company.postman@worknet.test'").fetchone()[0]
            company=db.execute("SELECT id FROM accounts_user WHERE email='company.postman@worknet.test'").fetchone()[0]
            for title,owner,state,expiry in [('Oferta ajena QA',other,'published',None),('Oferta archivada QA',company,'archived',None),('Oferta cerrada QA',company,'closed',None),('Borrador QA',company,'draft',None),('Oferta vencida QA',company,'published','2000-01-01 00:00:00'),('Oferta errores QA',company,'published',None)]:
                db.execute('INSERT INTO candidate_dashboard_joboffer (title,company_id,company_name,status,published_at,expires_at,description,requirements,salary,location,category,contract_type) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)',
                           (title,owner,'Empresa ficticia QA',state,datetime.now(timezone.utc).replace(tzinfo=None).isoformat(sep=' '),expiry,'Descripción QA','Requisitos QA',1000000,'Pasto','Tecnología','Indefinido'))
        shutil.copy2(run/'qa.sqlite3',run/'initial.sqlite3')
        return {'prepared':True,'offers':8}
    require((root/'.hu015-prepared').is_file())
    require(action == 'hu015_snapshot')
    with connect(run/'qa.sqlite3') as db, connect(run/'initial.sqlite3') as initial:
        def rows(c, table): return [dict(r) for r in c.execute('SELECT * FROM '+table+' ORDER BY id')]
        offers=rows(db,'candidate_dashboard_joboffer'); before=rows(initial,'candidate_dashboard_joboffer')
        # Las ocho ofertas iniciales solo pueden cambiar de estado. La novena se
        # publica/edita por la UI para la regresión HU013/HU014.
        unchanged=lambda table:rows(db,table)==rows(initial,table)
        return dict(offers=offers,
                    information_unchanged=[{k:v for k,v in r.items() if k!='status'} for r in offers[:8]]==[{k:v for k,v in r.items() if k!='status'} for r in before],
                    other_offers_unchanged=offers[2:7]==before[2:7],
                    relations_unchanged=unchanged('candidate_dashboard_application') and unchanged('candidate_dashboard_savedoffer'),
                    company_approval_unchanged=unchanged('accounts_companyprofile'), reviews_unchanged=unchanged('accounts_companyreview'),
                    applications=len(rows(db,'candidate_dashboard_application')), saved=len(rows(db,'candidate_dashboard_savedoffer')))
