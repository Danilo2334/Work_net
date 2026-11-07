from io import BytesIO
import uuid

from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase
from PIL import Image
from rest_framework.authtoken.models import Token
from rest_framework.test import APIClient

from accounts.models import User
from .models import Application, CandidateProfile, JobOffer
from .profile import MAX_PHOTO_BYTES


BASE = "/api/profile/candidate/"


def photo(name="qa.png", content_type="image/png", size=(24, 24), fmt="PNG"):
    output = BytesIO()
    Image.new("RGB", size, "#087f70").save(output, format=fmt)
    return SimpleUploadedFile(name, output.getvalue(), content_type=content_type)


class CandidateProfileTests(TestCase):
    def setUp(self):
        self.owner = User.objects.create_user(email="perfil.qa@example.test", full_name="Perfil QA", password="QaPassword!2026", role="candidato", email_verified=True)
        self.other = User.objects.create_user(email="otro.qa@example.test", full_name="Otro QA", password="QaPassword!2026", role="candidato", email_verified=True)
        self.client = APIClient()
        self.authenticate(self.owner)

    def authenticate(self, user):
        token, _ = Token.objects.get_or_create(user=user)
        self.client.credentials(HTTP_AUTHORIZATION="Token " + token.key)

    def test_empty_get_does_not_create_profile(self):
        result = self.client.get(BASE)
        self.assertEqual(result.status_code, 200)
        self.assertFalse(result.data["profile"]["exists"])
        self.assertEqual(result.data["profile_completion"]["percentage"], 17)
        self.assertFalse(CandidateProfile.objects.filter(candidate=self.owner).exists())

    def test_create_edit_and_delete_profile(self):
        self.assertEqual(self.client.post(BASE, {"professional_summary": "Perfil de prueba"}, format="json").status_code, 201)
        self.assertEqual(self.client.post(BASE, {"professional_summary": "Otro"}, format="json").status_code, 409)
        self.assertEqual(self.client.patch(BASE, {"professional_summary": "Editado"}, format="json").status_code, 200)
        self.assertEqual(self.client.get(BASE).data["profile"]["professional_summary"], "Editado")
        self.assertEqual(self.client.delete(BASE).status_code, 200)
        self.assertFalse(self.client.get(BASE).data["profile"]["exists"])

    def test_summary_validation_and_mass_assignment(self):
        for data in ({}, {"professional_summary": "x" * 5001}, {"professional_summary": "QA", "candidate": self.other.pk}, {"professional_summary": "QA", "skills": ["injected"]}):
            with self.subTest(data=list(data)):
                self.assertEqual(self.client.post(BASE, data, format="json").status_code, 400)

    def test_all_sections_support_create_read_edit_delete_with_structured_json(self):
        for section, row, changed in [
            ("education", {"qualification": "Título QA", "institution": "Instituto QA", "start_date": "2021-01-01", "end_date": "2023-12-01"}, {"qualification": "Título editado"}),
            ("experience", {"position": "Puesto QA", "company": "Empresa QA", "start_date": "2024-01-01"}, {"company": "Empresa editada"}),
            ("skills", {"name": "Flutter", "level": "intermedio"}, {"level": "avanzado"}),
            ("languages", {"name": "Español", "level": "nativo"}, {"name": "Español QA"}),
        ]:
            with self.subTest(section=section):
                result = self.client.post(BASE + section + "/", row, format="json")
                self.assertEqual(result.status_code, 201, result.data)
                saved = result.data["profile"][section][-1]
                uuid.UUID(saved["id"])
                path = BASE + section + "/" + saved["id"] + "/"
                self.assertEqual(self.client.get(path).data["record"]["id"], saved["id"])
                self.assertEqual(self.client.patch(path, changed, format="json").status_code, 200)
                self.assertEqual(self.client.get(path).data["record"][next(iter(changed))], next(iter(changed.values())))
                self.assertEqual(self.client.delete(path).status_code, 200)
                self.assertEqual(self.client.get(BASE + section + "/").data["records"], [])

    def test_dates_are_validated_against_previous_record_on_partial_edit(self):
        result = self.client.post(BASE + "education/", {"qualification": "QA", "start_date": "2020-01-01", "end_date": "2023-01-01"}, format="json")
        path = BASE + "education/" + result.data["profile"]["education"][0]["id"] + "/"
        self.assertEqual(self.client.patch(path, {"start_date": "2024-01-01"}, format="json").status_code, 400)
        self.assertEqual(self.client.patch(path, {"end_date": None}, format="json").status_code, 200)

    def test_invalid_records_and_unknown_fields_are_rejected(self):
        for section, data in [
            ("education", {"qualification": ""}),
            ("experience", {"position": "QA", "start_date": "not-a-date"}),
            ("skills", {"name": "QA", "level": "expert"}),
            ("languages", {"name": "QA", "level": "Z9"}),
            ("skills", {"name": "QA", "id": "injected"}),
        ]:
            self.assertEqual(self.client.post(BASE + section + "/", data, format="json").status_code, 400)
        self.assertEqual(self.client.get(BASE + "unknown/").status_code, 404)

    def test_legacy_records_are_readable_stable_and_original_keys_survive_edit(self):
        original = {"title": "Estudio histórico QA", "custom_note": "Conservar"}
        profile = CandidateProfile.objects.create(candidate=self.owner, education=[original], skills=["Python"])
        first = self.client.get(BASE).data["profile"]
        self.assertEqual(first["education"][0]["qualification"], original["title"])
        self.assertEqual(first["skills"][0]["name"], "Python")
        self.assertEqual(first["education"][0]["id"], self.client.get(BASE).data["profile"]["education"][0]["id"])
        profile.refresh_from_db()
        self.assertEqual(profile.education, [original])  # GET never rewrites legacy data.
        path = BASE + "education/" + first["education"][0]["id"] + "/"
        self.assertEqual(self.client.patch(path, {"institution": "Instituto QA"}, format="json").status_code, 200)
        profile.refresh_from_db()
        self.assertEqual(profile.education[0]["custom_note"], "Conservar")

    def test_section_limits(self):
        CandidateProfile.objects.create(candidate=self.owner, skills=["QA"] * 100)
        self.assertEqual(self.client.post(BASE + "skills/", {"name": "Extra"}, format="json").status_code, 400)

    def test_other_candidate_cannot_read_or_mutate_records(self):
        result = self.client.post(BASE + "skills/", {"name": "Privado QA"}, format="json")
        key = result.data["profile"]["skills"][0]["id"]
        self.authenticate(self.other)
        self.assertEqual(self.client.get(BASE).data["profile"]["skills"], [])
        path = BASE + "skills/" + key + "/"
        self.assertEqual(self.client.get(path).status_code, 404)
        self.assertEqual(self.client.patch(path, {"name": "Intruso"}, format="json").status_code, 404)
        self.assertEqual(self.client.delete(path).status_code, 404)

    def test_company_denied_even_if_candidate_has_applied_no_selection_authorization_exists(self):
        company = User.objects.create_user(email="company.qa@example.test", full_name="Empresa QA", role="empresa", email_verified=True)
        offer = JobOffer.objects.create(company=company, title="QA", company_name="QA", location="QA", contract_type="QA")
        Application.objects.create(candidate=self.owner, offer=offer)
        self.authenticate(company)
        for path in (BASE, BASE + "skills/", BASE + "photo/"):
            self.assertEqual(self.client.get(path).status_code, 403)

    def test_anonymous_all_writes_and_reads_require_authentication(self):
        self.client.credentials()
        for method, path, data in [("get", BASE, None), ("post", BASE, {"professional_summary": "QA"}), ("patch", BASE, {"professional_summary": "QA"}), ("delete", BASE, None), ("get", BASE + "photo/", None), ("put", BASE + "photo/", None), ("post", BASE + "skills/", {"name": "QA"})]:
            self.assertEqual(getattr(self.client, method)(path, data, format="json").status_code, 401)

    def test_admin_staff_and_unverified_are_denied(self):
        for role, staff, verified in [("admin", True, True), ("candidato", True, True), ("candidato", False, False)]:
            user = User.objects.create_user(email=f"{role}-{staff}-{verified}@example.test", full_name="QA", role=role, is_staff=staff, email_verified=verified)
            self.authenticate(user)
            self.assertEqual(self.client.get(BASE).status_code, 403)

    def test_valid_photo_is_private_reencoded_and_optional(self):
        result = self.client.put(BASE + "photo/", {"photo": photo()}, format="multipart")
        self.assertEqual(result.status_code, 200, result.data)
        self.assertTrue(result.data["profile"]["has_photo"])
        self.assertEqual(result.data["profile_completion"]["percentage"], 17)
        result = self.client.get(BASE + "photo/")
        self.assertEqual(result.status_code, 200)
        self.assertEqual(result["Content-Type"], "image/jpeg")
        self.assertIn("no-store", result["Cache-Control"])
        self.assertEqual(result["X-Content-Type-Options"], "nosniff")
        with Image.open(BytesIO(result.content)) as image:
            self.assertEqual(image.format, "JPEG")
            self.assertFalse(image.getexif())
        self.authenticate(self.other)
        self.assertEqual(self.client.get(BASE + "photo/").status_code, 404)
        self.client.credentials()
        self.assertEqual(self.client.get(BASE + "photo/").status_code, 401)

    def test_photo_replace_and_delete(self):
        for upload in (photo(), photo("qa.jpg", "image/jpeg", fmt="JPEG")):
            self.assertEqual(self.client.put(BASE + "photo/", {"photo": upload}, format="multipart").status_code, 200)
        self.assertFalse(self.client.delete(BASE + "photo/").data["profile"]["has_photo"])
        self.assertEqual(self.client.get(BASE + "photo/").status_code, 404)

    def test_invalid_photos_are_rejected_without_destroying_previous(self):
        self.client.put(BASE + "photo/", {"photo": photo()}, format="multipart")
        previous = self.client.get(BASE + "photo/").content
        for upload in (
            SimpleUploadedFile("qa.svg", b"<svg/>", content_type="image/svg+xml"),
            SimpleUploadedFile("fake.png", b"not an image", content_type="image/png"),
            photo("fake.png", "image/png", fmt="JPEG"),
            photo("qa.png", "application/octet-stream"),
            photo(size=(4097, 1)),
            SimpleUploadedFile("big.png", b"x" * (MAX_PHOTO_BYTES + 1), content_type="image/png"),
        ):
            with self.subTest(name=upload.name):
                result = self.client.put(BASE + "photo/", {"photo": upload}, format="multipart")
                self.assertEqual(result.status_code, 400)
                self.assertEqual(self.client.get(BASE + "photo/").content, previous)

    def test_photo_rejects_multiple_files_and_missing_file(self):
        for data in ({}, {"photo": [photo(), photo()]}, {"photo": "not-a-file"}):
            self.assertEqual(self.client.put(BASE + "photo/", data, format="multipart").status_code, 400)

    def test_dashboard_completion_comes_from_saved_profile_not_photo(self):
        self.client.post(BASE, {"professional_summary": "QA"}, format="json")
        for section, data in [("education", {"qualification": "QA"}), ("experience", {"position": "QA"}), ("skills", {"name": "QA"}), ("languages", {"name": "Español", "level": "nativo"})]:
            self.client.post(BASE + section + "/", data, format="json")
        result = self.client.get("/api/dashboard/candidate/")
        self.assertEqual(result.data["profile_completion"]["percentage"], 100)
        self.client.delete(BASE)
        self.assertEqual(self.client.get("/api/dashboard/candidate/").data["profile_completion"]["percentage"], 17)
