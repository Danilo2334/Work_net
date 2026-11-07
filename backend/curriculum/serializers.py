import json

from rest_framework import serializers

from accounts.account_configuration import StrictInputSerializer
from candidate_dashboard.profile import (
    EducationSerializer, ExperienceSerializer,
    LanguageSerializer, SkillSerializer,
)
from .models import GeneratedCurriculum


class PersonalSerializer(StrictInputSerializer):
    full_name = serializers.CharField(max_length=150)
    email = serializers.EmailField(max_length=254, required=False, allow_blank=True, default="")
    phone = serializers.CharField(max_length=40, required=False, allow_blank=True, default="")
    location = serializers.CharField(max_length=200, required=False, allow_blank=True, default="")
    website = serializers.URLField(max_length=200, required=False, allow_blank=True, default="")


class CertificationSerializer(StrictInputSerializer):
    title = serializers.CharField(max_length=200)
    issuer = serializers.CharField(max_length=200, required=False, allow_blank=True)
    issue_date = serializers.DateField(required=False, allow_null=True)
    description = serializers.CharField(max_length=3000, required=False, allow_blank=True)


class ExtraSectionSerializer(StrictInputSerializer):
    title = serializers.CharField(max_length=120)
    content = serializers.CharField(max_length=3000)


class CurriculumDataSerializer(StrictInputSerializer):
    personal = PersonalSerializer()
    professional_summary = serializers.CharField(max_length=5000, required=False, allow_blank=True, default="")
    education = EducationSerializer(many=True, required=False, default=list, max_length=100)
    experience = ExperienceSerializer(many=True, required=False, default=list, max_length=100)
    skills = SkillSerializer(many=True, required=False, default=list, max_length=100)
    languages = LanguageSerializer(many=True, required=False, default=list, max_length=100)
    certifications = CertificationSerializer(many=True, required=False, default=list, max_length=100)
    extra_sections = ExtraSectionSerializer(many=True, required=False, default=list, max_length=10)

    def validate(self, data):
        if len(json.dumps(data, ensure_ascii=False, default=str).encode("utf-8")) > 128 * 1024:
            raise serializers.ValidationError("El currículum supera 128 KiB de texto. Reduce las descripciones.")
        return data


class GeneratedCurriculumSerializer(StrictInputSerializer):
    template = serializers.ChoiceField(choices=GeneratedCurriculum.Template.choices)
    data = CurriculumDataSerializer()
