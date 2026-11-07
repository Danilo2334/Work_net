"""Evidencia HTTP real, solo con servidor/SQLite QA y sin publicar credenciales."""
from datetime import datetime, timedelta
from email import policy
from email.parser import BytesParser
from pathlib import Path
from urllib.error import HTTPError
from urllib.parse import parse_qs, urlencode, urlsplit
from urllib.request import Request, urlopen
from unittest.mock import patch
import json
import os
import re
import secrets
import sys
import time


def main():
    root = Path(sys.argv[1]).resolve()
    output = Path(sys.argv[2]).resolve()
    state = json.loads((root / 'frontend/.dart_tool/worknet_qa/latest.json').read_text(encoding='utf-8'))
    if state['frontend'] != 'http://localhost:55004' or '.dart_tool' not in Path(state['database']).parts:
        raise RuntimeError('Solo se admite la base aislada del servidor QA de normalización.')
    sys.path.insert(0, str(root / 'backend'))
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
    from django.conf import settings
    settings.DATABASES['default']['NAME'] = state['database']
    import django
    django.setup()
    from django.core import signing
    from django.contrib.auth.tokens import default_token_generator
    from accounts.models import User
    from accounts.email_verification import EMAIL_VERIFICATION_SALT

    base = 'http://127.0.0.1:8005'
    groups = {str(n): [] for n in (30,31,35,40,44,45,48,60)}

    def safe(value):
        if isinstance(value, dict):
            return {('credencial_emitida' if k == 'token' else k): (True if k == 'token' else safe(v))
                    for k,v in value.items() if 'password' not in k.lower() and k != 'uid'}
        if isinstance(value, list): return [safe(v) for v in value]
        if isinstance(value, str): return re.sub(r'https?://\S*\?(?:uid|token)=\S+', '[enlace privado omitido]', value)
        return value

    def request(method, path, data=None, token=None, file=None):
        headers = {'Accept': 'application/json, image/jpeg'}
        if token: headers['Authorization'] = 'Token ' + token
        body = None
        if file:
            boundary = 'qa-' + secrets.token_hex(12)
            name, payload = file
            body = (f'--{boundary}\r\nContent-Disposition: form-data; name="photo"; filename="{name}"\r\nContent-Type: image/png\r\n\r\n'.encode() + payload + f'\r\n--{boundary}--\r\n'.encode())
            headers['Content-Type'] = 'multipart/form-data; boundary=' + boundary
        elif data is not None:
            body = json.dumps(data).encode(); headers['Content-Type'] = 'application/json'
        try: response = urlopen(Request(base + path, body, headers, method=method), timeout=20)
        except HTTPError as error: response = error
        raw = response.read(); media = response.headers.get_content_type()
        value = json.loads(raw) if media == 'application/json' else {'imagen_jpeg': media == 'image/jpeg', 'bytes_recibidos': len(raw), 'cache_control': response.headers.get('Cache-Control')}
        return response.status, value

    def case(task, label, method, path, expected, data=None, token=None, file=None, condition=None):
        status, value = request(method,path,data,token,file)
        okay = status == expected and (condition(value) if condition else True)
        groups[str(task)].append({'caso':label,'tipo':'API HTTP local automática','peticion':{'metodo':method,'ruta':urlsplit(path).path,'parametros_privados_omitidos':bool(urlsplit(path).query),'campos_enviados':list(data) if data else (['photo'] if file else [])},'esperado':{'http':expected},'obtenido':{'http':status,'respuesta':safe(value)},'resultado':'aprobado' if okay else 'fallido'})
        if not okay: raise RuntimeError(f'Fallo en tarea {task}: {label}; HTTP {status}')
        return value

    def login(email,password):
        status, value=request('POST','/api/login/',{'email':email,'password':password})
        if status != 200: raise RuntimeError('No se pudo autenticar la cuenta ficticia QA.')
        return value['token']

    def mail_link(recipient, marker):
        for file in sorted(Path(state['mail']).glob('*'), key=lambda f:f.stat().st_mtime, reverse=True):
            message=BytesParser(policy=policy.default).parsebytes(file.read_bytes())
            if recipient not in str(message['To']): continue
            body=(message.get_body(preferencelist=('plain',)) or message).get_content()
            for link in re.findall(r'https?://[^\s<>]+',body):
                if marker in link: return link
        raise RuntimeError('No apareció el enlace en el correo capturado localmente.')

    password=secrets.token_urlsafe(22)+'!Aa9'; suffix=secrets.token_hex(4)
    email=f'registro-{suffix}@worknet.test'; company_email=f'empresa-{suffix}@worknet.test'
    registration={'full_name':'Registro ficticio QA','email':email,'role':'candidato','password':password,'password_confirm':password}
    registered=case(30,'Registro candidato','POST','/api/register/',201,registration,condition=lambda r:r['user']['role']=='candidato' and r['user']['email_verified'] is False)
    case(30,'Correo duplicado','POST','/api/register/',400,registration)
    case(30,'Registro empresa','POST','/api/register/',201,{**registration,'email':company_email,'role':'empresa'},condition=lambda r:r['user']['role']=='empresa')
    case(30,'Rol administrador no público','POST','/api/register/',400,{**registration,'email':f'admin-{suffix}@worknet.test','role':'admin'})
    case(31,'Login previo a verificación','POST','/api/login/',400,{'email':email,'password':password})
    case(31,'Enlace inválido','GET','/api/verify-email/?token=invalido-qa',400)
    with patch('django.core.signing.time.time',return_value=time.time()-172800):
        expired=signing.dumps({'user_id':registered['user']['id'],'email':email},salt=EMAIL_VERIFICATION_SALT)
    case(31,'Enlace vencido','GET','/api/verify-email/?'+urlencode({'token':expired}),400)
    valid_link=mail_link(email,'verify-email')
    path=urlsplit(valid_link).path+'?'+urlsplit(valid_link).query
    case(31,'Abrir enlace capturado a archivo local','GET',path,200)
    case(31,'Reutilización idempotente','GET',path,200)
    logged=case(35,'Login verificado','POST','/api/login/',200,{'email':email,'password':password},condition=lambda r:r['user']['email_verified'] is True and bool(r.get('token')))
    token=logged['token']
    case(35,'Contraseña incorrecta','POST','/api/login/',400,{'email':email,'password':'Incorrecta-QA'})
    case(35,'Correo inexistente','POST','/api/login/',400,{'email':f'ausente-{suffix}@worknet.test','password':password})
    case(35,'Cuenta aún no verificada','POST','/api/login/',400,{'email':company_email,'password':password})

    recovery=case(40,'Solicitud con cuenta existente','POST','/api/password-recovery/request/',200,{'email':email})
    case(40,'Solicitud genérica con correo inexistente','POST','/api/password-recovery/request/',200,{'email':f'ausente-{suffix}@worknet.test'},condition=lambda r:r==recovery)
    link=mail_link(email,'reset-password'); query=parse_qs(urlsplit(link).query)
    recovered_password=secrets.token_urlsafe(22)+'!Aa9'
    fields={'uid':query['uid'][0],'token':query['token'][0],'new_password':recovered_password,'new_password_confirm':recovered_password}
    case(40,'Contraseñas distintas','POST','/api/password-recovery/confirm/',400,{**fields,'new_password_confirm':'Distinta-QA'})
    user=User.objects.get(email=email)
    with patch.object(default_token_generator,'_now',return_value=datetime.now()-timedelta(days=2)):
        expired_reset=default_token_generator.make_token(user)
    case(40,'Enlace de recuperación vencido','POST','/api/password-recovery/confirm/',400,{**fields,'token':expired_reset})
    case(40,'Confirmación válida','POST','/api/password-recovery/confirm/',200,fields)
    case(40,'Token de sesión previo revocado','GET','/api/account/',401,token=token)
    case(40,'Enlace ya utilizado','POST','/api/password-recovery/confirm/',400,fields)
    case(40,'Contraseña anterior rechazada','POST','/api/login/',400,{'email':email,'password':password})
    token=login(email,recovered_password)

    case(44,'Consultar cuenta y correo','GET','/api/account/',200,token=token)
    case(44,'Guardar nombre','PATCH','/api/account/',200,{'full_name':'Nombre actualizado QA'},token)
    case(44,'Nueva consulta conserva nombre','GET','/api/account/',200,token=token,condition=lambda r:r['user']['full_name']=='Nombre actualizado QA')
    case(44,'Correo de solo lectura','PATCH','/api/account/',400,{'email':'intrusion@worknet.test'},token)
    next_password=secrets.token_urlsafe(22)+'!Aa9'
    change={'current_password':recovered_password,'new_password':next_password,'new_password_confirm':next_password}
    case(44,'Contraseña actual incorrecta','POST','/api/account/password/',400,{**change,'current_password':'Incorrecta-QA'},token)
    case(44,'Confirmación distinta','POST','/api/account/password/',400,{**change,'new_password_confirm':'Distinta-QA'},token)
    changed=case(44,'Cambio válido emite token nuevo','POST','/api/account/password/',200,change,token,condition=lambda r:bool(r.get('token')) and r['token']!=token)
    case(44,'Token anterior rechazado','GET','/api/account/',401,token=token)
    token=changed['token']; case(44,'Token nuevo conserva acceso','GET','/api/account/',200,token=token)
    disposable=login('eliminar.qa@worknet.test',state['password'])
    case(44,'Eliminación sin confirmación','DELETE','/api/account/delete/',400,{'current_password':state['password'],'confirmation':False},disposable)
    case(44,'Eliminación confirmada de cuenta desechable','DELETE','/api/account/delete/',200,{'current_password':state['password'],'confirmation':True},disposable)
    case(44,'Cuenta eliminada pierde acceso','GET','/api/account/',401,token=disposable)

    case(45,'Consultar preferencia inicial','GET','/api/account/notifications/',200,token=token)
    for push in [False,True]:
        case(45,'Guardar preferencia '+str(push),'PATCH','/api/account/notifications/',200,{'push_notifications':push},token)
        case(45,'Nueva consulta conserva '+str(push),'GET','/api/account/notifications/',200,token=token,condition=lambda r,push=push:r['preferences']['push_notifications'] is push)
    case(45,'Texto no equivale a booleano','PATCH','/api/account/notifications/',400,{'push_notifications':'false'},token)
    case(45,'Preferencias sin autenticación','GET','/api/account/notifications/',401)

    seeded=login(state['candidate'],state['password']); company=login('empresa.qa@worknet.test',state['password']); other=login('vacio.qa@worknet.test',state['password'])
    case(48,'Datos reales de actividad y completitud','GET','/api/dashboard/candidate/',200,token=seeded,condition=lambda r:r['profile_completion']['percentage']==83 and r['metrics']=={'applications_count':2,'saved_offers_count':1,'pending_notifications_count':2} and len(r['recent_jobs'])==2)
    case(48,'Otro candidato consulta solo sus métricas','GET','/api/dashboard/candidate/',200,token=other,condition=lambda r:all(v==0 for v in r['metrics'].values()))
    case(48,'Dashboard sin autenticación','GET','/api/dashboard/candidate/',401)
    case(48,'Empresa no accede a dashboard candidato','GET','/api/dashboard/candidate/',403,token=company)

    profile='/api/profile/candidate/'
    case(60,'Perfil vacío sin escritura','GET',profile,200,token=token,condition=lambda r:r['profile']['exists'] is False)
    case(60,'Crear descripción','POST',profile,201,{'professional_summary':'Perfil ficticio QA'},token)
    ids={}
    for section,data in [('education',{'qualification':'Título ficticio QA','institution':'Instituto QA','start_date':'2020-01-01'}),('experience',{'position':'Puesto ficticio QA','company':'Empresa QA'}),('skills',{'name':'Flutter QA','level':'intermedio'}),('languages',{'name':'Español QA','level':'nativo'})]:
        result=case(60,'Crear registro '+section,'POST',profile+section+'/',201,data,token)
        ids[section]=result['profile'][section][0]['id']
    case(60,'Editar educación','PATCH',profile+'education/'+ids['education']+'/',200,{'institution':'Instituto editado QA'},token)
    case(60,'Consulta conserva edición y campos para CV','GET',profile,200,token=token,condition=lambda r:r['profile']['education'][0]['institution']=='Instituto editado QA' and r['profile_completion']['percentage']==100)
    case(60,'Eliminar habilidad','DELETE',profile+'skills/'+ids['skills']+'/',200,token=token,condition=lambda r:r['profile']['skills']==[])
    fixture=(root/'frontend/docs/evidencias/hu008/foto-qa.png').read_bytes()
    case(60,'Fotografía válida','PUT',profile+'photo/',200,token=token,file=('foto-qa.png',fixture),condition=lambda r:r['profile']['has_photo'] is True)
    case(60,'Fotografía privada autenticada','GET',profile+'photo/',200,token=token,condition=lambda r:r['imagen_jpeg'] is True and 'no-store' in r['cache_control'])
    case(60,'Contenido falso rechazado','PUT',profile+'photo/',400,token=token,file=('fake.png',b'NO ES UNA IMAGEN QA'))
    case(60,'Otro candidato no lee registro ajeno','GET',profile+'education/'+ids['education']+'/',404,token=other)
    case(60,'Empresa no autorizada','GET',profile,403,token=company)
    case(60,'Perfil sin autenticación','GET',profile,401)
    case(60,'Eliminar fotografía opcional','DELETE',profile+'photo/',200,token=token,condition=lambda r:r['profile']['has_photo'] is False)
    report={'fecha_cliente':'2026-10-18','codigo_backend':'a40045545ff874b079392d55786992786093ee83','tipo':'Peticiones HTTP reales automáticas a Django local','servidor':'http://127.0.0.1:8005','base':'SQLite nueva en .dart_tool; solo datos ficticios QA','correo':'Archivos locales; no SMTP real ni recepción en buzón','revision_humana':'pendiente','responsable':'Danilo2334','grupos':groups,'total_casos':sum(map(len,groups.values()))}
    output.mkdir(parents=True,exist_ok=True)
    (output/'api.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f"API: {report['total_casos']} casos aprobados en base aislada; sin credenciales en informe.")


if __name__=='__main__':
    try: main()
    except Exception as exc:
        # Do not expose URLs, password values or auth headers in exception traces.
        print('La comprobación API no terminó: '+type(exc).__name__)
        raise SystemExit(1)
