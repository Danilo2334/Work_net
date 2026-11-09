"""HU026: nueva base ficticia, correo a archivos y actor autenticador de QA local.

Los códigos efímeros se entregan solo por IPC privado al recorrido; nunca a resultados,
capturas, consola pública ni Git. El servidor comprueba TOTP real con django-otp.
"""
import argparse
from datetime import datetime, timezone
from hashlib import sha256
import importlib.util
import json
from pathlib import Path
import shutil
import sqlite3
import time

from hu016_api import require
from hu018_api import HERE, configure
from hu01920_api import fixtures as previous_fixtures


def json_write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, default=str)+'\n', encoding='utf-8')


def env_values(run):
    return {v['key']: v['value'] for v in json.loads((run/'local.postman_environment.json').read_text(encoding='utf-8'))['values']}


def fixtures(run):
    previous_fixtures(run)
    with (run/'.hu026-prepared').open('x', encoding='utf-8') as file:
        file.write('HU026: base nueva, cuentas ficticias, correo a archivos; no LinkedIn.\n')
    from accounts.models import AdminAccess, CompanyProfile, User
    from candidate_dashboard.models import JobOffer
    from django.db import connection
    from rest_framework.authtoken.models import Token
    from rest_framework.test import APIClient
    values = env_values(run)
    principal = User.objects.create_superuser('principal.postman@worknet.test', values['qa_password'], full_name='Principal HU026 QA')
    manager = User.objects.create_user('manager.postman@worknet.test', values['qa_password'], full_name='Gestora HU026 QA', is_staff=True, email_verified=True)
    AdminAccess.objects.create(user=manager, role='gestor', permissions=['dashboard', 'manage_admins'])
    reviewer = User.objects.get(email='admin.postman@worknet.test')
    reviewer.full_name = 'Revisora HU026 QA'
    reviewer.save(update_fields=['full_name'])
    # More than one page; these accounts cannot log in until explicitly activated.
    for index in range(25):
        user = User.objects.create_user(f'inactiva.{index:02}@hu026.invalid', values['qa_password'],
            full_name=f'Revisión ficticia {index:02}', is_staff=True, is_active=False, email_verified=True)
        AdminAccess.objects.create(user=user, role='revisor', permissions=['dashboard'])
    # A genuine company submission supplies the HU007 pending count and internal notice.
    client = APIClient(HTTP_HOST='127.0.0.1')
    login = client.post('/api/login/', {'email': values['draft_email'], 'password': values['qa_password']}, format='json')
    require(login.status_code == 200)
    client.credentials(HTTP_AUTHORIZATION='Token '+login.data['token'])
    info = client.patch('/api/company/', {'legal_name': 'Empresa solicitante HU026 QA', 'tax_id': '900000026-6',
        'sector': 'Tecnología ficticia', 'location': 'Pasto', 'contact_email': 'contacto@hu026.invalid',
        'description': 'Solicitud ficticia de aceptación administrativa.', 'website': '', 'social_links': []}, format='json')
    require(info.status_code == 200)
    require(client.post('/api/company/submit/', {}, format='json').status_code == 200)
    environment = json.loads((run/'local.postman_environment.json').read_text(encoding='utf-8'))
    indexed = {v['key']: v for v in environment['values']}
    def private(key, value):
        if key not in indexed:
            indexed[key] = {'key': key, 'enabled': True, 'type': 'secret'}
            environment['values'].append(indexed[key])
        indexed[key]['value'] = str(value)
    for actor, user in [('principal', principal), ('manager', manager), ('reviewer', reviewer)]:
        private(actor+'_email', user.email)
        private(actor+'_id', user.pk)
    private('created_admin_email', 'creada.hu026@worknet.test')
    private('legacy_admin_token', Token.objects.get_or_create(user=reviewer)[0].key)
    for actor in ['candidate', 'company']:
        user = User.objects.get(email=values[actor+'_email'])
        private(actor+'_token', Token.objects.get_or_create(user=user)[0].key)
    environment['name'] = 'HU026 QA privado '+run.name
    json_write(run/'local.postman_environment.json', environment)
    result = {'offers': JobOffer.objects.count(), 'administrators': User.objects.filter(is_staff=True).count(),
        'principal_id': principal.pk, 'manager_id': manager.pk, 'reviewer_id': reviewer.pk,
        'pending_company_id': CompanyProfile.objects.get(company__email=values['draft_email']).pk,
        'date': datetime.now(timezone.utc).isoformat(),
        'mfa': 'Inicialmente sin configurar; se enrola por la API/interfaz real con autenticador TOTP local ficticio.',
        'data': 'Usuarios ficticios; correo a archivos; sin SMTP ni proveedor externo.'}
    json_write(run/'hu026-baseline.json', result)
    connection.close()
    shutil.copy2(run/'qa.sqlite3', run/'initial.sqlite3')
    return result


def seed(run):
    require((run/'.hu026-prepared').is_file())
    return json.loads((run/'hu026-baseline.json').read_text(encoding='utf-8'))


def private_code(run, actor):
    """Software authenticator for fictional accounts; no server verification is mocked."""
    seed(run)
    require(actor in ('principal', 'manager', 'reviewer', 'created'))
    configure(run)
    from accounts.models import User
    from django_otp.oath import totp
    from django_otp.plugins.otp_totp.models import TOTPDevice
    values = env_values(run)
    email = values['created_admin_email'] if actor == 'created' else values[actor+'_email']
    user = User.objects.get(email=email)
    device = TOTPDevice.objects.get(user=user, name='WorkNet')
    # Never alter clocks/last_t. Wait for the next real step if this one was used.
    deadline = time.monotonic()+35
    while device.last_t >= int(time.time()//device.step):
        require(time.monotonic() < deadline)
        time.sleep(0.2)
        device.refresh_from_db()
    return {'code': f'{totp(device.bin_key, step=device.step, t0=device.t0, digits=device.digits):06d}'}


def contrast(run):
    seed(run)
    result = {'business_unchanged': True, 'non_admin_accounts_unchanged': True, 'tables': {}}
    with sqlite3.connect(run/'qa.sqlite3') as db, sqlite3.connect(run/'initial.sqlite3') as old:
        tables = [r[0] for r in old.execute("SELECT name FROM sqlite_master WHERE type='table' AND (name LIKE 'candidate_dashboard_%' OR name LIKE 'curriculum_%' OR name IN ('accounts_companyprofile','accounts_companyreview')) ORDER BY name")]
        for table in tables:
            initial = old.execute('SELECT * FROM '+table+' ORDER BY rowid').fetchall()
            current = db.execute('SELECT * FROM '+table+' ORDER BY rowid').fetchall()
            require(current == initial)
            result['tables'][table] = {'rows': len(current), 'sha256': sha256(repr(current).encode()).hexdigest(), 'unchanged': True}
        initial = old.execute('SELECT * FROM accounts_user WHERE is_staff=0 AND is_superuser=0 ORDER BY id').fetchall()
        current = db.execute('SELECT * FROM accounts_user WHERE is_staff=0 AND is_superuser=0 ORDER BY id').fetchall()
        require(current == initial)
        result['administrators'] = db.execute('SELECT count(*) FROM accounts_user WHERE is_staff=1 OR is_superuser=1').fetchone()[0]
        result['events'] = db.execute('SELECT action,count(*) FROM accounts_adminevent GROUP BY action ORDER BY action').fetchall()
        result['administrative_sessions'] = db.execute('SELECT count(*) FROM accounts_adminmfasession').fetchone()[0]
        result['no_duplicate_emails'] = not db.execute('SELECT lower(email) FROM accounts_user GROUP BY lower(email) HAVING count(*)>1').fetchall()
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['prepare', 'contrast'])
    parser.add_argument('--port', type=int, default=8105)
    parser.add_argument('--run')
    args = parser.parse_args()
    spec = importlib.util.spec_from_file_location('hu026_qa', HERE/'qa.py')
    qa = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(qa)
    if args.action == 'contrast':
        run, _ = qa.load_run(args.run)
        print(json.dumps(contrast(run)))
        return
    qa.prepare(args.port)
    run, _ = qa.load_run()
    configure(run)
    result = fixtures(run)
    print(json.dumps({'run': run.name, 'baseline': result}, ensure_ascii=True))


if __name__ == '__main__':
    main()
