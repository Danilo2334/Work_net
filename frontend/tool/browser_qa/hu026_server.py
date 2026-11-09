"""Servidor Desktop exclusivo: base HU026, correo a archivos y marcador de identidad."""
import argparse
import json
from io import BytesIO
from datetime import datetime, timezone
import re
from wsgiref.simple_server import make_server, WSGIRequestHandler

from hu026_api import HERE, configure, require, seed


class Quiet(WSGIRequestHandler):
    def log_message(self, *args):
        pass


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--run', required=True)
    parser.add_argument('--port', type=int, default=8105)
    args = parser.parse_args()
    require(args.run.startswith('run-') and '/' not in args.run and '\\' not in args.run)
    run = HERE/'.local'/args.run
    configure(run)
    seed(run)
    state = json.loads((run/'state.json').read_text(encoding='utf-8'))
    require(state['port'] == args.port)
    from django.conf import settings
    require(settings.DEBUG is False)
    require(settings.MAILERS['default']['BACKEND'] == 'django.core.mail.backends.filebased.EmailBackend')
    from django.core.wsgi import get_wsgi_application
    application = get_wsgi_application()
    def marked(environ, start_response):
        audit = None
        ticket_id = None
        if environ.get('PATH_INFO') == '/api/admin/mfa/verify/' and environ.get('REQUEST_METHOD') == 'POST':
            length = environ.get('CONTENT_LENGTH', '')
            if length.isdigit() and int(length) <= 8192:
                raw = environ['wsgi.input'].read(int(length))
                environ['wsgi.input'] = BytesIO(raw)
                try:
                    body = json.loads(raw)
                    code = body.get('code')
                    audit = {'utc': datetime.now(timezone.utc).isoformat(), 'code_is_string': isinstance(code,str),
                        'code_length': len(code) if isinstance(code,str) else None,
                        'six_ascii_digits': isinstance(code,str) and re.fullmatch(r'[0-9]{6}',code) is not None,
                        'unresolved_template': isinstance(code,str) and '{{' in code,
                        'recovery': body.get('recovery') is True}
                    ticket_id = body.get('challenge')
                    audit['before'] = security_shape(ticket_id)
                except (ValueError, TypeError):
                    audit = {'json_valid':False}
        def respond(status, headers, exc_info=None):
            if audit is not None:
                audit['status'] = int(status.split()[0])
            return start_response(status, headers+[('X-WorkNet-QA-Run', args.run)], exc_info)
        result = application(environ, respond)
        if audit is not None:
            audit['after'] = security_shape(ticket_id)
            with (run/'hu026-request-shapes.private.jsonl').open('a',encoding='utf-8') as file:
                file.write(json.dumps(audit)+'\n')
        return result
    print('HU026 Desktop QA preparada en 127.0.0.1:'+str(args.port), flush=True)
    with make_server('127.0.0.1', args.port, marked, handler_class=Quiet) as server:
        server.serve_forever()


def security_shape(identifier):
    """Only counters/flags; never record a code, seed, password, ticket or Token."""
    from accounts.models import AdminChallenge
    from django.core.exceptions import ValidationError
    from django_otp.plugins.otp_totp.models import TOTPDevice
    try:
        ticket = AdminChallenge.objects.filter(pk=identifier).first()
    except (ValueError, TypeError, ValidationError):
        ticket = None
    if ticket is None:
        return {'ticket_found':False}
    device = TOTPDevice.objects.filter(user_id=ticket.user_id,name='WorkNet').first()
    return {'ticket_found':True, 'attempts':ticket.attempts, 'consumed':ticket.consumed,
        'device_enrolled':device.confirmed if device else False,
        'otp_failures':device.throttling_failure_count if device else None,
        'last_step':device.last_t if device else None}


if __name__ == '__main__':
    main()
