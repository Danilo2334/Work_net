"""Servidor Desktop exclusivo: base HU026, correo a archivos y marcador de identidad."""
import argparse
import json
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
        def respond(status, headers, exc_info=None):
            return start_response(status, headers+[('X-WorkNet-QA-Run', args.run)], exc_info)
        return application(environ, respond)
    print('HU026 Desktop QA preparada en 127.0.0.1:'+str(args.port), flush=True)
    with make_server('127.0.0.1', args.port, marked, handler_class=Quiet) as server:
        server.serve_forever()


if __name__ == '__main__':
    main()
