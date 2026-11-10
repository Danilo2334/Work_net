"""Production settings selected explicitly with DJANGO_SETTINGS_MODULE."""

import os
import re
from urllib.parse import urlsplit

from django.core.exceptions import ImproperlyConfigured

from .settings import *  # noqa: F403


def required(name):
    value = os.environ.get(name, "").strip()
    if not value:
        raise ImproperlyConfigured(f"Required production variable: {name}")
    return value


def positive_integer(name, default):
    try:
        value = int(os.environ.get(name, str(default)))
    except ValueError:
        raise ImproperlyConfigured(f"{name} must be a positive integer") from None
    if value < 1:
        raise ImproperlyConfigured(f"{name} must be a positive integer")
    return value


DEBUG = False
SECRET_KEY = required("DJANGO_SECRET_KEY")
if len(SECRET_KEY) < 50 or SECRET_KEY.startswith("django-insecure-"):
    raise ImproperlyConfigured("DJANGO_SECRET_KEY must be a new private key of at least 50 characters")

PUBLIC_ORIGIN = required("WORKNET_PUBLIC_ORIGIN").rstrip("/")
try:
    origin = urlsplit(PUBLIC_ORIGIN)
    public_port = origin.port
except ValueError:
    raise ImproperlyConfigured("WORKNET_PUBLIC_ORIGIN must be a valid HTTPS origin") from None
if (
    origin.scheme != "https"
    or not origin.hostname
    or origin.username
    or origin.password
    or origin.path
    or origin.query
    or origin.fragment
    or public_port == 0
    or len(origin.hostname or "") > 253
    or not re.fullmatch(r"[A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?", origin.hostname or "")
):
    raise ImproperlyConfigured("WORKNET_PUBLIC_ORIGIN must be one HTTPS origin without a path")
ALLOWED_HOSTS = [origin.hostname]
CSRF_TRUSTED_ORIGINS = [PUBLIC_ORIGIN]
CORS_ALLOW_ALL_ORIGINS = False
CORS_ALLOWED_ORIGINS = [PUBLIC_ORIGIN]
CORS_EXPOSE_HEADERS = ["Content-Disposition"]
PASSWORD_RESET_FRONTEND_URL = f"{PUBLIC_ORIGIN}/reset-password"

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": required("POSTGRES_DB"),
        "USER": required("POSTGRES_USER"),
        "PASSWORD": required("POSTGRES_PASSWORD"),
        "HOST": required("POSTGRES_HOST"),
        "PORT": positive_integer("POSTGRES_PORT", 5432),
        "CONN_MAX_AGE": 60,
        "CONN_HEALTH_CHECKS": True,
        "OPTIONS": {"connect_timeout": 5},
    }
}
if DATABASES["default"]["PORT"] > 65535:
    raise ImproperlyConfigured("POSTGRES_PORT must be between 1 and 65535")
redis_url = required("REDIS_URL")
try:
    redis_origin = urlsplit(redis_url)
    redis_port = redis_origin.port
except ValueError:
    raise ImproperlyConfigured("REDIS_URL must identify a valid Redis service") from None
if redis_origin.scheme not in ("redis", "rediss") or not redis_origin.hostname or redis_port == 0:
    raise ImproperlyConfigured("REDIS_URL must identify a Redis service")
CACHES = {
    "default": {
        "BACKEND": "django.core.cache.backends.redis.RedisCache",
        "LOCATION": redis_url,
        "KEY_PREFIX": "worknet",
        "OPTIONS": {"socket_connect_timeout": 2, "socket_timeout": 2},
    }
}

# Only the private Caddy proxy reaches this port. Caddy replaces these headers.
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
SECURE_SSL_REDIRECT = True
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SESSION_COOKIE_HTTPONLY = True
SECURE_CONTENT_TYPE_NOSNIFF = True
SECURE_HSTS_SECONDS = 31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True
SECURE_REFERRER_POLICY = "same-origin"
X_FRAME_OPTIONS = "DENY"

STATIC_URL = "/static/"
STATIC_ROOT = BASE_DIR / "staticfiles"  # noqa: F405
MIDDLEWARE = list(MIDDLEWARE)  # noqa: F405
MIDDLEWARE.insert(1, "whitenoise.middleware.WhiteNoiseMiddleware")
STORAGES = {
    "default": {"BACKEND": "django.core.files.storage.FileSystemStorage"},
    "staticfiles": {"BACKEND": "whitenoise.storage.CompressedManifestStaticFilesStorage"},
}

# Provider credentials remain in the backend's private environment.
MAILERS = {
    "default": {
        "BACKEND": "django.core.mail.backends.smtp.EmailBackend",
        "OPTIONS": {
            "host": "smtp.gmail.com",
            "port": 587,
            "username": os.environ.get("GMAIL_USER", ""),
            "password": os.environ.get("GMAIL_APP_PASSWORD", ""),
            "use_tls": True,
            "timeout": 15,
        },
    }
}
DEFAULT_FROM_EMAIL = os.environ.get("GMAIL_USER", "")
LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "handlers": {"console": {"class": "logging.StreamHandler"}},
    "root": {"handlers": ["console"], "level": "WARNING"},
    "loggers": {
        "django.security.DisallowedHost": {"handlers": ["console"], "level": "CRITICAL", "propagate": False},
    },
}
