"""HU008: owner-only structured profile and private, validated photograph."""
from datetime import date
from io import BytesIO
from pathlib import Path
import json
import uuid
import warnings

from django.db import transaction
from django.http import HttpResponse
from PIL import Image, ImageOps, UnidentifiedImageError
from rest_framework import serializers
from rest_framework.authentication import TokenAuthentication
from rest_framework.exceptions import NotFound, ValidationError
from rest_framework.parsers import MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.account_configuration import StrictInputSerializer
from .models import CandidateProfile
from .views import IsCandidate, profile_completion


SECTIONS = ("education", "experience", "skills", "languages")
MAX_PHOTO_BYTES = 2 * 1024 * 1024


class SummarySerializer(StrictInputSerializer):
    professional_summary = serializers.CharField(max_length=5000, allow_blank=True)


class DatedRecordSerializer(StrictInputSerializer):
    start_date = serializers.DateField(required=False, allow_null=True)
    end_date = serializers.DateField(required=False, allow_null=True)
    description = serializers.CharField(max_length=3000, required=False, allow_blank=True)

    def validate(self, data):
        previous = self.context.get("previous", {})
        merged = {**previous, **data}
        start, end = merged.get("start_date"), merged.get("end_date")
        # Legacy values remain stored; all new date values are validated above.
        if start and end:
            try:
                start = start if isinstance(start, date) else date.fromisoformat(start)
                end = end if isinstance(end, date) else date.fromisoformat(end)
            except (ValueError, TypeError):
                raise serializers.ValidationError("Corrige las fechas del registro antes de guardarlo.")
            if start > end:
                raise serializers.ValidationError({"end_date": "La fecha final no puede ser anterior a la inicial."})
        return data


class EducationSerializer(DatedRecordSerializer):
    qualification = serializers.CharField(max_length=200)
    institution = serializers.CharField(max_length=200, required=False, allow_blank=True)


class ExperienceSerializer(DatedRecordSerializer):
    position = serializers.CharField(max_length=200)
    company = serializers.CharField(max_length=200, required=False, allow_blank=True)


class SkillSerializer(StrictInputSerializer):
    name = serializers.CharField(max_length=100)
    level = serializers.ChoiceField(choices=("", "basico", "intermedio", "avanzado"), required=False)


class LanguageSerializer(StrictInputSerializer):
    name = serializers.CharField(max_length=100)
    level = serializers.ChoiceField(choices=("", "A1", "A2", "B1", "B2", "C1", "C2", "nativo"), required=False)


SERIALIZERS = dict(zip(SECTIONS, (EducationSerializer, ExperienceSerializer, SkillSerializer, LanguageSerializer)))


def json_fields(validated):
    return {key: value.isoformat() if isinstance(value, date) else value for key, value in validated.items()}


def records(profile, section):
    """Adapt legacy JSON without losing original keys or writing during GET."""
    result = []
    for index, original in enumerate(getattr(profile, section)):
        row = dict(original) if isinstance(original, dict) else {"name": str(original)}
        row.setdefault("id", str(uuid.uuid5(uuid.NAMESPACE_URL, f"worknet:{profile.pk}:{section}:{index}:{json.dumps(original, sort_keys=True)}")))
        if section == "education":
            row.setdefault("qualification", row.get("title", row.get("name", "")))
        elif section == "experience":
            row.setdefault("position", row.get("title", row.get("name", "")))
        else:
            row.setdefault("name", row.get("title", ""))
        result.append(row)
    return result


def payload(user, profile):
    return {
        "profile": {
            "exists": profile is not None,
            "professional_summary": profile.professional_summary if profile else "",
            "has_photo": bool(profile and profile.photo_data),
            **{section: records(profile, section) if profile else [] for section in SECTIONS},
        },
        "profile_completion": profile_completion(user, profile),
    }


class ProfileCandidatePermission(IsCandidate):
    message = "Este perfil está disponible únicamente para su candidato autenticado y verificado."

    def has_permission(self, request, view):
        return super().has_permission(request, view) and request.user.email_verified


class OwnProfileView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated, ProfileCandidatePermission]

    def handle_exception(self, exc):
        response = super().handle_exception(exc)
        if isinstance(exc, ValidationError):
            response.data = {"message": "Revisa los datos del perfil.", "errors": response.data}
        return response

    def profile(self, request, *, locked=False):
        query = CandidateProfile.objects.select_for_update() if locked else CandidateProfile.objects
        return query.filter(candidate=request.user).first()


class ProfileView(OwnProfileView):
    def get(self, request):
        return Response(payload(request.user, self.profile(request)))

    @transaction.atomic
    def post(self, request):
        serializer = SummarySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        profile, created = CandidateProfile.objects.get_or_create(candidate=request.user, defaults=serializer.validated_data)
        if not created:
            return Response({"message": "El perfil ya existe. Actualízalo para guardar cambios."}, status=409)
        return Response(payload(request.user, profile), status=201)

    @transaction.atomic
    def patch(self, request):
        serializer = SummarySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        profile = self.profile(request, locked=True)
        if profile is None:
            raise NotFound("Todavía no has creado tu perfil.")
        profile.professional_summary = serializer.validated_data["professional_summary"]
        profile.save(update_fields=["professional_summary"])
        return Response(payload(request.user, profile))

    @transaction.atomic
    def delete(self, request):
        profile = self.profile(request, locked=True)
        if profile:
            profile.delete()
        return Response(payload(request.user, None))


class ProfileRecordsView(OwnProfileView):
    def serializer_class(self, section):
        if section not in SERIALIZERS:
            raise NotFound("Esta sección no está disponible.")
        return SERIALIZERS[section]

    def get(self, request, section):
        self.serializer_class(section)
        profile = self.profile(request)
        return Response({"records": records(profile, section) if profile else []})

    @transaction.atomic
    def post(self, request, section):
        serializer = self.serializer_class(section)(data=request.data)
        serializer.is_valid(raise_exception=True)
        profile, _ = CandidateProfile.objects.get_or_create(candidate=request.user)
        profile = CandidateProfile.objects.select_for_update().get(pk=profile.pk)
        rows = records(profile, section)
        if len(rows) >= 100:
            raise ValidationError({"message": "Puedes guardar hasta 100 registros en esta sección."})
        rows.append({"id": str(uuid.uuid4()), **json_fields(serializer.validated_data)})
        setattr(profile, section, rows)
        profile.save(update_fields=[section])
        return Response(payload(request.user, profile), status=201)


class ProfileRecordView(ProfileRecordsView):
    http_method_names = ["get", "head", "patch", "delete", "options"]

    def find(self, request, section, record_id, *, locked=True):
        self.serializer_class(section)
        profile = self.profile(request, locked=locked)
        rows = records(profile, section) if profile else []
        row = next((row for row in rows if row["id"] == str(record_id)), None)
        if row is None:
            raise NotFound("No encontramos ese registro en tu perfil.")
        return profile, rows, row

    def get(self, request, section, record_id):
        _, _, row = self.find(request, section, record_id, locked=False)
        return Response({"record": row})

    @transaction.atomic
    def patch(self, request, section, record_id):
        profile, rows, row = self.find(request, section, record_id)
        if not request.data:
            raise ValidationError({"message": "Envía al menos un campo para actualizar."})
        serializer = self.serializer_class(section)(data=request.data, partial=True, context={"previous": row})
        serializer.is_valid(raise_exception=True)
        row.update(json_fields(serializer.validated_data))
        setattr(profile, section, rows)
        profile.save(update_fields=[section])
        return Response(payload(request.user, profile))

    @transaction.atomic
    def delete(self, request, section, record_id):
        profile, rows, row = self.find(request, section, record_id)
        rows.remove(row)
        setattr(profile, section, rows)
        profile.save(update_fields=[section])
        return Response(payload(request.user, profile))


def validated_photo(upload):
    if upload.size > MAX_PHOTO_BYTES:
        raise ValidationError({"photo": "La fotografía no puede superar 2 MiB."})
    allowed = {".jpg": ("JPEG", "image/jpeg"), ".jpeg": ("JPEG", "image/jpeg"), ".png": ("PNG", "image/png")}
    expected = allowed.get(Path(upload.name).suffix.lower())
    if expected is None or upload.content_type != expected[1]:
        raise ValidationError({"photo": "Selecciona una imagen JPEG o PNG válida."})
    raw = upload.read(MAX_PHOTO_BYTES + 1)
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("error", Image.DecompressionBombWarning)
            with Image.open(BytesIO(raw)) as image:
                if image.format != expected[0] or getattr(image, "n_frames", 1) != 1:
                    raise ValueError()
                if max(image.size) > 4096 or image.width * image.height > 16_000_000:
                    raise ValueError()
                image.verify()
            with Image.open(BytesIO(raw)) as image:
                image = ImageOps.exif_transpose(image)
                image.thumbnail((1024, 1024))
                # Re-encode pixels only; no original metadata, filename or payload.
                clean = Image.new("RGB", image.size, "white")
                converted = image.convert("RGBA")
                clean.paste(converted, mask=converted.getchannel("A"))
                output = BytesIO()
                clean.save(output, format="JPEG", quality=85)
                return output.getvalue()
    except (UnidentifiedImageError, OSError, ValueError, Image.DecompressionBombError, Image.DecompressionBombWarning):
        raise ValidationError({"photo": "La imagen está dañada, no coincide con su formato o supera 4096 px / 16 MP."})


class ProfilePhotoView(OwnProfileView):
    parser_classes = [MultiPartParser]

    def get(self, request):
        profile = self.profile(request)
        if not profile or not profile.photo_data:
            raise NotFound("Todavía no has agregado una fotografía.")
        response = HttpResponse(bytes(profile.photo_data), content_type="image/jpeg")
        response["Cache-Control"] = "private, no-store"
        response["Vary"] = "Authorization"
        response["X-Content-Type-Options"] = "nosniff"
        response["Content-Disposition"] = 'inline; filename="profile.jpg"'
        return response

    @transaction.atomic
    def put(self, request):
        if set(request.data) != {"photo"} or len(request.FILES.getlist("photo")) != 1:
            raise ValidationError({"photo": "Envía una única fotografía en el campo photo."})
        data = validated_photo(request.FILES["photo"])
        profile, _ = CandidateProfile.objects.get_or_create(candidate=request.user)
        profile.photo_data = data
        profile.save(update_fields=["photo_data"])
        return Response(payload(request.user, profile))

    @transaction.atomic
    def delete(self, request):
        profile = self.profile(request, locked=True)
        if profile:
            profile.photo_data = b""
            profile.save(update_fields=["photo_data"])
        return Response(payload(request.user, profile))
