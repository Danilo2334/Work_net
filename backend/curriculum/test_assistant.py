from copy import deepcopy
from io import BytesIO
import json
from unittest.mock import MagicMock, patch
from urllib.error import HTTPError, URLError

from django.core.cache import cache
from django.test import SimpleTestCase, TestCase, override_settings
from rest_framework.test import APIClient

from accounts.models import User
from accounts.testing import fixture_token
from candidate_dashboard.models import CandidateProfile
from .assistant import AssistantFailure, generate
from .models import GeneratedCurriculum


URL = "/api/curriculum/generated/assistant/"
TEXT = "Ana QA. Ingeniera de Software de Universidad QA. Desarrolladora en Equipo QA. Python avanzado. Español nativo."
DATA = {
    "personal": {"full_name": "Ana QA", "email": "", "phone": "", "location": "", "website": ""},
    "professional_summary": "Ingeniera de Software con experiencia en desarrollo.",
    "education": [{"qualification": "Ingeniera de Software", "institution": "Universidad QA", "start_date": None, "end_date": None, "description": ""}],
    "experience": [{"position": "Desarrolladora", "company": "Equipo QA", "start_date": None, "end_date": None, "description": ""}],
    "skills": [{"name": "Python", "level": "avanzado"}],
    "languages": [{"name": "Español", "level": "nativo"}],
    "certifications": [], "extra_sections": [],
}


def proposal():
    return {"data": deepcopy(DATA), "missing_information": ["Completa las fechas de experiencia y formación."]}


@override_settings(PASSWORD_HASHERS=["django.contrib.auth.hashers.MD5PasswordHasher"],
                   GEMINI_API_KEY="fixture-key-not-real", GEMINI_MODEL="gemini-3.5-flash-lite", CURRICULUM_AI_RATE="1000/hour")
class CurriculumAssistantTests(TestCase):
    def setUp(self):
        cache.clear()
        self.user = User.objects.create_user(email="ai.owner@example.test", full_name="Nombre de cuenta", role="candidato", email_verified=True)
        self.other = User.objects.create_user(email="ai.other@example.test", full_name="Otro candidato", role="candidato", email_verified=True)
        self.client = APIClient()
        self.authenticate(self.user)
        self.generator = patch("curriculum.assistant.generate", return_value=(proposal(), "fixture-model")).start()
        self.addCleanup(patch.stopall)

    def authenticate(self, user):
        self.client.credentials(HTTP_AUTHORIZATION="Token " + fixture_token(user).key)

    def post(self, **kwargs):
        return self.client.post(URL, {"text": TEXT, "consent": True, **kwargs}, format="json")

    def test_configuration_reports_presence_without_key_or_network(self):
        response = self.client.get(URL)
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.data["available"])
        self.assertNotIn("fixture-key", json.dumps(response.data))
        self.generator.assert_not_called()
        self.assertEqual(response["Cache-Control"], "private, no-store")
        self.assertIn("Authorization", response["Vary"])
        with override_settings(GEMINI_API_KEY=""):
            self.assertFalse(self.client.get(URL).data["available"])

    def test_json_field_names_do_not_count_as_user_supplied_facts(self):
        value = proposal()
        value["data"]["skills"] = [{"name": "text", "level": ""}]
        self.generator.return_value = (value, "fixture-model")
        response = self.post()
        self.assertEqual(response.status_code, 502)
        self.assertEqual(GeneratedCurriculum.objects.count(), 0)

    def test_generation_proposes_without_saving_and_does_not_read_other_profile(self):
        CandidateProfile.objects.create(candidate=self.other, professional_summary="SECRET_OTHER_PROFILE")
        response = self.post()
        self.assertEqual(response.status_code, 200)
        self.assertIs(response.data["saved"], False)
        self.assertEqual(response.data["suggestion"]["data"]["skills"], DATA["skills"])
        self.assertFalse(GeneratedCurriculum.objects.exists())
        self.assertEqual(self.generator.call_args.args[0], {"text": TEXT})
        self.assertNotIn("SECRET_OTHER_PROFILE", json.dumps(response.data))

    def test_include_profile_is_explicit_and_owner_only(self):
        CandidateProfile.objects.create(candidate=self.user, professional_summary="Resumen propio", skills=["SQL"])
        CandidateProfile.objects.create(candidate=self.other, professional_summary="SECRET_OTHER_PROFILE")
        self.assertEqual(self.post(include_profile=True).status_code, 200)
        source = self.generator.call_args.args[0]
        self.assertEqual(source["profile"]["professional_summary"], "Resumen propio")
        self.assertEqual(source["profile"]["personal"]["email"], self.user.email)
        self.assertNotIn("SECRET_OTHER_PROFILE", json.dumps(source))

    def test_authentication_role_and_verification_before_provider(self):
        self.client.credentials()
        self.assertEqual(self.post().status_code, 401)
        for role, verified in [("empresa", True), ("candidato", False)]:
            user = User.objects.create_user(email=f"ai.{role}.{verified}@example.test", full_name="QA", role=role, email_verified=verified)
            self.authenticate(user)
            self.assertEqual(self.post().status_code, 403)
        self.generator.assert_not_called()

    def test_invalid_input_and_missing_consent_never_calls_provider(self):
        for overrides in ({"consent": False}, {"text": ""}, {"text": "x" * 12001}, {"candidate": self.other.pk}, {"include_profile": "invalid"}):
            with self.subTest(overrides=tuple(overrides)):
                self.assertEqual(self.post(**overrides).status_code, 400)
        self.generator.assert_not_called()

    def test_oversized_profile_is_rejected_before_provider(self):
        CandidateProfile.objects.create(candidate=self.user, professional_summary="x" * 33000)
        self.assertEqual(self.post(include_profile=True).status_code, 400)
        self.generator.assert_not_called()

    def test_provider_failures_preserve_existing_cv_and_account(self):
        saved = GeneratedCurriculum.objects.create(candidate=self.user, template="moderna", data=deepcopy(DATA))
        for status in (429, 502, 503):
            self.generator.side_effect = AssistantFailure("Indisponible", status=status)
            self.assertEqual(self.post().status_code, status)
            saved.refresh_from_db()
            self.assertEqual(saved.data, DATA)
            self.assertEqual(saved.template, "moderna")
        self.user.refresh_from_db()
        self.assertEqual(self.user.full_name, "Nombre de cuenta")

    def test_invalid_structure_dates_levels_and_unprovided_facts_are_rejected(self):
        variants = []
        bad = proposal(); bad["data"]["owner"] = self.other.pk; variants.append(bad)
        bad = proposal(); bad["data"]["experience"][0]["company"] = "Empresa inventada"; variants.append(bad)
        bad = proposal(); bad["data"]["education"][0]["start_date"] = "2020-01-01"; variants.append(bad)
        bad = proposal(); bad["data"]["languages"][0]["level"] = "C2"; variants.append(bad)
        bad = proposal(); bad["data"]["experience"] = [{}]; variants.append(bad)
        bad = proposal(); bad["missing_information"] = [42]; variants.append(bad)
        bad = proposal(); bad["data"]["personal"]["email"] = 42; variants.append(bad)
        bad = proposal(); bad["data"]["experience"][0]["company"] = 0; variants.append(bad)
        for result in variants:
            with self.subTest(result=result):
                self.generator.return_value = (result, "fixture-model")
                self.assertEqual(self.post().status_code, 502)
        self.assertFalse(GeneratedCurriculum.objects.exists())

    def test_missing_personal_information_is_not_proposed_as_shared(self):
        value = proposal()
        value["data"]["personal"]["full_name"] = ""
        self.generator.return_value = (value, "fixture-model")
        response = self.post()
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["suggestion"]["personal_fields"], [])
        self.assertEqual(response.data["suggestion"]["data"]["personal"]["full_name"], self.user.full_name)
        self.assertNotIn("Nombre de cuenta", json.dumps(self.generator.call_args.args[0]))

    def test_reviewed_data_can_be_saved_and_rendered_in_all_three_templates(self):
        suggestion = self.post().data["suggestion"]["data"]
        for template in ("clasica", "moderna", "minimalista"):
            response = self.client.put("/api/curriculum/generated/", {"template": template, "data": suggestion}, format="json")
            self.assertIn(response.status_code, (200, 201))
            document = self.client.get("/api/curriculum/generated/pdf/")
            self.assertEqual(document.status_code, 200)
            self.assertTrue(document.content.startswith(b"%PDF-"))
        self.authenticate(self.other)
        self.assertEqual(self.client.get("/api/curriculum/generated/pdf/").status_code, 404)

    @override_settings(CURRICULUM_AI_RATE="1/hour")
    def test_rate_limit_is_per_candidate_and_configuration_get_is_free(self):
        for _ in range(3):
            self.assertEqual(self.client.get(URL).status_code, 200)
        self.assertEqual(self.post().status_code, 200)
        response = self.post()
        self.assertEqual(response.status_code, 429)
        self.assertIn("Retry-After", response)
        self.authenticate(self.other)
        self.assertEqual(self.post().status_code, 200)


@override_settings(GEMINI_API_KEY="fixture-key-not-real", GEMINI_MODEL="gemini-3.5-flash-lite")
class GeminiTransportTests(SimpleTestCase):
    def test_private_header_fixed_host_structured_json_and_timeout(self):
        envelope = {"candidates": [{"finishReason": "STOP", "content": {"parts": [{"text": json.dumps(proposal())}]}}]}
        response = MagicMock()
        response.__enter__.return_value.read.return_value = json.dumps(envelope).encode()
        with patch("curriculum.assistant.build_opener") as opener:
            opener.return_value.open.return_value = response
            result, model = generate({"text": TEXT})
        request = opener.return_value.open.call_args.args[0]
        self.assertEqual(request.full_url, "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent")
        self.assertNotIn("fixture-key", request.full_url)
        self.assertEqual(request.get_header("X-goog-api-key"), "fixture-key-not-real")
        payload = json.loads(request.data)
        self.assertIn("schema", payload["generationConfig"]["responseFormat"]["text"])
        self.assertEqual(payload["generationConfig"]["responseFormat"]["text"]["mimeType"], "APPLICATION_JSON")
        self.assertEqual(opener.return_value.open.call_args.kwargs["timeout"], 15)
        self.assertEqual(result, proposal())
        self.assertEqual(model, "gemini-3.5-flash-lite")

    def test_configuration_missing_or_invalid_never_connects(self):
        for settings in ({"GEMINI_API_KEY": ""}, {"GEMINI_MODEL": ""}, {"GEMINI_MODEL": "https://example.test/leak"}):
            with override_settings(**settings), patch("curriculum.assistant.build_opener") as opener:
                with self.assertRaises(AssistantFailure): generate({"text": TEXT})
                opener.assert_not_called()

    def test_upstream_failures_do_not_leak_details_or_credentials(self):
        for error in (HTTPError("private", 429, "fixture-key-not-real", {}, BytesIO()),
                      HTTPError("private", 401, "fixture-key-not-real", {}, BytesIO()),
                      URLError("fixture-key-not-real"), TimeoutError("fixture-key-not-real")):
            with patch("curriculum.assistant.build_opener") as opener:
                opener.return_value.open.side_effect = error
                with self.assertRaises(AssistantFailure) as caught: generate({"text": TEXT})
                self.assertNotIn("fixture-key", str(caught.exception))

    def test_malformed_oversized_and_unfinished_responses_are_rejected(self):
        for raw in (b"bad-json", b"x" * (256 * 1024 + 1), b'{}',
                    b'{"candidates":[{"finishReason":"MAX_TOKENS","content":{"parts":[{"text":"{}"}]}}]}'):
            response = MagicMock()
            response.__enter__.return_value.read.return_value = raw
            with patch("curriculum.assistant.build_opener") as opener:
                opener.return_value.open.return_value = response
                with self.assertRaises(AssistantFailure) as caught: generate({"text": TEXT})
                self.assertEqual(caught.exception.status_code, 502)
