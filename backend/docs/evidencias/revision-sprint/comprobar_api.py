"""Peticiones HTTP a la SQLite QA; nunca a la base habitual ni a SMTP real."""
from datetime import datetime, timedelta
from email import policy
from email.parser import BytesParser
from pathlib import Path
from unittest.mock import patch
from urllib.error import HTTPError
from urllib.parse import parse_qs, urlencode, urlsplit
from urllib.request import Request, urlopen
import json
import os
import re
import secrets
import sqlite3
import sys


root = Path(sys.argv[1]).resolve()
out = Path(sys.argv[2]).resolve()
out.mkdir(parents=True, exist_ok=True)
state = json.loads((root / 'frontend/.dart_tool/worknet_qa/latest.json').read_text(encoding='utf-8'))
assert state['frontend'] == 'http://localhost:55006' and '.dart_tool' in Path(state['database']).parts
base = 'http://127.0.0.1:8006/api/'
groups = {name: [] for name in ('registro-sesion', 'informacion-empresa', 'validacion-empresa', 'dashboards')}


def safe(value):
    if isinstance(value, dict):
        return {k: safe(v) for k, v in value.items() if not any(part in k.lower() for part in ('token', 'password', 'uid'))}
    if isinstance(value, list):
        return [safe(v) for v in value]
    return value


def call(method, route, data=None, token=None):
    headers = {'Accept': 'application/json'}
    if token:
        headers['Authorization'] = 'Token ' + token
    body = None
    if data is not None:
        headers['Content-Type'] = 'application/json'
        body = json.dumps(data).encode()
    try:
        response = urlopen(Request(base + route, data=body, headers=headers, method=method), timeout=20)
    except HTTPError as error:
        response = error
    return response.status, json.loads(response.read())


def case(group, label, method, route, expected, data=None, token=None, condition=None):
    status, response = call(method, route, data, token)
    okay = status == expected and (condition(response) if condition else True)
    groups[group].append({'caso': label, 'tipo': 'API HTTP local automática', 'metodo': method, 'ruta': urlsplit('/api/' + route).path, 'campos_enviados': list(data) if data else [], 'esperado': {'http': expected}, 'obtenido': {'http': status, 'respuesta': safe(response)}, 'resultado': 'aprobado' if okay else 'fallido'})
    if not okay:
        raise RuntimeError('Falló: ' + label + '; HTTP ' + str(status))
    return response


def link(email, marker):
    for file in sorted(Path(state['mail']).glob('*'), key=lambda p: p.stat().st_mtime, reverse=True):
        message = BytesParser(policy=policy.default).parsebytes(file.read_bytes())
        if email not in str(message['To']):
            continue
        body = (message.get_body(preferencelist=('plain',)) or message).get_content()
        for url in re.findall(r'https?://[^\s<>]+', body):
            if marker in url:
                return urlsplit(url)
    raise RuntimeError('No se encontró el mensaje en archivos locales de QA.')


def login(email, password):
    status, response = call('POST', 'login/', {'email': email, 'password': password})
    assert status == 200
    return response['token'], response['user']['id']


suffix = secrets.token_hex(5)
password = secrets.token_urlsafe(24) + '!Aa9'
candidate_email = f'api-candidato-{suffix}@worknet.test'
company_email = f'api-empresa-{suffix}@worknet.test'
other_email = f'api-otra-{suffix}@worknet.test'
registration = {'full_name': 'Persona ficticia API QA', 'email': candidate_email, 'password': password, 'password_confirm': password}
registered = case('registro-sesion', 'Cuenta creada sin rol previo', 'POST', 'register/', 201, registration, condition=lambda r: r['user']['role'] == '' and bool(r['registration_token']))
case('registro-sesion', 'No se permite administrador público', 'POST', 'register/role/', 400, {'role': 'admin', 'registration_token': registered['registration_token']})
case('registro-sesion', 'Rol elegido después de crear la cuenta', 'POST', 'register/role/', 200, {'role': 'candidato', 'registration_token': registered['registration_token']}, condition=lambda r: r['user']['role'] == 'candidato')
case('registro-sesion', 'No se permite reasignar el rol', 'POST', 'register/role/', 409, {'role': 'empresa', 'registration_token': registered['registration_token']})
case('registro-sesion', 'Login antes de verificar correo rechazado', 'POST', 'login/', 400, {'email': candidate_email, 'password': password})
case('registro-sesion', 'Enlace de verificación inválido', 'GET', 'verify-email/?token=invalido-qa', 400)

# Generate expired signatures only; all mutations still go through actual HTTP.
sys.path.insert(0, str(root / 'backend'))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
from django.conf import settings
settings.DATABASES['default']['NAME'] = state['database']
import django
django.setup()
from accounts.models import User
from accounts.email_verification import create_verification_token
from django.contrib.auth.tokens import default_token_generator
import time
user = User.objects.get(email=candidate_email)
with patch('django.core.signing.time.time', return_value=time.time() - 172800):
    expired = create_verification_token(user)
case('registro-sesion', 'Enlace de verificación vencido', 'GET', 'verify-email/?' + urlencode({'token': expired}), 400)
verification = link(candidate_email, 'verify-email')
case('registro-sesion', 'Verificación mediante correo capturado a archivos', 'GET', verification.path.replace('/api/', '') + '?' + verification.query, 200)
case('registro-sesion', 'Verificación repetida idempotente', 'GET', verification.path.replace('/api/', '') + '?' + verification.query, 200)
logged = case('registro-sesion', 'Login verificado del candidato', 'POST', 'login/', 200, {'email': candidate_email, 'password': password}, condition=lambda r: r['user']['email_verified'] and r['user']['role'] == 'candidato')
candidate_token = logged['token']
case('registro-sesion', 'Logout remoto confirmado', 'POST', 'logout/', 200, {}, candidate_token)
case('registro-sesion', 'Token revocado no permite consultar cuenta', 'GET', 'account/', 401, token=candidate_token)
case('registro-sesion', 'Recuperación solicitada con respuesta genérica', 'POST', 'password-recovery/request/', 200, {'email': candidate_email})
recovery = link(candidate_email, 'reset-password')
parameters = parse_qs(recovery.query)
with patch.object(default_token_generator, '_now', return_value=datetime.now() - timedelta(days=2)):
    expired = default_token_generator.make_token(user)
new_password = secrets.token_urlsafe(24) + '!Aa9'
reset = {'uid': parameters['uid'][0], 'token': expired, 'new_password': new_password, 'new_password_confirm': new_password}
case('registro-sesion', 'Recuperación con enlace vencido rechazada', 'POST', 'password-recovery/confirm/', 400, reset)
reset['token'] = parameters['token'][0]
case('registro-sesion', 'Recuperación válida mediante mensaje local', 'POST', 'password-recovery/confirm/', 200, reset)
case('registro-sesion', 'Recuperación no permite reutilizar el enlace', 'POST', 'password-recovery/confirm/', 400, reset)
case('registro-sesion', 'Contraseña anterior rechazada', 'POST', 'login/', 400, {'email': candidate_email, 'password': password})
candidate_token, _ = login(candidate_email, new_password)

for email in (company_email, other_email):
    case('informacion-empresa', 'Registro de cuenta empresarial QA ' + ('principal' if email == company_email else 'separada'), 'POST', 'register/', 201, {**registration, 'email': email, 'role': 'empresa'})
    verification = link(email, 'verify-email')
    status, _ = call('GET', verification.path.replace('/api/', '') + '?' + verification.query)
    assert status == 200
company_token, company_id = login(company_email, password)
other_token, _ = login(other_email, password)
admin_token, admin_id = login('admin.qa@worknet.test', state['password'])
case('informacion-empresa', 'Estado inicial pendiente sin solicitud completa', 'GET', 'company/', 200, token=company_token, condition=lambda r: r['company']['state'] == 'pending' and not r['company']['submitted'])
case('informacion-empresa', 'Solicitud incompleta no se envía', 'POST', 'company/submit/', 400, {}, company_token)
case('informacion-empresa', 'Correo de contacto inválido rechazado', 'PATCH', 'company/', 400, {'contact_email': 'no-correo'}, company_token)
case('informacion-empresa', 'Propietario y estado no son editables desde cliente', 'PATCH', 'company/', 400, {'company': 999999, 'state': 'approved'}, company_token)
fields = {'legal_name': 'Empresa ficticia API QA', 'tax_id': str(secrets.randbelow(900_000_000) + 100_000_000) + '-1', 'sector': 'Tecnología QA', 'location': 'Pasto', 'contact_email': 'api@worknet.test', 'description': 'Datos ficticios de API para comprobar persistencia.'}
info = case('informacion-empresa', 'Información empresarial guardada', 'PATCH', 'company/', 200, fields, company_token)['company']
case('informacion-empresa', 'Nueva consulta conserva los datos', 'GET', 'company/', 200, token=company_token, condition=lambda r: all(r['company'][k] == v for k, v in fields.items()))
case('informacion-empresa', 'Otra empresa no recibe los datos ajenos', 'GET', 'company/', 200, token=other_token, condition=lambda r: r['company']['legal_name'] == '' and r['company']['id'] != info['id'])
case('informacion-empresa', 'NIT duplicado en otra cuenta rechazado', 'PATCH', 'company/', 400, fields, other_token)
info = case('informacion-empresa', 'Solicitud completa pasa a revisión', 'POST', 'company/submit/', 200, {}, company_token, condition=lambda r: r['company']['submitted'] and r['company']['state'] == 'pending')['company']
case('informacion-empresa', 'Datos enviados protegidos durante revisión', 'PATCH', 'company/', 400, {'location': 'Cambiar durante revisión'}, company_token)

route = f"admin/companies/{info['id']}/review/"
case('validacion-empresa', 'Listado sin autenticación rechazado', 'GET', 'admin/companies/', 401)
case('validacion-empresa', 'Candidato no puede revisar solicitudes', 'GET', 'admin/companies/', 403, token=candidate_token)
case('validacion-empresa', 'Empresa no puede aprobarse', 'POST', route, 403, {'decision': 'approved', 'version': info['version']}, company_token)
case('validacion-empresa', 'Administrador consulta información completa pendiente', 'GET', 'admin/companies/', 200, token=admin_token, condition=lambda r: any(c['id'] == info['id'] and c['tax_id'] == fields['tax_id'] for c in r['companies']))
case('validacion-empresa', 'Rechazo exige motivo', 'POST', route, 400, {'decision': 'rejected', 'version': info['version']}, admin_token)
case('validacion-empresa', 'Rechazo registra responsable y motivo', 'POST', route, 200, {'decision': 'rejected', 'version': info['version'], 'reason': 'Corrige la sede ficticia.'}, admin_token, condition=lambda r: r['company']['reviewed_by'] == admin_id and r['company']['state'] == 'rejected')
case('validacion-empresa', 'Empresa recibe estado y motivo del rechazo', 'GET', 'company/', 200, token=company_token, condition=lambda r: r['company']['rejection_reason'] == 'Corrige la sede ficticia.' and bool(r['notifications']))
case('validacion-empresa', 'Empresa corrige información rechazada', 'PATCH', 'company/', 200, {'location': 'Sede corregida QA'}, company_token)
info = case('validacion-empresa', 'Reenvío restablece estado pendiente', 'POST', 'company/submit/', 200, {}, company_token, condition=lambda r: r['company']['state'] == 'pending' and r['company']['rejection_reason'] == '')['company']
case('validacion-empresa', 'Aprobación habilita estado y registra administrador', 'POST', route, 200, {'decision': 'approved', 'version': info['version']}, admin_token, condition=lambda r: r['company']['state'] == 'approved' and r['company']['reviewed_by'] == admin_id)
case('validacion-empresa', 'Decisión obsoleta no sobrescribe aprobación', 'POST', route, 409, {'decision': 'rejected', 'version': info['version'], 'reason': 'Intento con versión anterior'}, admin_token)
case('validacion-empresa', 'Resultado aprobado se notifica dentro de WorkNet', 'GET', 'company/', 200, token=company_token, condition=lambda r: any('aprobada' in n['title'] for n in r['notifications']))
case('informacion-empresa', 'Complementos aprobados conservados', 'PATCH', 'company/', 200, {'website': 'https://example.org', 'social_links': ['https://example.org/qa']}, company_token, condition=lambda r: r['company']['website'] == 'https://example.org')

case('dashboards', 'Empresa aprobada nueva recibe solo sus métricas vacías', 'GET', 'dashboard/company/', 200, token=company_token, condition=lambda r: r['metrics'] == {'active_offers': 0, 'closed_offers': 0, 'applications': 0})
seed_token, seed_id = login('empresa.qa@worknet.test', state['password'])
database = sqlite3.connect(state['database'])
count = lambda sql, args=(): database.execute(sql, args).fetchone()[0]
expected_company = {'active_offers': count("SELECT COUNT(*) FROM candidate_dashboard_joboffer WHERE company_id=? AND status='published' AND (expires_at IS NULL OR datetime(expires_at)>datetime('now'))", (seed_id,)), 'closed_offers': count("SELECT COUNT(*) FROM candidate_dashboard_joboffer WHERE company_id=? AND status='closed'", (seed_id,)), 'applications': count('SELECT COUNT(*) FROM candidate_dashboard_application a JOIN candidate_dashboard_joboffer o ON a.offer_id=o.id WHERE o.company_id=?', (seed_id,))}
case('dashboards', 'Métricas empresariales coinciden con filas de SQLite propias', 'GET', 'dashboard/company/', 200, token=seed_token, condition=lambda r: r['metrics'] == expected_company)
case('dashboards', 'Empresa no aprobada no accede a dashboard', 'GET', 'dashboard/company/', 403, token=other_token)
case('dashboards', 'Candidato no accede a dashboard empresarial', 'GET', 'dashboard/company/', 403, token=candidate_token)
case('dashboards', 'Administrador sin sesión no accede a resumen', 'GET', 'dashboard/admin/', 401)
case('dashboards', 'Empresa no accede a resumen administrativo', 'GET', 'dashboard/admin/', 403, token=company_token)
expected_admin = {'candidates': count("SELECT COUNT(*) FROM accounts_user WHERE role='candidato' AND NOT is_staff AND NOT is_superuser"), 'companies': count("SELECT COUNT(*) FROM accounts_user WHERE role='empresa' AND NOT is_staff AND NOT is_superuser"), 'pending_companies': count("SELECT COUNT(*) FROM accounts_companyprofile WHERE state='pending' AND submitted_at IS NOT NULL")}
case('dashboards', 'Conteos administrativos coinciden con SQLite y existen avisos/eventos', 'GET', 'dashboard/admin/', 200, token=admin_token, condition=lambda r: r['metrics'] == expected_admin and bool(r['notifications']) and bool(r['recent_events']))
database.close()
for token in (candidate_token, company_token, other_token, admin_token, seed_token):
    assert call('POST', 'logout/', {}, token)[0] == 200

report = {'fecha_contexto': '2026-10-19', 'zona': 'America/Bogota', 'codigo_backend': 'f9e4dea', 'entorno': 'HTTP real 127.0.0.1:8006, SQLite aislada y correo a archivos; datos ficticios QA', 'smtp_real': 'no comprobado', 'revision_humana': 'pendiente', 'responsable': 'Danilo2334', 'suite_backend': {'total': 103, 'fallos': 0, 'ejecucion': 'manage.py test accounts candidate_dashboard --noinput; ejecución previa de esta fase sobre el mismo código backend'}, 'metricas_sqlite_contrastadas': {'empresa': expected_company, 'administracion': expected_admin}, 'grupos': groups}
(out / 'resultados-api.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print('Comprobaciones API aprobadas:', sum(map(len, groups.values())))
