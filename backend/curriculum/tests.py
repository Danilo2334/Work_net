from copy import deepcopy
from io import BytesIO

from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings
from pypdf import PdfReader, PdfWriter
from rest_framework.authtoken.models import Token
from rest_framework.test import APIClient

from accounts.models import User
from candidate_dashboard.models import CandidateProfile
from .models import GeneratedCurriculum, UploadedCurriculum
from .uploads import MAX_UPLOAD_BYTES


BASE = "/api/curriculum/"
DATA = {
    "personal": {"full_name": "María Núñez", "email": "maria@example.test", "phone": "+57 300 000 0000", "location": "Pasto"},
    "professional_summary": "Desarrolladora con experiencia en aplicaciones para educación.",
    "education": [{"qualification": "Ingeniería de Sistemas", "institution": "Universidad QA", "start_date": "2019-01-01", "end_date": "2024-01-01"}],
    "experience": [{"position": "Desarrolladora", "company": "Equipo QA", "start_date": "2024-03-01", "description": "Desarrollo y pruebas de aplicaciones."}],
    "skills": [{"name": "Python", "level": "avanzado"}],
    "languages": [{"name": "Español", "level": "nativo"}],
    "certifications": [{"title": "Pruebas de software", "issuer": "Instituto QA", "issue_date": "2025-01-01"}],
    "extra_sections": [{"title": "Voluntariado", "content": "Talleres de programación para estudiantes."}],
}


def pdf_bytes(label="QA", *, encrypted=False, javascript=False, attachment=False, pages=1):
    writer = PdfWriter()
    for _ in range(pages):
        writer.add_blank_page(width=595, height=842)
    writer.add_metadata({"/Title": label})
    if encrypted:
        writer.encrypt("clave-qa")
    if javascript:
        writer.add_js("app.alert('qa');")
    if attachment:
        writer.add_attachment("adjunto.txt", b"QA")
    output = BytesIO()
    writer.write(output)
    return output.getvalue()


def upload(raw=None, name="curriculum.pdf", mime="application/pdf"):
    return SimpleUploadedFile(name, pdf_bytes() if raw is None else raw, content_type=mime)


@override_settings(PASSWORD_HASHERS=["django.contrib.auth.hashers.MD5PasswordHasher"])
class CurriculumTests(TestCase):
    def setUp(self):
        self.owner = User.objects.create_user(email="cv.qa@example.test", full_name="Nombre de cuenta", role="candidato", email_verified=True)
        self.other = User.objects.create_user(email="otro.cv@example.test", full_name="Otro candidato", role="candidato", email_verified=True)
        self.client = APIClient()
        self.authenticate(self.owner)

    def authenticate(self, user):
        token, _ = Token.objects.get_or_create(user=user)
        self.client.credentials(HTTP_AUTHORIZATION="Token " + token.key)

    def save_generated(self, template="clasica", data=None):
        return self.client.put(BASE + "generated/", {"template": template, "data": deepcopy(DATA) if data is None else data}, format="json")

    def assert_pdf(self, response, *, text=None):
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response["Content-Type"], "application/pdf")
        self.assertIn("private", response["Cache-Control"])
        self.assertIn("no-store", response["Cache-Control"])
        self.assertIn("Authorization", response["Vary"])
        self.assertEqual(response["X-Content-Type-Options"], "nosniff")
        reader = PdfReader(BytesIO(response.content), strict=True)
        self.assertGreater(len(reader.pages), 0)
        if text:
            self.assertIn(text, "\n".join(page.extract_text() for page in reader.pages))
        return reader

    def test_empty_reads_do_not_create_records(self):
        result = self.client.get(BASE)
        self.assertEqual(result.data["options"], [])
        self.assertEqual(result.data["limits"]["max_upload_bytes"], MAX_UPLOAD_BYTES)
        result = self.client.get(BASE + "generated/")
        self.assertFalse(result.data["exists"])
        self.assertEqual(result.data["curriculum"]["data"]["personal"]["full_name"], self.owner.full_name)
        self.assertFalse(GeneratedCurriculum.objects.exists())
        self.assertFalse(UploadedCurriculum.objects.exists())

    def test_upload_read_replace_and_delete_pdf(self):
        first = pdf_bytes("Primera versión")
        second = pdf_bytes("Segunda versión")
        result = self.client.put(BASE + "uploaded/", {"file": upload(first)}, format="multipart")
        self.assertEqual(result.status_code, 201)
        self.assertEqual(result.data["uploaded"]["size_bytes"], len(first))
        self.assertEqual(self.client.get(BASE + "uploaded/").content, first)
        result = self.client.put(BASE + "uploaded/", {"file": upload(second, "nueva-version.pdf")}, format="multipart")
        self.assertEqual(result.status_code, 200)
        self.assertEqual(UploadedCurriculum.objects.count(), 1)
        response = self.client.get(BASE + "uploaded/")
        self.assert_pdf(response)
        self.assertEqual(response.content, second)
        self.assertIn("inline", response["Content-Disposition"])
        self.assertIn("nueva-version.pdf", response["Content-Disposition"])
        self.assertEqual(self.client.delete(BASE + "uploaded/").status_code, 200)
        self.assertEqual(self.client.get(BASE + "uploaded/").status_code, 404)

    def test_invalid_files_preserve_previous_curriculum(self):
        original = pdf_bytes("Conservar")
        self.client.put(BASE + "uploaded/", {"file": upload(original)}, format="multipart")
        for invalid in (
            upload(name="imagen.png", mime="image/png"),
            upload(mime="application/octet-stream"),
            upload(b"No es PDF"),
            upload(b"%PDF-1.4\ncontenido roto\n%%EOF"),
            upload(pdf_bytes(encrypted=True)),
            upload(pdf_bytes(javascript=True)),
            upload(pdf_bytes(attachment=True)),
            upload(pdf_bytes(pages=51)),
            upload(b"x" * (MAX_UPLOAD_BYTES + 1)),
        ):
            with self.subTest(filename=invalid.name, size=invalid.size):
                result = self.client.put(BASE + "uploaded/", {"file": invalid}, format="multipart")
                self.assertEqual(result.status_code, 400)
                self.assertIn("file", result.data["errors"])
                self.assertEqual(self.client.get(BASE + "uploaded/").content, original)

    def test_accepts_exact_size_limit(self):
        overhead = len(pdf_bytes(""))
        raw = pdf_bytes("x" * (MAX_UPLOAD_BYTES - overhead))
        # La tabla xref puede crecer al añadir un dígito al desplazamiento.
        raw = pdf_bytes("x" * (MAX_UPLOAD_BYTES - overhead - (len(raw) - MAX_UPLOAD_BYTES)))
        self.assertEqual(len(raw), MAX_UPLOAD_BYTES)
        self.assertEqual(self.client.put(BASE + "uploaded/", {"file": upload(raw)}, format="multipart").status_code, 201)

    def test_only_one_file_and_no_owner_override_allowed(self):
        for body in ({}, {"file": "texto"}, {"file": [upload(), upload()]}, {"file": upload(), "candidate": self.other.pk}):
            self.assertEqual(self.client.put(BASE + "uploaded/", body, format="multipart").status_code, 400)
        self.assertFalse(UploadedCurriculum.objects.exists())

    def test_filename_is_safe_and_other_candidate_cannot_read_replace_or_delete_owner_pdf(self):
        self.client.put(BASE + "uploaded/", {"file": upload(name="carpeta\\nombre con espacios.pdf")}, format="multipart")
        saved = UploadedCurriculum.objects.get(candidate=self.owner)
        self.assertEqual(saved.filename, "nombre_con_espacios.pdf")
        self.authenticate(self.other)
        self.assertEqual(self.client.get(BASE + f"uploaded/?candidate={self.owner.pk}").status_code, 404)
        self.client.delete(BASE + f"uploaded/?candidate={self.owner.pk}")
        self.client.put(BASE + f"uploaded/?candidate={self.owner.pk}", {"file": upload(name="otro.pdf")}, format="multipart")
        saved.refresh_from_db()
        self.assertEqual(saved.filename, "nombre_con_espacios.pdf")
        self.assertEqual(UploadedCurriculum.objects.count(), 2)

    def test_preload_profile_sections_without_ids_and_without_mutating_profile(self):
        profile = CandidateProfile.objects.create(candidate=self.owner, professional_summary="Resumen guardado", education=[{"title": "Ingeniería", "institution": "Instituto", "custom_note": "Privado"}], skills=["Python"])
        result = self.client.get(BASE + "generated/")
        data = result.data["curriculum"]["data"]
        self.assertEqual(data["professional_summary"], "Resumen guardado")
        self.assertEqual(data["education"], [{"qualification": "Ingeniería", "institution": "Instituto"}])
        self.assertEqual(data["skills"], [{"name": "Python"}])
        self.assertEqual(data["certifications"], [])
        profile.refresh_from_db()
        self.assertEqual(profile.education[0]["title"], "Ingeniería")
        self.assertFalse(GeneratedCurriculum.objects.exists())

    def test_save_edit_reload_and_template_change_preserve_data(self):
        self.assertEqual(self.save_generated().status_code, 201)
        original = self.client.get(BASE + "generated/").data["curriculum"]["data"]
        for template in ("moderna", "minimalista", "clasica"):
            result = self.client.patch(BASE + "generated/", {"template": template}, format="json")
            self.assertEqual(result.status_code, 200)
            self.assertEqual(result.data["curriculum"]["template"], template)
            self.assertEqual(result.data["curriculum"]["data"], original)
            self.assertEqual(self.client.get(BASE + "generated/").data["curriculum"]["data"], original)
        changed = deepcopy(DATA)
        changed["professional_summary"] = "Resumen actualizado"
        self.assertEqual(self.save_generated("moderna", changed).status_code, 200)
        self.assertEqual(GeneratedCurriculum.objects.count(), 1)
        self.assertEqual(self.client.get(BASE + "generated/").data["curriculum"]["data"]["professional_summary"], "Resumen actualizado")
        self.owner.refresh_from_db()
        self.assertEqual(self.owner.full_name, "Nombre de cuenta")

    def test_invalid_template_fields_and_dates_do_not_overwrite_saved_data(self):
        self.save_generated()
        original = deepcopy(GeneratedCurriculum.objects.get().data)
        bad_data = deepcopy(DATA)
        bad_data["education"][0]["end_date"] = "2018-01-01"
        for body in (
            {"template": "desconocida"}, {"candidate": self.other.pk}, {},
            {"data": bad_data}, {"data": {"personal": {"full_name": ""}}},
            {"data": {**DATA, "password": "invasión"}},
            {"data": {**DATA, "skills": [{"name": "Python", "level": "inventado"}]}},
        ):
            result = self.client.patch(BASE + "generated/", body, format="json")
            self.assertEqual(result.status_code, 400, result.data)
            self.assertEqual(GeneratedCurriculum.objects.get().data, original)

    def test_generated_schema_limits_and_non_object_json(self):
        for body in ([], "texto", 3, {"template": "clasica", "data": []}):
            self.assertEqual(self.client.put(BASE + "generated/", body, format="json").status_code, 400)
        data = deepcopy(DATA)
        data["extra_sections"] *= 11
        self.assertEqual(self.save_generated(data=data).status_code, 400)
        data = deepcopy(DATA)
        data["education"] = [{"qualification": "Formación", "description": "x" * 3000}] * 50
        self.assertEqual(self.save_generated(data=data).status_code, 400)
        self.assertFalse(GeneratedCurriculum.objects.exists())

    def test_preview_three_templates_without_saving_and_download_stored_pdf(self):
        for template in ("clasica", "moderna", "minimalista"):
            before = list(GeneratedCurriculum.objects.values("template", "data", "updated_at"))
            response = self.client.post(BASE + "generated/preview/", {"template": template, "data": DATA}, format="json")
            reader = self.assert_pdf(response, text="María Núñez")
            text = "\n".join(page.extract_text() for page in reader.pages)
            for expected in ("Ingeniería de Sistemas", "Equipo QA", "Pruebas de software", "Voluntariado", "Español"):
                self.assertIn(expected, text)
            self.assertIn("inline", response["Content-Disposition"])
            self.assertEqual(list(GeneratedCurriculum.objects.values("template", "data", "updated_at")), before)
            self.assertEqual(self.save_generated(template).status_code, 201 if template == "clasica" else 200)
            response = self.client.get(BASE + "generated/pdf/")
            self.assert_pdf(response, text="María Núñez")
            self.assertIn("attachment", response["Content-Disposition"])

    def test_text_markup_is_printed_without_interpreting_images_or_links(self):
        data = deepcopy(DATA)
        data["professional_summary"] = '<b>Texto literal</b> & <img src="https://example.test/privado"/>'
        response = self.client.post(BASE + "generated/preview/", {"template": "moderna", "data": data}, format="json")
        self.assert_pdf(response, text="<b>Texto literal</b>")

    def test_long_curriculum_flows_to_multiple_pages_without_losing_last_record(self):
        data = deepcopy(DATA)
        data["experience"] = [{"position": f"Puesto {i}", "description": "Descripción de actividades y resultados. " * 30} for i in range(18)]
        response = self.client.post(BASE + "generated/preview/", {"template": "moderna", "data": data}, format="json")
        reader = self.assert_pdf(response, text="Puesto 17")
        self.assertGreater(len(reader.pages), 1)

    def test_saved_cv_is_not_overwritten_by_later_profile_changes(self):
        self.save_generated()
        CandidateProfile.objects.create(candidate=self.owner, professional_summary="Cambio posterior del perfil")
        saved = self.client.get(BASE + "generated/").data["curriculum"]["data"]
        self.assertEqual(saved["professional_summary"], DATA["professional_summary"])

    def test_uploaded_and_generated_options_coexist_and_remain_private(self):
        self.client.put(BASE + "uploaded/", {"file": upload()}, format="multipart")
        self.save_generated()
        result = self.client.get(BASE)
        self.assertEqual([row["source"] for row in result.data["options"]], ["uploaded", "generated"])
        self.assertNotIn("document", result.json())
        self.authenticate(self.other)
        self.assertEqual(self.client.get(BASE).data["options"], [])
        self.assertFalse(self.client.get(BASE + f"generated/?candidate={self.owner.pk}").data["exists"])
        self.assertEqual(self.client.get(BASE + "generated/pdf/").status_code, 404)
        self.client.delete(BASE + "generated/")
        self.assertEqual(GeneratedCurriculum.objects.count(), 1)

    def test_missing_pdf_and_edit_before_save_explain_problem(self):
        self.assertEqual(self.client.get(BASE + "generated/pdf/").status_code, 404)
        self.assertEqual(self.client.patch(BASE + "generated/", {"template": "moderna"}, format="json").status_code, 404)
        self.assertEqual(self.client.post(BASE + "generated/preview/", {}, format="json").status_code, 400)

    def test_delete_generated_preserves_uploaded_profile_and_account(self):
        self.client.put(BASE + "uploaded/", {"file": upload()}, format="multipart")
        self.save_generated()
        profile = CandidateProfile.objects.create(candidate=self.owner, professional_summary="Conservar")
        self.assertEqual(self.client.delete(BASE + "generated/").status_code, 200)
        self.assertFalse(GeneratedCurriculum.objects.exists())
        self.assertTrue(UploadedCurriculum.objects.exists())
        self.assertTrue(CandidateProfile.objects.filter(pk=profile.pk).exists())
        self.assertTrue(User.objects.filter(pk=self.owner.pk).exists())

    def test_authentication_role_and_verification_protect_all_curriculum_routes(self):
        routes = [BASE, BASE + "uploaded/", BASE + "generated/", BASE + "generated/pdf/"]
        self.client.credentials()
        for route in routes:
            self.assertEqual(self.client.get(route).status_code, 401)
        self.assertEqual(self.client.post(BASE + "generated/preview/", {}, format="json").status_code, 401)
        for name, role, verified, staff in (("empresa", "empresa", True, False), ("admin", "", True, True), ("sin-verificar", "candidato", False, False)):
            user = User.objects.create_user(email=name + "@example.test", full_name=name, role=role, email_verified=verified, is_staff=staff)
            self.authenticate(user)
            for route in routes:
                self.assertEqual(self.client.get(route).status_code, 403)
            self.assertEqual(self.client.post(BASE + "generated/preview/", {}, format="json").status_code, 403)
            self.assertEqual(self.client.put(BASE + "uploaded/", {"file": upload()}, format="multipart").status_code, 403)

    def test_account_deletion_removes_both_private_curricula(self):
        self.client.put(BASE + "uploaded/", {"file": upload()}, format="multipart")
        self.save_generated()
        self.owner.delete()
        self.assertFalse(UploadedCurriculum.objects.exists())
        self.assertFalse(GeneratedCurriculum.objects.exists())
