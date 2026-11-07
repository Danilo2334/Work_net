"""Guard de QA y contrastes de persistencia; nunca devuelve credenciales."""
import hashlib
import json
import re
import sqlite3
import sys
from pathlib import Path
from urllib.parse import urlsplit


def require(condition):
    if not condition:
        raise ValueError('QA_GUARD_REJECTED')


def load(manifest_file):
    file = Path(manifest_file).resolve(strict=True)
    root = file.parent
    require(root.parent.name == 'worknet-browser-qa' and root.name.startswith('browser-qa-'))
    require(file.name == 'manifest.private.json')
    config = json.loads(file.read_text(encoding='utf-8'))
    require(config['schema'] == 'worknet-browser-qa-v1')
    for key in ['frontend_sha', 'backend_sha']:
        require(re.fullmatch('[a-f0-9]{40}', config[key]) is not None)
    require(re.fullmatch('[a-f0-9]{48}', config['nonce']) is not None)
    backend = (root / 'source/backend').resolve(strict=True)
    require(backend == root / 'source/backend')
    env_path = (root / config['environment']).resolve(strict=True)
    run = env_path.parent
    require(env_path.name == 'local.postman_environment.json')
    require(run.parent == backend / 'postman/.local' and run.name.startswith('run-'))
    state = json.loads((run / 'state.json').read_text(encoding='utf-8'))
    require(state['qa_marker'] == 'WORKNET_POSTMAN_AISLADO')
    require(Path(state['database']).resolve(strict=True) == run / 'qa.sqlite3')
    require((run / 'initial.sqlite3').is_file())
    env = {v['key']: v['value'] for v in json.loads(env_path.read_text(encoding='utf-8'))['values']}
    require(env['qa_confirmation'] == 'SOLO_BASE_AISLADA' and env['qa_run_id'] == run.name)
    require(isinstance(env['qa_password'], str) and len(env['qa_password']) >= 12)
    for key in ['candidate', 'other', 'company', 'draft']:
        require(env[key + '_email'] == key + '.postman@worknet.test')
    for key in ['api_origin', 'web_origin']:
        uri = urlsplit(config[key])
        require(uri.scheme == 'http' and uri.hostname == '127.0.0.1')
        require(uri.username is None and uri.password is None and uri.path == '')
        require(not uri.query and not uri.fragment and 1024 <= uri.port <= 65535)
    require(config['api_origin'] != config['web_origin'])
    require(urlsplit(config['api_origin']).port == state['port'])
    require(env['base_url'] == config['api_origin'] + '/api')
    return root, run, config


def connect(path):
    db = sqlite3.connect(path.as_uri() + '?mode=rw', uri=True)
    db.row_factory = sqlite3.Row
    return db


def snapshot(run):
    with connect(run / 'qa.sqlite3') as db, connect(run / 'initial.sqlite3') as initial:
        def profile(c):
            return dict(c.execute('SELECT * FROM candidate_dashboard_candidateprofile WHERE candidate_id=1').fetchone())
        def account(c):
            return tuple(c.execute('SELECT full_name,email FROM accounts_user WHERE id=1').fetchone())
        rows = [dict(r) for r in db.execute('SELECT candidate_id,template,data FROM curriculum_generatedcurriculum ORDER BY candidate_id')]
        for row in rows:
            row['data'] = json.loads(row['data'])
        offers = [dict(r) for r in db.execute('SELECT id,title,company_id,status,salary,category,contract_type FROM candidate_dashboard_joboffer ORDER BY id')]
        return dict(profile_unchanged=profile(db) == profile(initial), account_unchanged=account(db) == account(initial), curricula=rows, offers=offers)


def execute(manifest, action, args):
    root, run, config = load(manifest)
    if action == 'validate':
        return {'isolated': True}
    if action == 'start':
        require(hashlib.sha256((run / 'qa.sqlite3').read_bytes()).digest() == hashlib.sha256((run / 'initial.sqlite3').read_bytes()).digest())
        s = snapshot(run)
        require(len(s['offers']) == 2 and not s['curricula'])
        # Impide volver a ejecutar una suite sobre el mismo estado.
        with (root / '.suite-started').open('x', encoding='utf-8') as file:
            file.write('QA exclusiva; usar run.py para crear otra corrida.\n')
        return {'ready': True}
    require((root / '.suite-started').is_file())
    if action in ['revoke_candidate', 'revoke_company']:
        key = action.removeprefix('revoke_')
        with connect(run / 'qa.sqlite3') as db:
            count = db.execute('DELETE FROM authtoken_token WHERE user_id=(SELECT id FROM accounts_user WHERE email=?)', (key + '.postman@worknet.test',)).rowcount
        require(count == 1)
        return {'revoked': count}
    if action == 'snapshot':
        return snapshot(run)
    if action == 'pdf_compare':
        from pypdf import PdfReader
        texts = []
        for name in args:
            require(re.fullmatch(r'[a-z0-9-]+\.pdf', name) is not None)
            file = (root / 'artifacts' / name).resolve(strict=True)
            require(file.parent == root / 'artifacts')
            reader = PdfReader(file)
            require(len(reader.pages) == 1)
            texts.append('\n'.join(page.extract_text() for page in reader.pages))
        require(len(texts) == 2 and texts[0] == texts[1])
        require(all(term in texts[0] for term in ['Aceptación visual HU012', 'Formación QA', 'Experiencia QA', 'Django']))
        return {'equal_text': True, 'pages': 1, 'optional_sections': all(term in texts[0] for term in ['Inglés QA', 'Certificación ficticia QA', 'Proyectos QA'])}
    raise ValueError('QA_ACTION_REJECTED')


if __name__ == '__main__':
    try:
        print(json.dumps(execute(sys.argv[1], sys.argv[2], sys.argv[3:]), ensure_ascii=False))
    except Exception:
        # No emitir valores del entorno, SQL, argumentos ni excepciones con datos.
        print('{"error":"QA_GUARD_OR_CONTRAST_FAILED"}')
        sys.exit(1)
