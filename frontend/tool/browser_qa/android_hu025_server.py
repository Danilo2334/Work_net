"""Sirve exclusivamente una HU025 QA preparada, accesible por el emulador local."""
import argparse
import importlib.util
from wsgiref.simple_server import make_server, WSGIRequestHandler
from hu016_api import require
from hu018_api import HERE


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--run',required=True);args=parser.parse_args()
    spec=importlib.util.spec_from_file_location('hu025_android_qa',HERE/'qa.py')
    qa=importlib.util.module_from_spec(spec);spec.loader.exec_module(qa)
    run,state=qa.load_run(args.run);require((run/'.hu025-prepared').is_file());qa.configure(run,state)
    from django.conf import settings
    from django.core.wsgi import get_wsgi_application
    require(settings.MAILERS['default']['BACKEND']=='django.core.mail.backends.filebased.EmailBackend')
    settings.ALLOWED_HOSTS=[*settings.ALLOWED_HOSTS,'10.0.2.2']
    application=get_wsgi_application()
    def isolated(environ,start_response):
        def start(status,headers,exc_info=None):
            return start_response(status,headers+[('X-WorkNet-QA-Run',run.name)],exc_info)
        return application(environ,start)
    class Quiet(WSGIRequestHandler):
        def log_message(self,*args):pass
    print('Servidor Android HU025 local; base nueva y correo a archivos.',flush=True)
    make_server('127.0.0.1',state['port'],isolated,handler_class=Quiet).serve_forever()

if __name__=='__main__':main()
