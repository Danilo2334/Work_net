"""Preparación y correo local de Postman; nunca usa db.sqlite3 ni SMTP real."""
import argparse
from datetime import datetime, timezone
from email import policy
from email.parser import BytesParser
import hashlib
import json
from pathlib import Path
import re
import secrets
import shutil
import socket
import sys
import os
import uuid
from urllib.parse import parse_qs, urlsplit

HERE = Path(__file__).resolve().parent
LOCAL = HERE / '.local'


def write(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def load_run(name=None):
    name = name or (LOCAL / 'latest.txt').read_text(encoding='utf-8').strip()
    path = (LOCAL / name).resolve()
    if path.parent != LOCAL.resolve() or not path.name.startswith('run-'):
        raise ValueError('Solo se admite un run-* dentro de postman/.local.')
    state = json.loads((path / 'state.json').read_text(encoding='utf-8'))
    assert state['qa_marker'] == 'WORKNET_POSTMAN_AISLADO'
    assert Path(state['database']).resolve() == path / 'qa.sqlite3'
    return path, state


def configure(path, state):
    sys.path.insert(0, str(HERE.parent))
    os.environ['DJANGO_SETTINGS_MODULE'] = 'config.settings'
    from django.conf import settings
    settings.DATABASES['default']['NAME'] = str(path / 'qa.sqlite3')
    settings.SECRET_KEY = state['signing_key']
    settings.DEBUG = False
    settings.ALLOWED_HOSTS = ['127.0.0.1', 'localhost']
    settings.MAILERS = {'default': {
        'BACKEND': 'django.core.mail.backends.filebased.EmailBackend',
        'OPTIONS': {'file_path': str(path / 'mail')},
    }}
    settings.DEFAULT_FROM_EMAIL = 'qa@worknet.invalid'
    settings.PASSWORD_RESET_FRONTEND_URL = 'http://localhost:55008/reset-password'
    import django
    django.setup()


def prepare(port):
    if not 1024 <= port <= 65535:
        raise ValueError('Puerto local inválido.')
    with socket.socket() as probe:
        if probe.connect_ex(('127.0.0.1', port)) == 0:
            raise ValueError('Ese puerto ya está ocupado. Detén el servidor anterior o elige otro puerto para la nueva base.')
    LOCAL.mkdir(exist_ok=True)
    name = 'run-' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S') + '-' + secrets.token_hex(4)
    path = LOCAL / name
    path.mkdir()
    (path / 'mail').mkdir()
    fixtures = LOCAL / 'fixtures'
    fixtures.mkdir(exist_ok=True)
    from PIL import Image
    if not (fixtures / 'ancha.png').exists():
        Image.new('RGB', (4097, 1), 'white').save(fixtures / 'ancha.png')
    if not (fixtures / 'exceso.png').exists():
        (fixtures / 'exceso.png').write_bytes(b'QA-no-es-imagen-' + b'0' * (2 * 1024 * 1024))
    from io import BytesIO
    from pypdf import PdfWriter
    for filename, active in [('cifrado.pdf', False), ('activo.pdf', True)]:
        if not (fixtures / filename).exists():
            writer = PdfWriter()
            writer.add_blank_page(width=595, height=842)
            if active:
                writer.add_js("app.alert('Solo fixture QA');")
            else:
                writer.encrypt('solo-fixture-qa')
            document = BytesIO()
            writer.write(document)
            (fixtures / filename).write_bytes(document.getvalue())
    if not (fixtures / 'exceso-cv.pdf').exists():
        (fixtures / 'exceso-cv.pdf').write_bytes(b'%PDF-QA-invalido-' + b'0' * (5 * 1024 * 1024))
    state = {'qa_marker': 'WORKNET_POSTMAN_AISLADO', 'database': str(path / 'qa.sqlite3'),
             'port': port, 'signing_key': secrets.token_urlsafe(48), 'created_at': datetime.now(timezone.utc).isoformat()}
    write(path / 'state.json', state)
    configure(path, state)
    from django.core.management import call_command
    from django.utils import timezone as tz
    from accounts.models import User, CompanyProfile
    from candidate_dashboard.models import CandidateProfile, JobOffer, Application, SavedOffer, Notification
    call_command('migrate', verbosity=0)
    password = secrets.token_urlsafe(24) + '!Aa9'
    users = {}
    names = {'candidate': ('Candidato principal QA', 'candidato'), 'other': ('Otro candidato QA', 'candidato'),
             'company': ('Empresa aprobada QA', 'empresa'), 'draft': ('Empresa solicitante QA', 'empresa'),
             'other_company': ('Otra empresa QA', 'empresa'), 'admin': ('Administrador QA', ''),
             'disposable': ('Cuenta desechable QA', 'candidato')}
    for key, (full_name, role) in names.items():
        users[key] = User.objects.create_user(email=f'{key}.postman@worknet.test', full_name=full_name,
            password=password, role=role, email_verified=True, is_staff=key == 'admin')
    CompanyProfile.objects.create(company=users['company'], legal_name='Empresa aprobada QA',
        tax_id='900000001-1', sector='Tecnología QA', location='Pasto', contact_email='contacto@worknet.test',
        description='Empresa ficticia para QA Postman.', state='approved', submitted_at=tz.now())
    CandidateProfile.objects.create(candidate=users['candidate'], professional_summary='Resumen ficticio QA',
        education=[{'title': 'Formación QA'}], experience=[{'title': 'Experiencia QA'}], skills=['Django'])
    for index, title in enumerate(['Oferta Flutter QA', 'Oferta Django QA']):
        offer = JobOffer.objects.create(company=users['company'], title=title, company_name='Empresa aprobada QA',
            location='Pasto', contract_type='Indefinido', status='published', published_at=tz.now())
        Application.objects.create(candidate=users['candidate'], offer=offer)
        if index == 0:
            SavedOffer.objects.create(candidate=users['candidate'], offer=offer)
        Notification.objects.create(recipient=users['candidate'], title=f'Aviso ficticio QA {index+1}')
    from django.db import connection
    connection.close()
    shutil.copy2(path / 'qa.sqlite3', path / 'initial.sqlite3')
    env = json.loads((HERE / 'WorkNet.local.postman_environment.json').read_text(encoding='utf-8'))
    # Cada importación debe conservar el entorno y los resultados del run anterior.
    env['id'] = str(uuid.uuid4())
    values = {i['key']: i for i in env['values']}
    def set_value(key, value):
        values[key]['value'] = value
    set_value('base_url', f'http://127.0.0.1:{port}/api')
    set_value('qa_run_id', name)
    set_value('qa_confirmation', 'SOLO_BASE_AISLADA')
    set_value('qa_password', password)
    set_value('candidate_password', password)
    set_value('registered_password', password)
    set_value('new_password', secrets.token_urlsafe(24) + '!Bb8')
    set_value('account_new_password', secrets.token_urlsafe(24) + '!Cc7')
    for key, user in users.items():
        set_value(key + '_email', user.email)
    set_value('registered_email', 'registro.postman@worknet.test')
    env['name'] = 'WorkNet QA privado ' + name
    write(path / 'local.postman_environment.json', env)
    (LOCAL / 'latest.txt').write_text(name, encoding='utf-8')
    print(f'Base nueva aislada: {name}; servidor previsto en http://127.0.0.1:{port}.')
    print('Importa el entorno privado: ' + str(path / 'local.postman_environment.json'))
    print('Las contraseñas se generaron localmente; correo a archivos, sin SMTP.')


def extract_mail(path, kind):
    env_path = path / 'local.postman_environment.json'
    env = json.loads(env_path.read_text(encoding='utf-8'))
    values = {v['key']: v for v in env['values']}
    email = values['registered_email']['value']
    assert email.endswith('@worknet.test')
    marker = 'verify-email' if kind == 'verification' else 'reset-password'
    found = None
    for file in sorted((path / 'mail').glob('*'), key=lambda f: f.stat().st_mtime_ns, reverse=True):
        message = BytesParser(policy=policy.default).parsebytes(file.read_bytes())
        if email not in str(message.get('To', '')):
            continue
        content = (message.get_body(preferencelist=('plain',)) or message).get_content()
        for url in re.findall(r'https?://[^\s<>]+', content):
            parsed = urlsplit(url)
            if marker in parsed.path:
                assert parsed.hostname in ('localhost', '127.0.0.1')
                found = parse_qs(parsed.query)
                break
        if found:
            break
    if not found:
        raise RuntimeError('No se encontró el correo real capturado. Ejecuta primero la fase correspondiente.')
    updates = {'verification_token': found['token'][0]} if kind == 'verification' else {
        'reset_uid': found['uid'][0], 'reset_token': found['token'][0]}
    for key, value in updates.items():
        values[key]['value'] = value
    write(env_path, env)
    print('Enlace leído del correo capturado; entorno privado actualizado. No acredita entrega SMTP.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    p = sub.add_parser('prepare', help='Nueva base inicial; conserva todos los runs anteriores.')
    p.add_argument('--port', type=int, default=8008)
    p = sub.add_parser('serve')
    p.add_argument('--run')
    p = sub.add_parser('mail')
    p.add_argument('kind', choices=['verification', 'recovery'])
    p.add_argument('--run')
    args = parser.parse_args()
    if args.command == 'prepare':
        prepare(args.port)
        return
    path, state = load_run(args.run)
    if args.command == 'mail':
        extract_mail(path, args.kind)
        return
    configure(path, state)
    # No registra URLs firmadas ni cuerpos de peticiones en la consola.
    from wsgiref.simple_server import make_server, WSGIRequestHandler
    from django.core.wsgi import get_wsgi_application
    class Quiet(WSGIRequestHandler):
        def log_message(self, *args):
            pass
    with make_server('127.0.0.1', state['port'], get_wsgi_application(), handler_class=Quiet) as server:
        print(f'Django QA aislado en http://127.0.0.1:{state["port"]}; correo en archivos locales.', flush=True)
        server.serve_forever()


if __name__ == '__main__':
    main()
