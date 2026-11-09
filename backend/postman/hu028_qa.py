"""Fresh loopback-only HU028 QA. The optional provider double is explicitly not Gemini."""
import argparse
from copy import deepcopy
from datetime import datetime, timezone
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import hashlib
import json
import os
import platform
from pathlib import Path
import secrets
import socket
import subprocess
import sys
import threading
import time
import uuid
from urllib.error import HTTPError
from urllib.request import Request, urlopen
from wsgiref.simple_server import make_server, WSGIRequestHandler


class Quiet(WSGIRequestHandler):
    def log_message(self, *args):
        pass


class WebHandler(SimpleHTTPRequestHandler):
    qa_run = ""

    def end_headers(self):
        self.send_header("X-WorkNet-QA-Run", self.qa_run)
        super().end_headers()

    def do_GET(self):
        target = Path(self.translate_path(self.path))
        if not target.is_file() and not Path(self.path.split("?", 1)[0]).suffix:
            self.path = "/index.html"
        super().do_GET()

    def log_message(self, *args):
        pass


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--api-port", type=int, default=18488)
    parser.add_argument("--web-port", type=int, default=18489)
    parser.add_argument("--provider-real", action="store_true", help="Explicitly use the configured provider with fictitious QA data; requires authorized private key/model.")
    parser.add_argument("--serve", action="store_true", help="Keep only this newly created QA run available on loopback.")
    parser.add_argument("--prepare-only", action="store_true", help="Prepare a fresh QA without running the HTTP suite, for independent browser/Desktop acceptance.")
    parser.add_argument("--private-env", type=Path, help="Read only Gemini server configuration from a private local dotenv file; never copy it into artifacts or clients.")
    args = parser.parse_args()
    if args.api_port == args.web_port or any(not 1024 <= p <= 65535 for p in [args.api_port, args.web_port]):
        parser.error("Use two distinct unprivileged ports.")
    for port in [args.api_port, args.web_port]:
        with socket.socket() as probe:
            probe.bind(("127.0.0.1", port))
    repo = Path(__file__).resolve().parents[2]
    common = Path(subprocess.check_output(["git", "-C", str(repo), "rev-parse", "--path-format=absolute", "--git-common-dir"], text=True).strip())
    run = common / "hu028-qa" / (datetime.now(timezone.utc).strftime("run-%Y%m%dT%H%M%SZ-") + secrets.token_hex(4))
    run.mkdir(parents=True, exist_ok=False, mode=0o700)
    (run / "mode.json").write_text('{"mode":"unconfigured"}')
    sys.path.insert(0, str(repo / "backend"))
    if args.private_env:
        from dotenv import dotenv_values
        private_values = dotenv_values(args.private_env.resolve(strict=True))
        for name in ["GEMINI_API_KEY", "GEMINI_MODEL"]:
            if private_values.get(name):
                os.environ[name] = private_values[name]
    os.environ["DJANGO_SETTINGS_MODULE"] = "config.settings"
    from django.conf import settings
    real_key = getattr(settings, "GEMINI_API_KEY", "")
    real_model = getattr(settings, "GEMINI_MODEL", "")
    if args.provider_real and (not real_key or not real_model):
        raise RuntimeError("Configure the authorized server key and model privately before provider-real QA.")
    settings.DATABASES = {"default": {"ENGINE": "django.db.backends.sqlite3", "NAME": str(run / "qa.sqlite3")}}
    settings.ALLOWED_HOSTS = ["127.0.0.1", "localhost", "testserver"]
    settings.EMAIL_BACKEND = "django.core.mail.backends.filebased.EmailBackend"
    settings.EMAIL_FILE_PATH = str(run / "mail")
    settings.CORS_ALLOWED_ORIGINS = [f"http://127.0.0.1:{args.web_port}"]
    settings.CURRICULUM_AI_RATE = "1000/hour"
    settings.DEBUG = False
    settings.SECRET_KEY = secrets.token_urlsafe(48)
    settings.GEMINI_API_KEY = ""
    settings.GEMINI_MODEL = ""
    import django
    django.setup()
    from django.core.management import call_command
    from django.core.wsgi import get_wsgi_application
    from accounts.models import User
    from accounts.testing import fixture_token
    from candidate_dashboard.models import CandidateProfile
    from curriculum import assistant
    from curriculum.models import GeneratedCurriculum
    from curriculum.test_assistant import DATA, TEXT, proposal
    call_command("migrate", verbosity=0, interactive=False)
    password = secrets.token_urlsafe(24)
    owner = User.objects.create_user(email="hu028.owner@example.test", full_name="Candidata HU028 QA", password=password, role="candidato", email_verified=True)
    other = User.objects.create_user(email="hu028.other@example.test", full_name="Otra candidata QA", password=password, role="candidato", email_verified=True)
    company = User.objects.create_user(email="hu028.company@example.test", full_name="Empresa QA", password=password, role="empresa", email_verified=True)
    unverified = User.objects.create_user(email="hu028.pending@example.test", full_name="Pendiente QA", password=password, role="candidato", email_verified=False)
    tokens = {label: fixture_token(user).key for label, user in [("owner", owner), ("other", other), ("company", company), ("unverified", unverified)]}
    CandidateProfile.objects.create(candidate=owner, professional_summary="Resumen manual QA", skills=["Python"])
    CandidateProfile.objects.create(candidate=other, professional_summary="PERFIL_AJENO_NO_COMPARTIR")
    seed = {"email": owner.email, "password": password, "tokens": tokens, "api_port": args.api_port, "web_port": args.web_port}
    (run / "private.json").write_text(json.dumps(seed))
    private_environment = {"id": str(uuid.uuid4()), "name": "WorkNet HU028 QA privado " + run.name,
                           "_postman_variable_scope": "environment", "values": [
        {"key": "hu028_api_origin", "value": f"http://127.0.0.1:{args.api_port}", "enabled": True}]}
    for label, key in [("candidate", "owner"), ("other", "other"), ("company", "company"), ("unverified", "unverified")]:
        private_environment["values"].append({"key": "hu028_" + label + "_token", "value": tokens[key], "enabled": True, "type": "secret"})
    (run / "private.postman_environment.json").write_text(json.dumps(private_environment))
    (run / "private.json").chmod(0o600)
    (run / "private.postman_environment.json").chmod(0o600)
    marker = "hu028-isolated-real" if args.provider_real else "hu028-isolated-double"
    (run / "marker.json").write_text(json.dumps({"suite": "hu028", "provider": marker, "database": "qa.sqlite3"}))
    last_source = {}

    def provider_double(source):
        mode = json.loads((run / "mode.json").read_text())["mode"]
        if mode == "unconfigured":
            raise assistant.AssistantFailure(code="assistant_not_configured")
        if mode == "limit":
            raise assistant.AssistantFailure("Cuota de prueba agotada; tu edición se conserva.", status=429, code="provider_limit")
        last_source.clear(); last_source.update(deepcopy(source))
        value = proposal()
        if mode == "invalid":
            value["data"]["experience"][0]["company"] = "Empresa no proporcionada"
        return value, "qa-controlled-double-not-gemini"

    if not args.provider_real:
        assistant.generate = provider_double
    else:
        real_generate = assistant.generate
        provider_calls = []

        def audited_real_generate(source):
            configured = all(assistant.configuration())
            if not configured:
                return real_generate(source)
            started = time.perf_counter()
            record = {"requested_model": real_model, "profile_included": "profile" in source,
                      "source_sha256": hashlib.sha256(json.dumps(source, sort_keys=True, ensure_ascii=False).encode()).hexdigest()}
            try:
                value, model = real_generate(source)
                record["returned_json"] = True
                record["result_sha256"] = hashlib.sha256(json.dumps(value, sort_keys=True, ensure_ascii=False).encode()).hexdigest()
                return value, model
            except assistant.AssistantFailure as error:
                record.update(returned_json=False, http_status=error.status_code, error_code=error.get_codes())
                raise
            finally:
                record["elapsed_ms"] = round((time.perf_counter() - started) * 1000, 2)
                provider_calls.append(record)
                (run / "provider-calls.json").write_text(json.dumps(provider_calls, indent=2), encoding="utf-8")

        assistant.generate = audited_real_generate
    application = get_wsgi_application()

    def guarded_app(environ, start_response):
        mode = json.loads((run / "mode.json").read_text())["mode"]
        settings.GEMINI_API_KEY = (real_key if args.provider_real else "qa-double-not-a-real-key") if mode != "unconfigured" else ""
        settings.GEMINI_MODEL = (real_model if args.provider_real else "gemini-3.5-flash-lite") if mode != "unconfigured" else ""
        def marked(status, headers, exc_info=None):
            return start_response(status, [*headers, ("X-WorkNet-QA", marker), ("X-WorkNet-QA-Run", run.name)], exc_info)
        return application(environ, marked)

    api = make_server("127.0.0.1", args.api_port, guarded_app, handler_class=Quiet)
    thread = threading.Thread(target=api.serve_forever, daemon=True)
    thread.start()
    results = []
    base = f"http://127.0.0.1:{args.api_port}/api/"

    def request(case, path="curriculum/generated/assistant/", *, body=None, token="owner", expected=200):
        headers = {"Content-Type": "application/json"}
        if token: headers["Authorization"] = "Token " + tokens[token]
        req = Request(base + path, data=json.dumps(body).encode() if body is not None else None, headers=headers)
        try:
            with urlopen(req, timeout=20) as response: status, raw, hdr = response.status, response.read(), response.headers
        except HTTPError as error:
            status, raw, hdr = error.code, error.read(), error.headers
        assert hdr["X-WorkNet-QA"] == marker
        assert status == expected, (case, status, expected)
        results.append({"case": case, "expected_http": expected, "obtained_http": status, "passed": True})
        return json.loads(raw) if not raw.startswith(b"%PDF-") else raw

    # Keep every new run independent; never overwrite the published historical evidence.
    results_path = run / "artifacts"
    results_path.mkdir(parents=True, exist_ok=True)
    try:
        if args.prepare_only:
            pass
        elif args.provider_real:
            (run / "mode.json").write_text('{"mode":"real"}')
            available = request("R01 configuración de proveedor real")
            assert available["available"]
            suggestion = request("R02 propuesta con proveedor real", body={"text": TEXT, "consent": True})
            assert suggestion["saved"] is False and GeneratedCurriculum.objects.count() == 0
            assert suggestion["provider"] == "Gemini" and suggestion["model"] == real_model
            for template in ["clasica", "moderna", "minimalista"]:
                body = {"template": template, "data": suggestion["suggestion"]["data"]}
                req = Request(base + "curriculum/generated/", data=json.dumps(body).encode(), method="PUT",
                              headers={"Content-Type": "application/json", "Authorization": "Token " + tokens["owner"]})
                with urlopen(req) as response:
                    assert response.status in (200, 201)
                    results.append({"case": "R03 guardado " + template, "expected_http": "200/201", "obtained_http": response.status, "passed": True})
                document = request("R04 PDF " + template, "curriculum/generated/pdf/")
                assert document.startswith(b"%PDF-")
                (results_path / ("HU028-PDF-" + template + "-proveedor-real.pdf")).write_bytes(document)
        else:
            available = request("A01 estado sin configuración")
            assert not available["available"]
            request("A02 sin sesión", token=None, expected=401)
            request("A03 empresa", token="company", expected=403)
            request("A04 candidato sin verificar", token="unverified", expected=403)
            request("A05 sin consentimiento", body={"text": TEXT, "consent": False}, expected=400)
            request("A06 datos vacíos", body={"text": "", "consent": True}, expected=400)
            request("A07 propietario no aceptado", body={"text": TEXT, "consent": True, "candidate": other.pk}, expected=400)
            request("A08 proveedor no configurado", body={"text": TEXT, "consent": True}, expected=503)
            (run / "mode.json").write_text('{"mode":"double"}')
            suggestion = request("A09 propuesta con doble controlado", body={"text": TEXT, "consent": True})
            assert suggestion["saved"] is False and GeneratedCurriculum.objects.count() == 0
            request("A10 perfil propio optativo", body={"text": TEXT, "consent": True, "include_profile": True})
            assert last_source["profile"]["personal"]["email"] == owner.email
            assert "PERFIL_AJENO_NO_COMPARTIR" not in json.dumps(last_source)
            (run / "mode.json").write_text('{"mode":"invalid"}')
            request("A11 dato factual no proporcionado", body={"text": TEXT, "consent": True}, expected=502)
            (run / "mode.json").write_text('{"mode":"limit"}')
            request("A12 cuota", body={"text": TEXT, "consent": True}, expected=429)
            (run / "mode.json").write_text('{"mode":"double"}')
            for template in ["clasica", "moderna", "minimalista"]:
                body = {"template": template, "data": suggestion["suggestion"]["data"]}
                req = Request(base + "curriculum/generated/", data=json.dumps(body).encode(), method="PUT",
                              headers={"Content-Type": "application/json", "Authorization": "Token " + tokens["owner"]})
                with urlopen(req) as response:
                    assert response.status in (200, 201)
                results.append({"case": "A13 guardado " + template, "expected_http": "200/201", "obtained_http": response.status, "passed": True})
                document = request("A13 PDF " + template, "curriculum/generated/pdf/")
                (results_path / ("HU028-PDF-" + template + "-doble-controlado.pdf")).write_bytes(document)
                assert document.startswith(b"%PDF-")
            request("A14 otro candidato no lee PDF", "curriculum/generated/pdf/", token="other", expected=404)
        report = {"date_utc": datetime.now(timezone.utc).isoformat(), "run": run.name,
                  "platform": platform.system() + " / SQLite / loopback", "python": platform.python_version(), "django": django.get_version(),
                  "source_sha": subprocess.check_output(["git", "-C", str(repo), "rev-parse", "HEAD"], text=True).strip(),
                  "provider_real_tested": args.provider_real and not args.prepare_only, "provider_double": None if args.provider_real else "controlled test fixture; not Gemini",
                  "requests_checked": len(results), "cases": results,
                  "pending": ["Postman Desktop evidence"] if args.provider_real else ["authorized provider key and model", "real provider acceptance", "Postman Desktop evidence"]}
        report_name = "preparacion.json" if args.prepare_only else ("http-proveedor-real.json" if args.provider_real else "http-resultados.json")
        (results_path / report_name).write_text(json.dumps(report, ensure_ascii=False, indent=2)+"\n")
        (run / "mode.json").write_text(json.dumps({"mode": "real" if args.provider_real else "unconfigured"}))
        print(json.dumps({"run": str(run), "requests_checked": len(results), "provider_real_tested": args.provider_real and not args.prepare_only}), flush=True)
        if args.serve:
            webroot = repo / "frontend/build/web"
            if not (webroot / "index.html").is_file():
                raise RuntimeError("Build the web application first.")
            WebHandler.qa_run = run.name
            web = ThreadingHTTPServer(("127.0.0.1", args.web_port), partial(WebHandler, directory=str(webroot)))
            try:
                web.serve_forever()
            finally:
                web.server_close()
    finally:
        api.shutdown(); api.server_close()


if __name__ == "__main__":
    main()
