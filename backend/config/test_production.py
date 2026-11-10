"""Production boot failures and public health responses, without provider calls."""

import json
import os
from pathlib import Path
import subprocess
import sys
from unittest.mock import patch

from django.test import SimpleTestCase, TestCase


class ProductionBootTests(SimpleTestCase):
    def boot(self, **overrides):
        env = os.environ.copy()
        env.update({
            "DJANGO_SETTINGS_MODULE": "config.production",
            "DJANGO_SECRET_KEY": "test-only-private-key-" * 4,
            "WORKNET_PUBLIC_ORIGIN": "https://worknet.example.test",
            "POSTGRES_DB": "worknet_test", "POSTGRES_USER": "qa",
            "POSTGRES_PASSWORD": "test-only-password", "POSTGRES_HOST": "db",
            "POSTGRES_PORT": "5432", "REDIS_URL": "redis://cache:6379/0",
        })
        env.update(overrides)
        return subprocess.run(
            [sys.executable, "-c", "import json;from config import production as p;print(json.dumps({'debug':p.DEBUG,'hosts':p.ALLOWED_HOSTS,'db':p.DATABASES['default']['ENGINE'],'cache':p.CACHES['default']['BACKEND'],'reset':p.PASSWORD_RESET_FRONTEND_URL,'cors':p.CORS_ALLOW_ALL_ORIGINS,'secure':p.SESSION_COOKIE_SECURE}))"],
            cwd=Path(__file__).resolve().parent.parent,
            env=env, text=True, capture_output=True, check=False,
        )

    def test_production_is_explicit_secure_and_uses_shared_dependencies(self):
        result = self.boot()
        self.assertEqual(result.returncode, 0, result.stderr)
        data = json.loads(result.stdout)
        self.assertFalse(data["debug"])
        self.assertFalse(data["cors"])
        self.assertTrue(data["secure"])
        self.assertEqual(data["hosts"], ["worknet.example.test"])
        self.assertEqual(data["db"], "django.db.backends.postgresql")
        self.assertEqual(data["cache"], "django.core.cache.backends.redis.RedisCache")
        self.assertEqual(data["reset"], "https://worknet.example.test/reset-password")

    def test_production_refuses_missing_secret_database_or_cache(self):
        for variable in ("DJANGO_SECRET_KEY", "POSTGRES_PASSWORD", "POSTGRES_HOST", "REDIS_URL"):
            with self.subTest(variable=variable):
                result = self.boot(**{variable: ""})
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(variable, result.stderr)

    def test_production_refuses_development_key_and_unsafe_origins(self):
        cases = [
            {"DJANGO_SECRET_KEY": "django-insecure-" + "x" * 60},
            {"WORKNET_PUBLIC_ORIGIN": "http://worknet.example.test"},
            {"WORKNET_PUBLIC_ORIGIN": "https://worknet.example.test/path"},
            {"WORKNET_PUBLIC_ORIGIN": "https://user:private-value@worknet.example.test"},
            {"WORKNET_PUBLIC_ORIGIN": "https://*"},
            {"WORKNET_PUBLIC_ORIGIN": "https://worknet.example.test:bad"},
            {"WORKNET_PUBLIC_ORIGIN": "https://worknet.example.test:0"},
            {"POSTGRES_PORT": "invalid"},
            {"POSTGRES_PORT": "70000"},
            {"REDIS_URL": "http://cache"},
            {"REDIS_URL": "redis://cache:bad/0"},
        ]
        for case in cases:
            with self.subTest(variable=next(iter(case))):
                result = self.boot(**case)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("private-value", result.stderr)


class HealthTests(TestCase):
    def test_probes_are_anonymous_small_and_not_cached(self):
        for path in ("/health/live/", "/health/ready/"):
            response = self.client.get(path)
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.json(), {"status": "ok"})
            self.assertIn("no-store", response["Cache-Control"])
            self.assertEqual(self.client.post(path).status_code, 405)

    def test_cache_failure_returns_no_exception_or_private_details(self):
        with patch("config.health.cache.set", side_effect=RuntimeError("private-connection-value")):
            response = self.client.get("/health/ready/")
        self.assertEqual(response.status_code, 503)
        self.assertEqual(response.json(), {"status": "unavailable"})
        self.assertNotContains(response, "private-connection-value", status_code=503)

    def test_database_failure_keeps_liveness_available(self):
        with patch("config.health.connection.cursor", side_effect=RuntimeError("private-database-value")):
            self.assertEqual(self.client.get("/health/ready/").status_code, 503)
            self.assertEqual(self.client.get("/health/live/").status_code, 200)
