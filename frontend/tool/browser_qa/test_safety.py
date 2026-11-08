"""Pruebas del guard antes de abrir el navegador o tocar SQLite."""
import json
from pathlib import Path
import secrets
import tempfile
import unittest
from bridge import load, execute


class GuardTest(unittest.TestCase):
    def test_hu01920_cannot_prepare_before_start(self):
        self.config['suite'] = 'hu019-hu020'
        self.write()
        with self.assertRaises(ValueError):
            execute(self.manifest, 'hu01920_prepare', [])

    def test_hu01920_actor_rejects_different_suite(self):
        (self.root / '.suite-started').touch()
        with self.assertRaises(ValueError):
            execute(self.manifest, 'hu01920_review', [])

    def test_hu018_fixtures_cannot_run_before_start_guard(self):
        self.config['suite'] = 'hu018'
        self.write()
        with self.assertRaises(ValueError):
            execute(self.manifest, 'hu018_prepare', [])

    def test_hu018_actions_reject_a_different_suite(self):
        (self.root / '.suite-started').touch()
        with self.assertRaises(ValueError):
            execute(self.manifest, 'hu018_snapshot', [])

    def test_hu017_fixtures_cannot_run_before_start_guard(self):
        self.config['suite'] = 'hu017'
        self.write()
        with self.assertRaises(ValueError):
            execute(self.manifest, 'hu017_prepare', [])

    def test_hu017_actions_reject_a_different_suite(self):
        (self.root / '.suite-started').touch()
        with self.assertRaises(ValueError):
            execute(self.manifest, 'hu017_snapshot', [])

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name).resolve() / 'worknet-browser-qa/browser-qa-test'
        self.run = self.root / 'source/backend/postman/.local/run-test'
        self.run.mkdir(parents=True)
        for name in ['qa.sqlite3', 'initial.sqlite3']:
            (self.run / name).touch()
        self.state = dict(qa_marker='WORKNET_POSTMAN_AISLADO', database=str(self.run / 'qa.sqlite3'), port=8025)
        self.values = dict(qa_confirmation='SOLO_BASE_AISLADA', qa_run_id='run-test', qa_password=secrets.token_urlsafe(24), base_url='http://127.0.0.1:8025/api', **{key + '_email': key + '.postman@worknet.test' for key in ['candidate', 'other', 'company', 'draft']})
        self.config = dict(schema='worknet-browser-qa-v1', frontend_sha='a' * 40, backend_sha='b' * 40, nonce='c' * 48, api_origin='http://127.0.0.1:8025', web_origin='http://127.0.0.1:55032', environment='source/backend/postman/.local/run-test/local.postman_environment.json')
        self.manifest = self.root / 'manifest.private.json'
        self.write()

    def write(self):
        self.manifest.write_text(json.dumps(self.config), encoding='utf-8')
        (self.run / 'state.json').write_text(json.dumps(self.state), encoding='utf-8')
        (self.run / 'local.postman_environment.json').write_text(json.dumps({'values': [dict(key=k, value=v) for k, v in self.values.items()]}), encoding='utf-8')

    def rejected(self):
        self.write()
        with self.assertRaises((ValueError, FileNotFoundError)):
            load(self.manifest)

    def test_valid_private_fixture(self):
        self.assertEqual(load(self.manifest)[1], self.run)

    def test_foreign_database(self):
        self.state['database'] = str(self.root / 'db.sqlite3')
        (self.root / 'db.sqlite3').touch()
        self.rejected()

    def test_missing_marker(self):
        self.state['qa_marker'] = 'production'
        self.rejected()

    def test_non_loopback_origin(self):
        self.config['api_origin'] = 'https://example.com'
        self.rejected()

    def test_different_private_environment_url(self):
        self.values['base_url'] = 'http://127.0.0.1:8000/api'
        self.rejected()

    def test_personal_account(self):
        self.values['candidate_email'] = 'personal@example.com'
        self.rejected()

    def test_environment_outside_run(self):
        self.config['environment'] = '../local.postman_environment.json'
        self.rejected()

    def test_revoke_before_start_is_rejected(self):
        with self.assertRaises(ValueError):
            execute(self.manifest, 'revoke_candidate', [])

    def test_hu014_fixtures_cannot_run_before_start_guard(self):
        self.config['suite'] = 'hu014'
        self.write()
        with self.assertRaises(ValueError):
            execute(self.manifest, 'hu014_prepare', [])

    def test_hu014_actions_reject_a_different_suite(self):
        (self.root / '.suite-started').touch()
        with self.assertRaises(ValueError):
            execute(self.manifest, 'hu014_snapshot', [])

    def test_hu015_fixtures_cannot_run_before_start_guard(self):
        self.config['suite'] = 'hu015'
        self.write()
        with self.assertRaises(ValueError):
            execute(self.manifest, 'hu015_prepare', [])

    def test_hu015_actions_reject_a_different_suite(self):
        (self.root / '.suite-started').touch()
        with self.assertRaises(ValueError):
            execute(self.manifest, 'hu015_snapshot', [])


if __name__ == '__main__':
    unittest.main()
