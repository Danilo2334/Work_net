"""Colección Desktop HU026: sin secretos; variables privadas solo durante el Runner."""
import argparse
import json
import shutil
import uuid
from pathlib import Path

from hu026_api import HERE, json_write, require, seed


def collection(run, port):
    baseline = seed(run)
    items = []
    def add(name, path, code=200, actor=None, method='GET', body=None, check='', after='', pre=''):
        request = {'method': method, 'url': '{{base_url}}/'+path, 'auth': {'type':'noauth'}, 'header':[]}
        if actor:
            request['header'].append({'key':'Authorization','value':'Token {{'+actor+'_token}}'})
        if body is not None:
            request['header'].append({'key':'Content-Type','value':'application/json'})
            request['body'] = {'mode':'raw','raw':json.dumps(body, ensure_ascii=False)}
        tests = [f"pm.test('HTTP {code}',()=>pm.expect(pm.response.code).eq({code}));",
            f"if(pm.response.code!=={code}){{pm.execution.setNextRequest(null);throw Error('QA_HTTP_UNEXPECTED');}}",
            "const b=pm.response.json();"]
        if check:
            tests += ["let contractOK=false;pm.test('Contrato HU026',()=>{"+check+"contractOK=true;});",
                "if(!contractOK){pm.execution.setNextRequest(null);throw Error('QA_CONTRACT_FAILED');}"]
        if after:
            tests.append(after)
        events = [{'listen':'test','script':{'type':'text/javascript','exec':tests}}]
        if pre:
            events.insert(0, {'listen':'prerequest','script':{'type':'text/javascript','exec':pre.splitlines()}})
        items.append({'name':f'HU026-P{len(items)+1:02} · '+name,'request':request,'event':events})

    no_token = "pm.expect(!Object.hasOwn(b,'token')).eq(true);"
    def login(actor, enrollment):
        add('Contraseña '+actor+' requiere segundo factor', 'login/', 202, method='POST',
            body={'email':'{{'+actor+'_email}}','password':'{{qa_password}}'},
            check=no_token+f"pm.expect(b.mfa_required===true&&b.enrollment_required==={str(enrollment).lower()}&&typeof b.challenge==='string').eq(true);",
            after=f"pm.variables.set('{actor}_challenge',b.challenge);")
    def setup(actor):
        add('Preparar autenticador privado '+actor, 'admin/mfa/setup/', method='POST',
            body={'challenge':'{{'+actor+'_challenge}}'},
            check="pm.expect(typeof b.secret==='string'&&/^[A-Z2-7]{32}$/.test(b.secret)).eq(true);",
            after=f"pm.variables.set('{actor}_secret',b.secret);")
    source = (Path(__file__).parent/'hu026_totp.cjs').read_text(encoding='utf-8').split("if (typeof module")[0]
    def otp_pre(actor, invalid=False):
        # Wait for the real clock, never edit server time/last_t. First invalid attempt needs 1s throttle recovery.
        text = "const qaKeepAlive=setInterval(()=>{},100);try{\n"+source+f"\nconst actor={json.dumps(actor)};\nconst secret=pm.variables.get(actor+'_secret');\n"
        text += "const last=Number(pm.variables.get(actor+'_last_step')??-1);if(last>=Math.floor(Date.now()/30000)){await new Promise(r=>setTimeout(r,(last+1)*30000-Date.now()+150));}\n"
        text += "await new Promise(r=>setTimeout(r,1200));const remainder=Date.now()%30000;if(remainder>15000){await new Promise(r=>setTimeout(r,30000-remainder+150));}const step=Math.floor(Date.now()/30000);let code=await hu026Totp(secret,step);\n"
        if invalid:
            text += "const valid=new Set(await Promise.all([step-1,step,step+1].map(t=>hu026Totp(secret,t))));let n=0;while(valid.has(String(n).padStart(6,'0')))n++;code=String(n).padStart(6,'0');\n"
        text += "pm.variables.set(actor+'_current_code',code);pm.variables.set(actor+'_sent_step',step);const resolved=pm.variables.replaceIn('{{'+actor+'_current_code}}');if(typeof code!=='string'||!/^\\d{6}$/.test(code)||resolved!==code){pm.execution.skipRequest();throw Error('QA_OTP_NOT_READY');}"
        text += "\npm.request.body.update(JSON.stringify({challenge:pm.variables.get(actor+'_challenge'),code,recovery:false}));}finally{clearInterval(qaKeepAlive);}"
        return text
    def verify(actor, invalid=False):
        if invalid:
            add('TOTP incorrecto rechazado', 'admin/mfa/verify/', 400, method='POST',
                body={'challenge':'{{'+actor+'_challenge}}','code':'{{'+actor+'_current_code}}'},
                check=no_token, pre=otp_pre(actor, True))
            return
        add('TOTP real confirmado '+actor, 'admin/mfa/verify/', method='POST',
            body={'challenge':'{{'+actor+'_challenge}}','code':'{{'+actor+'_current_code}}'},
            check="pm.expect(typeof b.token==='string'&&/^[a-f0-9]{40}$/.test(b.token)&&b.user?.mfa_verified===true&&b.user?.role==='admin').eq(true);",
            after=f"pm.variables.set('{actor}_token',b.token);pm.variables.set('{actor}_last_step',pm.variables.get('{actor}_sent_step'));pm.variables.set('{actor}_replay_code',pm.variables.get('{actor}_current_code'));if(b.recovery_codes){{pm.variables.set('{actor}_recovery',b.recovery_codes[0]);}}",
            pre=otp_pre(actor))

    add('Preflight aislado sin sesión', 'account/',401,
        check=f"pm.expect(pm.response.headers.get('X-WorkNet-QA-Run')==={json.dumps(run.name)}).eq(true);",
        after=f"pm.variables.set('hu026_identity',{json.dumps(run.name)});")
    add('Token administrativo anterior no acredita MFA', 'account/',401,actor='legacy_admin')
    for actor in ['candidate','company']:
        add('Rol '+actor+' no gestiona administradores','admin/accounts/',403,actor=actor)
    login('principal',True)
    add('Desafío no equivale a sesión', 'admin/accounts/',401)
    setup('principal')
    verify('principal',True)
    verify('principal')
    login('principal',False)
    add('TOTP usado rechazado dentro del mismo periodo','admin/mfa/verify/',400,method='POST',
        body={'challenge':'{{principal_challenge}}','code':'{{principal_replay_code}}'},
        check=no_token+"pm.expect(Number(pm.variables.get('principal_last_step'))===Math.floor(Date.now()/30000)).eq(true);")
    add('Sesión MFA principal', 'account/',actor='principal',
        check="pm.expect(b.user?.mfa_verified===true&&b.user?.administrative_role==='principal'&&b.user?.permissions?.length===5).eq(true);")
    add('Dashboard HU007 y avisos', 'dashboard/admin/',actor='principal',
        check="pm.expect(Number.isInteger(b.metrics?.candidates)&&Number.isInteger(b.metrics?.companies)&&b.metrics?.pending_companies>=1&&b.notifications?.length>=1).eq(true);")
    for page, length in [(1,20),(2,8)]:
        add('Listado administrativo página '+str(page), 'admin/accounts/?page='+str(page),actor='principal',
            check=f"pm.expect(b.count===28&&b.page==={page}&&b.results?.length==={length}&&b.results.every(x=>typeof x.full_name==='string'&&typeof x.email==='string'&&typeof x.administrative_role==='string'&&typeof x.is_active==='boolean')).eq(true);")
    for query in ['page=0','page=1&page=1','permission=superuser']:
        add('Parámetro rechazado '+query.split('=')[0],'admin/accounts/?'+query,400,actor='principal')
    add('Eventos relevantes sin secretos','admin/events/',actor='principal',
        check="pm.expect(Array.isArray(b.events)&&b.events.some(e=>e.action==='mfa_enrolled')).eq(true);")
    add('Crear cuenta con verificación pendiente','admin/accounts/',201,actor='principal',method='POST',
        body={'full_name':'Administradora creada HU026 QA','email':'{{created_admin_email}}','password':'{{qa_password}}','administrative_role':'revisor','permissions':['dashboard','review_companies','view_events']},
        check="pm.expect(b.administrator?.email_verified===false&&b.administrator?.mfa_enrolled===false&&!Object.hasOwn(b.administrator,'password')&&b.administrator?.administrative_role==='revisor').eq(true);",
        after="pm.variables.set('created_admin_id',b.administrator.id);")
    add('Nueva cuenta no accede sin verificar correo','login/',400,method='POST',body={'email':'{{created_admin_email}}','password':'{{qa_password}}'},check=no_token)
    add('Principal protegido contra baja propia','admin/accounts/'+str(baseline['principal_id'])+'/',403,actor='principal',method='PATCH',body={'version':0,'is_active':False})
    add('Alta no admite superusuario inyectado','admin/accounts/',400,actor='principal',method='POST',body={'full_name':'Inválida QA','email':'invalida@hu026.invalid','password':'{{qa_password}}','administrative_role':'principal','is_superuser':True})
    add('Principal no se elimina desde cuenta','account/delete/',403,actor='principal',method='DELETE',body={'current_password':'{{qa_password}}','confirmation':True})
    login('reviewer',True)
    setup('reviewer')
    verify('reviewer')
    add('Revisor conserva validación empresarial','admin/companies/',actor='reviewer',check="pm.expect(b.count>=1).eq(true);")
    add('Revisor no configura administradores','admin/accounts/',403,actor='reviewer')
    login('manager',True)
    setup('manager')
    verify('manager')
    add('Gestor consulta administradores','admin/accounts/',actor='manager',check="pm.expect(b.count===29).eq(true);")
    add('Gestor no crea cuentas principales','admin/accounts/',403,actor='manager',method='POST',body={'full_name':'No autorizada QA','email':'sinpermiso@hu026.invalid','password':'{{qa_password}}','administrative_role':'revisor'})
    add('Gestor sin permiso no concede autoridad','admin/accounts/'+str(baseline['reviewer_id'])+'/',403,actor='manager',method='PATCH',body={'version':0,'permissions':['dashboard']})
    add('Gestor desactiva sin alterar permisos','admin/accounts/'+str(baseline['reviewer_id'])+'/',actor='manager',method='PATCH',body={'version':0,'is_active':False},
        check="pm.expect(b.administrator?.is_active===false&&b.administrator?.permissions?.length===3&&b.administrator?.version===1).eq(true);")
    add('Sesión afectada queda revocada','dashboard/admin/',401,actor='reviewer')
    add('Cuenta inactiva no inicia sesión','login/',400,method='POST',body={'email':'{{reviewer_email}}','password':'{{qa_password}}'},check=no_token)
    add('Versión anterior no sobrescribe cambios','admin/accounts/'+str(baseline['reviewer_id'])+'/',409,actor='principal',method='PATCH',body={'version':0,'is_active':True})
    add('Reactivar cuenta y retirar validación empresarial','admin/accounts/'+str(baseline['reviewer_id'])+'/',actor='principal',method='PATCH',body={'version':1,'is_active':True,'permissions':['dashboard']},
        check="pm.expect(b.administrator?.is_active===true&&b.administrator?.permissions?.length===1&&b.administrator?.version===2).eq(true);")
    login('reviewer',False)
    verify('reviewer')
    add('Permisos actuales tras nueva MFA','admin/companies/',403,actor='reviewer')
    add('Administración no gestiona postulaciones','company/offers/3/applications/',403,actor='principal')
    login('principal',False)
    add('Código ya utilizado no abre sesión','admin/mfa/verify/',400,method='POST',body={'challenge':'{{principal_challenge}}','code':'{{principal_replay_code}}'},check=no_token)
    add('Recuperación obliga a configurar segundo factor','admin/mfa/verify/',202,method='POST',body={'challenge':'{{principal_challenge}}','code':'{{principal_recovery}}','recovery':True},
        check=no_token+"pm.expect(b.mfa_required===true&&b.enrollment_required===true).eq(true);",
        after="pm.variables.set('principal_old_recovery',pm.variables.get('principal_recovery'));pm.variables.set('principal_challenge',b.challenge);")
    add('Recuperación revoca sesión anterior','account/',401,actor='principal')
    setup('principal')
    verify('principal')
    add('Acceso recuperado sigue exigiendo MFA','account/',actor='principal',check="pm.expect(b.user?.mfa_verified===true).eq(true);")
    login('principal',False)
    add('Código de recuperación consumido no se reutiliza','admin/mfa/verify/',400,method='POST',body={'challenge':'{{principal_challenge}}','code':'{{principal_old_recovery}}','recovery':True},check=no_token)
    add('Cerrar sesión real','logout/',actor='principal',method='POST',body={})
    add('Sesión cerrada no accede','admin/accounts/',401,actor='principal')
    guard = [f"if(pm.environment.get('base_url')!=='http://127.0.0.1:{port}/api'||pm.environment.get('qa_run_id')!=={json.dumps(run.name)}||pm.environment.get('qa_confirmation')!=='SOLO_BASE_AISLADA'){{pm.execution.skipRequest();throw Error('QA_ISOLATION_REQUIRED');}}",
        "if(pm.info.iteration>0){pm.execution.skipRequest();throw Error('ONE_ITERATION_ONLY');}",
        f"if(pm.info.requestName==={json.dumps(items[0]['name'],ensure_ascii=False)}){{if(pm.collectionVariables.get('qa_consumed')){{pm.execution.skipRequest();throw Error('BASE_ALREADY_CONSUMED');}}pm.collectionVariables.set('qa_consumed',{json.dumps(run.name)});for(const role of ['principal','reviewer','manager']){{pm.variables.set(role+'_current_code','QA_PENDING');pm.variables.set(role+'_sent_step',-1);}}}}else if(pm.variables.get('hu026_identity')!=={json.dumps(run.name)}){{pm.execution.skipRequest();throw Error('SERVER_IDENTITY_REQUIRED');}}"]
    return {'info':{'_postman_id':str(uuid.uuid4()),'name':'HU026 · Administradores y 2FA QA · '+run.name,'schema':'https://schema.getpostman.com/json/collection/v2.1.0/collection.json'},
        'event':[{'listen':'prerequest','script':{'type':'text/javascript','exec':guard}}], 'item':items}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--run',required=True)
    parser.add_argument('--port',type=int,default=8105)
    args=parser.parse_args()
    require(args.run.startswith('run-') and '/' not in args.run and '\\' not in args.run)
    run=HERE/'.local'/args.run
    state=json.loads((run/'state.json').read_text(encoding='utf-8'))
    require(state['port']==args.port)
    folder=run/'import-hu026'
    folder.mkdir()
    data=collection(run,args.port)
    json_write(folder/'HU026.postman_collection.json',data)
    shutil.copy2(run/'local.postman_environment.json',folder/'HU026.private.postman_environment.json')
    print('HU026 Desktop: '+str(len(data['item']))+' peticiones; carpeta privada '+str(folder))


if __name__=='__main__':
    main()
