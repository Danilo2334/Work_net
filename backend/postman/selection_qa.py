"""Estados locales para los 15 casos adicionales de HU008 en Postman Desktop."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import sqlite3

import qa


STAGES = dict(zip(
    ("prepare", "unverified", "rejected", "removed", "missing", "restore"),
    "ABCDEF",
))


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def write_new(path, value):
    with path.open("x", encoding="utf-8") as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2, default=str)
        stream.write("\n")


def fingerprint(connection):
    """Solo guarda recuentos y huellas; nunca exporta filas o credenciales."""
    def value(item):
        return {"bytes_sha256": hashlib.sha256(item).hexdigest()} if isinstance(item, bytes) else item

    result = {}
    with connection.cursor() as cursor:
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
        for table, in cursor.fetchall():
            cursor.execute('SELECT * FROM "' + table.replace('"', '""') + '" ORDER BY rowid')
            rows = [[value(item) for item in row] for row in cursor.fetchall()]
            encoded = json.dumps(rows, ensure_ascii=False, sort_keys=True, default=str).encode()
            result[table] = {"rows": len(rows), "sha256": hashlib.sha256(encoded).hexdigest()}
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=(*STAGES, "before", "after"))
    parser.add_argument("stage", nargs="?", choices=tuple("ABCDEF"))
    parser.add_argument("--run", required=True, help="Nombre run-* generado por qa.py prepare.")
    parser.add_argument("--application-id", type=int, help="ID obtenido en PM213; obligatorio en prepare.")
    args = parser.parse_args()
    if (args.action in ("before", "after")) != (args.stage is not None):
        parser.error("Solo before/after requieren una etapa A-F.")
    if args.action == "prepare" and not args.application_id:
        parser.error("Indica --application-id con el ID real obtenido en PM213.")

    path, state = qa.load_run(args.run)
    database = path / "qa.sqlite3"
    environment = read(path / "local.postman_environment.json")
    variables = {item["key"]: item["value"] for item in environment["values"]}
    if (state.get("qa_marker") != "WORKNET_POSTMAN_AISLADO"
            or Path(state["database"]).resolve() != database.resolve()
            or variables.get("qa_confirmation") != "SOLO_BASE_AISLADA"
            or variables.get("qa_run_id") != path.name
            or variables.get("base_url") != f'http://127.0.0.1:{state["port"]}/api'
            or not database.is_file()):
        raise ValueError("La base y el entorno no corresponden al mismo run aislado.")
    for key in ("company_email", "candidate_email", "draft_email", "disposable_email"):
        if not variables.get(key, "").endswith(".postman@worknet.test"):
            raise ValueError("Solo se admiten cuentas ficticias del entorno local de Postman.")

    qa.configure(path, state)
    from django.core import serializers
    from django.core.files.uploadedfile import SimpleUploadedFile
    from django.db import connection, transaction
    from accounts.models import CompanyProfile, User
    from candidate_dashboard.models import Application, CandidateProfile
    from candidate_dashboard.profile import validated_photo

    if Path(connection.settings_dict["NAME"]).resolve() != database.resolve():
        raise ValueError("Django no selecciono la base aislada indicada.")
    company = User.objects.get(email=variables["company_email"], role="empresa", is_staff=False)
    candidate = User.objects.get(email=variables["candidate_email"], role="candidato", is_staff=False)
    folder = path / "selection"
    context_file = folder / "context.json"

    if args.action == "prepare":
        if folder.exists():
            raise ValueError("Esta preparacion ya existe; conserva el run y prepara una base nueva.")
        profile = CandidateProfile.objects.get(candidate=candidate)
        application = Application.objects.get(
            pk=args.application_id, candidate=candidate, offer__company=company,
        )
        ready = (company.email_verified and candidate.email_verified
                 and CompanyProfile.objects.filter(company=company, state="approved").exists()
                 and CompanyProfile.objects.filter(company__email=variables["draft_email"], state="approved").exists()
                 and candidate.full_name == "Candidato actualizado Postman"
                 and profile.professional_summary == "Resumen ficticio QA"
                 and not profile.photo_data
                 and not User.objects.filter(email=variables["disposable_email"]).exists()
                 and Application.objects.filter(candidate=candidate, offer__company=company).exclude(pk=application.pk).exists())
        if not ready:
            raise ValueError("Falta el estado final de las fases 01-12; no se prepararon cambios.")
        folder.mkdir()
        with sqlite3.connect(database) as source, sqlite3.connect(folder / "before-additional.sqlite3") as backup:
            source.backup(backup)
        with transaction.atomic():
            for section in ("education", "experience", "skills", "languages"):
                for record in getattr(profile, section):
                    if isinstance(record, dict):
                        record["internal_note"] = "Dato historico ficticio reservado al candidato"
            photo = qa.HERE / "fixtures" / "foto-qa.png"
            profile.photo_data = validated_photo(SimpleUploadedFile(
                "foto-qa.png", photo.read_bytes(), content_type="image/png",
            ))
            profile.save()
        context = {
            "run": path.name, "company": company.pk, "candidate": candidate.pk,
            "application_id": application.pk, "stage": "A",
            "application": serializers.serialize("json", [application]),
            "profile": serializers.serialize("json", [profile]),
        }
        write_new(context_file, context)
    else:
        context = read(context_file)
        if (context["run"], context["company"], context["candidate"]) != (path.name, company.pk, candidate.pk):
            raise ValueError("La preparacion pertenece a otro run o a otras cuentas.")
        if args.action in ("before", "after"):
            if args.stage != context["stage"]:
                raise ValueError("Prepara primero el estado correspondiente a esta carpeta.")
            before_file = folder / f"before-{args.stage}.json"
            if args.action == "before":
                write_new(before_file, fingerprint(connection))
            else:
                before, after = read(before_file), fingerprint(connection)
                changed = sorted(table for table in before.keys() | after.keys() if before.get(table) != after.get(table))
                write_new(folder / f"after-{args.stage}.json", {
                    "time_utc": datetime.now(timezone.utc).isoformat(),
                    "database_unchanged": not changed, "changed_tables": changed,
                    "candidate_profile_count": CandidateProfile.objects.filter(candidate=candidate).count(),
                })
                if changed:
                    raise ValueError("La lectura cambio datos: conserva el resultado y revisa el caso.")
            print(f"Auditoria {args.action} {args.stage} guardada sin mostrar datos privados.")
            return

        stages = list(STAGES.values())
        target = STAGES[args.action]
        if stages.index(target) != stages.index(context["stage"]) + 1:
            raise ValueError("Sigue el orden A-F; no se modifico la base.")
        with transaction.atomic():
            if args.action == "unverified":
                User.objects.filter(pk=company.pk).update(email_verified=False)
            elif args.action == "rejected":
                User.objects.filter(pk=company.pk).update(email_verified=True)
                CompanyProfile.objects.filter(company=company).update(state="rejected")
            elif args.action == "removed":
                CompanyProfile.objects.filter(company=company).update(state="approved")
                Application.objects.get(pk=context["application_id"], offer__company=company).delete()
                if not Application.objects.filter(candidate=candidate, offer__company=company).exists():
                    raise ValueError("Debe permanecer otra postulacion para comprobar el permiso por ID.")
            elif args.action == "missing":
                for obj in serializers.deserialize("json", context["application"]):
                    obj.save()
                CandidateProfile.objects.filter(candidate=candidate).delete()
            elif args.action == "restore":
                for obj in serializers.deserialize("json", context["profile"]):
                    obj.save()
        context["stage"] = target
        qa.write(context_file, context)
    print(f'Estado {context["stage"]} preparado; postulación {context["application_id"]}. Solo datos QA locales.')


if __name__ == "__main__":
    main()
