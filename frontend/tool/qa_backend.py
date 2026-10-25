"""Backend local para QA Flutter; nunca utiliza la base habitual ni SMTP real."""
import argparse
import json
import os
from pathlib import Path
import secrets
import sys
import tempfile
from urllib.parse import urlparse

root = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--port", type=int, default=8002)
parser.add_argument("--frontend-origin", default="http://localhost:55001")
args = parser.parse_args()
if urlparse(args.frontend_origin).hostname not in {"localhost", "127.0.0.1"}:
    parser.error("La prueba aislada solo admite un frontend local.")

sys.path.insert(0, str(root / "backend"))
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")
from django.conf import settings

qa_root = root / "frontend" / ".dart_tool" / "worknet_qa"
qa_root.mkdir(parents=True, exist_ok=True)
run_path = Path(tempfile.mkdtemp(prefix="run-", dir=qa_root))
settings.DATABASES["default"]["NAME"] = str(run_path / "qa.sqlite3")
settings.MAILERS = {"default": {
    "BACKEND": "django.core.mail.backends.filebased.EmailBackend",
    "OPTIONS": {"file_path": str(run_path / "mail")},
}}
settings.DEFAULT_FROM_EMAIL = "qa@worknet.invalid"
settings.PASSWORD_RESET_FRONTEND_URL = args.frontend_origin.rstrip("/") + "/reset-password"
settings.ALLOWED_HOSTS = ["localhost", "127.0.0.1"]

import django
django.setup()
from django.core.management import call_command
from django.utils import timezone
from accounts.models import User
from accounts.models import CompanyProfile
from candidate_dashboard.models import Application, CandidateProfile, JobOffer, Notification, SavedOffer

call_command("migrate", verbosity=0)
password = secrets.token_urlsafe(24)
candidate = User.objects.create_user(email="candidato.qa@worknet.test", full_name="Candidato QA — base aislada",
    password=password, role="candidato", email_verified=True)
User.objects.create_user(email="vacio.qa@worknet.test", full_name="Candidato sin actividad QA",
    password=password, role="candidato", email_verified=True)
User.objects.create_user(email="perfil.qa@worknet.test", full_name="Perfil ficticio QA",
    password=password, role="candidato", email_verified=True)
User.objects.create_user(email="eliminar.qa@worknet.test", full_name="Cuenta desechable QA",
    password=password, role="candidato", email_verified=True)
company = User.objects.create_user(email="empresa.qa@worknet.test", full_name="Empresa QA — base aislada",
    password=password, role="empresa", email_verified=True)
User.objects.create_user(email="admin.qa@worknet.test", full_name="Administrador QA",
    password=password, email_verified=True, is_staff=True)
User.objects.create_user(email="nueva.empresa.qa@worknet.test", full_name="Nueva empresa ficticia QA",
    password=password, role="empresa", email_verified=True)
CompanyProfile.objects.create(company=company, legal_name="Empresa ficticia QA", tax_id="900000001-1",
    sector="Tecnología QA", location="Pasto", contact_email="contacto@worknet.test",
    description="Datos ficticios de la empresa aprobada de QA.", state="approved", submitted_at=timezone.now())
CandidateProfile.objects.create(candidate=candidate, professional_summary="Resumen de QA",
    education=[{"title": "Formación QA"}], experience=[{"title": "Experiencia QA"}], skills=["Flutter"])
for index, title in enumerate(["QA · Desarrollador Flutter", "QA · Analista de datos"]):
    offer = JobOffer.objects.create(company=company, title=title, company_name="Empresa QA — base aislada",
        location="Pasto", contract_type="Indefinido", status="published", published_at=timezone.now())
    Application.objects.create(candidate=candidate, offer=offer)
    if index == 0:
        SavedOffer.objects.create(candidate=candidate, offer=offer)
for index in range(2):
    Notification.objects.create(recipient=candidate, title=f"Notificación QA {index + 1}")

# Solo archivo local ignorado por Git; no imprimir ni publicar credenciales.
state = {"database": str(run_path / "qa.sqlite3"), "mail": str(run_path / "mail"),
         "password": password, "candidate": candidate.email, "profile_candidate": "perfil.qa@worknet.test", "frontend": args.frontend_origin,
         "expected": {"percentage": 83, "applications": 2, "saved": 1, "notifications": 2, "jobs": 2}}
(qa_root / "latest.json").write_text(json.dumps(state), encoding="utf-8")
print(f"QA aislada en http://127.0.0.1:{args.port}; correos a archivos locales, sin SMTP.")
print("Credenciales y rutas privadas disponibles solo en frontend/.dart_tool/worknet_qa/latest.json")
# Do not log signed verification/recovery query parameters during browser QA.
from django.core.servers.basehttp import WSGIRequestHandler
WSGIRequestHandler.log_message = lambda *args, **kwargs: None
call_command("runserver", f"127.0.0.1:{args.port}", use_reloader=False)
