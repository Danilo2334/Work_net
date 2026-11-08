"""Exporta fuentes Git y ejecuta HU012/HU013 en una corrida QA nueva y privada."""
import argparse
from datetime import datetime, timezone
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import importlib.util
import json
import os
from pathlib import Path
import secrets
import shutil
import socket
import subprocess
import sys
import tarfile
import threading
from urllib.parse import urlsplit
from wsgiref.simple_server import make_server, WSGIRequestHandler

BACKEND = 'HEAD'


def git(repo, *args):
    return subprocess.check_output(['git', '-C', str(repo), *args], text=True, encoding='utf-8').strip()


def tool(name):
    value = shutil.which(name + '.cmd') or shutil.which(name + '.bat') or shutil.which(name)
    if not value:
        raise RuntimeError('Falta herramienta: ' + name)
    return value


def command(label, args, cwd, env):
    print(label, flush=True)
    result = subprocess.run([str(a) for a in args], cwd=cwd, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if result.returncode:
        raise RuntimeError(label + ': salida ' + str(result.returncode))


def free_port(preferred):
    with socket.socket() as s:
        s.bind(('127.0.0.1', preferred))
        port = s.getsockname()[1]
    if not 1024 <= port <= 65535:
        raise ValueError('Puerto local inválido')
    return port


def export(repo, sha, name, destination, archive):
    subprocess.run(['git', '-C', str(repo), 'archive', '--format=tar', '-o', str(archive), sha, name], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    with tarfile.open(archive) as files:
        for member in files.getmembers():
            target = (destination / member.name).resolve()
            if not target.is_relative_to(destination.resolve()) or not (member.isfile() or member.isdir()):
                raise ValueError('Archivo Git no permitido')
        files.extractall(destination, filter='data')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--frontend-ref', default='HEAD', help='Fuente Flutter y suite versionada; no copia cambios sin commit.')
    parser.add_argument('--backend-ref', default=BACKEND, help='Fuente backend confirmada del checkout integrado; se exporta en otra carpeta.')
    parser.add_argument('--api-port', type=int, default=0, help='0 elige puerto libre; nunca reutiliza un servicio anterior.')
    parser.add_argument('--web-port', type=int, default=0)
    parser.add_argument('--python', default=sys.executable, help='Python 3.12+ para crear un venv nuevo.')
    parser.add_argument('--suite', choices=['hu012-hu013', 'hu014', 'hu015', 'hu016', 'hu017', 'hu018'], default='hu012-hu013', help='Recorrido en otra base QA nueva.')
    args = parser.parse_args()
    repo = Path(git(Path(__file__).parent, 'rev-parse', '--show-toplevel'))
    common = Path(git(repo, 'rev-parse', '--path-format=absolute', '--git-common-dir'))
    front_sha = git(repo, 'rev-parse', args.frontend_ref + '^{commit}')
    back_sha = git(repo, 'rev-parse', args.backend_ref + '^{commit}')
    api_port, web_port = free_port(args.api_port), free_port(args.web_port)
    if api_port == web_port:
        raise ValueError('Los puertos deben ser distintos')
    root = common / 'worknet-browser-qa' / ('browser-qa-' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S') + '-' + secrets.token_hex(4))
    root.mkdir(parents=True)
    source = root / 'source'
    source.mkdir()
    export(repo, front_sha, 'frontend', source, root / 'frontend.tar')
    export(repo, back_sha, 'backend', source, root / 'backend.tar')
    package = source / 'frontend/tool/browser_qa'
    if not (package / 'suite.cjs').is_file():
        raise RuntimeError('La referencia frontend no contiene el ejecutor publicado')
    print('Fuentes: Flutter/suite ' + front_sha + '; backend ' + back_sha, flush=True)
    env = {k: v for k, v in os.environ.items() if not k.startswith(('GMAIL_', 'SMTP_', 'EMAIL_')) and k not in ['DEBUG', 'PWDEBUG', 'NODE_OPTIONS']}
    env['PYTHONUTF8'] = '1'
    command('Crear venv exclusivo', [args.python, '-m', 'venv', root / '.venv'], repo, env)
    python = root / '.venv' / ('Scripts/python.exe' if os.name == 'nt' else 'bin/python')
    command('Instalar requirements backend fijados', [python, '-m', 'pip', 'install', '-r', source / 'backend/requirements.txt'], source, env)
    command('Instalar npm ci desde lockfile', [tool('npm'), 'ci', '--no-audit', '--no-fund', '--ignore-scripts'], package, env)
    command('Preparar Chromium fijado por Playwright', [tool('node'), package / 'node_modules/playwright/cli.js', 'install', 'chromium'], package, env)
    api_origin, web_origin = f'http://127.0.0.1:{api_port}', f'http://127.0.0.1:{web_port}'
    command('Compilar Flutter JavaScript con recursos locales', [tool('flutter'), 'build', 'web', '--release', '--no-web-resources-cdn', '--dart-define=API_BASE_URL=' + api_origin + '/api/'], source / 'frontend', env)
    command('Crear otra base con el preparador QA existente', [python, source / 'backend/postman/qa.py', 'prepare', '--port', api_port], source, env)
    run_name = (source / 'backend/postman/.local/latest.txt').read_text(encoding='utf-8').strip()
    run = source / 'backend/postman/.local' / run_name
    config = dict(schema='worknet-browser-qa-v1', suite=args.suite, frontend_sha=front_sha, backend_sha=back_sha, nonce=secrets.token_hex(24), api_origin=api_origin, web_origin=web_origin, environment=(run / 'local.postman_environment.json').relative_to(root).as_posix(), python=str(python))
    manifest = root / 'manifest.private.json'
    manifest.write_text(json.dumps(config, indent=2), encoding='utf-8')
    # Usar el venv de esta corrida también para el servidor del orquestador.
    server_args = [python, package / 'run.py', '--serve-private', manifest]
    # El modo privado se maneja antes de argparse en el entrypoint.
    server = subprocess.Popen([str(x) for x in server_args], cwd=source, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        import time
        from urllib.request import urlopen
        for attempt in range(100):
            if server.poll() is not None:
                raise RuntimeError('El servidor QA exclusivo no inició')
            try:
                with urlopen(web_origin, timeout=1) as response:
                    if response.headers.get('X-WorkNet-QA-Run') == config['nonce']:
                        break
            except OSError:
                pass
            time.sleep(0.1)
        else:
            raise RuntimeError('No respondió el servidor QA exclusivo')
        env['WORKNET_QA_MANIFEST'] = str(manifest)
        env['WORKNET_QA_PYTHON'] = str(python)
        print('Ejecutar suite ' + args.suite + '; sin trazas, HAR, storageState ni registros de autenticación', flush=True)
        result = subprocess.run([tool('node'), package / 'suite.cjs'], cwd=package, env=env)
        print('Resultados nuevos (privados): ' + str(root / 'artifacts/resultados.json'), flush=True)
        if result.returncode:
            raise RuntimeError('Suite no aprobada; se conserva la corrida para diagnóstico')
    finally:
        server.terminate()
        server.wait(timeout=15)


def serve(manifest):
    # Solo recibe un manifest de la exportación privada y conserva los guards.
    from bridge import load
    root, run, config = load(manifest)
    spec = importlib.util.spec_from_file_location('worknet_existing_qa', root / 'source/backend/postman/qa.py')
    qa = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(qa)
    qa.configure(run, json.loads((run / 'state.json').read_text(encoding='utf-8')))
    from django.conf import settings
    from django.core.wsgi import get_wsgi_application
    if settings.MAILERS['default']['BACKEND'] != 'django.core.mail.backends.filebased.EmailBackend':
        raise ValueError('SMTP no permitido en QA')
    app = get_wsgi_application()
    def isolated_app(environ, start_response):
        def start(status, headers, exc_info=None):
            return start_response(status, headers + [('X-WorkNet-QA-Run', config['nonce'])], exc_info)
        return app(environ, start)
    class Quiet(WSGIRequestHandler):
        def log_message(self, *args):
            pass
    class Static(SimpleHTTPRequestHandler):
        def do_GET(self):
            target = Path(self.directory) / urlsplit(self.path).path.lstrip('/')
            if not target.exists() and '.' not in target.name:
                self.path = '/index.html'
            super().do_GET()
        def end_headers(self):
            self.send_header('X-WorkNet-QA-Run', config['nonce'])
            self.send_header('Cache-Control', 'no-store')
            super().end_headers()
        def log_message(self, *args):
            pass
    api_server = make_server('127.0.0.1', urlsplit(config['api_origin']).port, isolated_app, handler_class=Quiet)
    web_server = ThreadingHTTPServer(('127.0.0.1', urlsplit(config['web_origin']).port), partial(Static, directory=str(root / 'source/frontend/build/web')))
    threading.Thread(target=api_server.serve_forever, daemon=True).start()
    web_server.serve_forever()


if __name__ == '__main__':
    try:
        if len(sys.argv) == 3 and sys.argv[1] == '--serve-private':
            serve(sys.argv[2])
        else:
            main()
    except Exception as error:
        # Las excepciones internas pueden contener valores de un entorno privado.
        print('QA_RUN_FAILED (' + type(error).__name__ + '). No se modifican corridas anteriores.', flush=True)
        sys.exit(1)
