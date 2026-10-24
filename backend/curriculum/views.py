from django.db import transaction
from django.http import HttpResponse
from django.utils.http import content_disposition_header
from rest_framework.authentication import TokenAuthentication
from rest_framework.exceptions import NotFound, ValidationError
from rest_framework.parsers import MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from candidate_dashboard.models import CandidateProfile
from candidate_dashboard.profile import ProfileCandidatePermission, SERIALIZERS, records
from .models import GeneratedCurriculum, UploadedCurriculum
from .pdf import render_curriculum
from .serializers import GeneratedCurriculumSerializer
from .uploads import MAX_UPLOAD_BYTES, MAX_UPLOAD_PAGES, validated_pdf


def uploaded_data(curriculum):
    return {
        "filename": curriculum.filename, "size_bytes": curriculum.size_bytes,
        "updated_at": curriculum.updated_at,
    } if curriculum else None


def generated_data(curriculum):
    return {
        "template": curriculum.template, "data": curriculum.data,
        "updated_at": curriculum.updated_at,
    }


def initial_data(user):
    profile = CandidateProfile.objects.filter(candidate=user).first()
    return {
        "personal": {"full_name": user.full_name, "email": user.email, "phone": "", "location": "", "website": ""},
        "professional_summary": profile.professional_summary if profile else "",
        **{
            section: [{key: value for key, value in row.items() if key in serializer().fields}
                      for row in records(profile, section)] if profile else []
            for section, serializer in SERIALIZERS.items()
        },
        "certifications": [], "extra_sections": [],
    }


def pdf_response(document, filename, *, download=False):
    response = HttpResponse(document, content_type="application/pdf")
    response["Content-Disposition"] = content_disposition_header(download, filename)
    response["Cache-Control"] = "private, no-store"
    response["Vary"] = "Authorization"
    response["X-Content-Type-Options"] = "nosniff"
    response["Content-Security-Policy"] = "sandbox"
    return response


class OwnCurriculumView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated, ProfileCandidatePermission]

    def handle_exception(self, exc):
        response = super().handle_exception(exc)
        if isinstance(exc, ValidationError):
            response.data = {"message": "Revisa los datos del currículum.", "errors": response.data}
        return response


class CurriculumView(OwnCurriculumView):
    def get(self, request):
        uploaded = UploadedCurriculum.objects.defer("document").filter(candidate=request.user).first()
        generated = GeneratedCurriculum.objects.filter(candidate=request.user).first()
        options = []
        if uploaded:
            options.append({"source": "uploaded", "label": uploaded.filename})
        if generated:
            options.append({"source": "generated", "label": "CV " + generated.get_template_display()})
        return Response({
            "uploaded": uploaded_data(uploaded),
            "generated": {"template": generated.template, "updated_at": generated.updated_at} if generated else None,
            "options": options,
            "limits": {"max_upload_bytes": MAX_UPLOAD_BYTES, "max_upload_pages": MAX_UPLOAD_PAGES},
        }, headers={"Cache-Control": "private, no-store", "Vary": "Authorization"})


class UploadedCurriculumView(OwnCurriculumView):
    parser_classes = [MultiPartParser]

    def get(self, request):
        curriculum = UploadedCurriculum.objects.filter(candidate=request.user).first()
        if curriculum is None:
            raise NotFound("Todavía no has subido un currículum.")
        return pdf_response(bytes(curriculum.document), curriculum.filename)

    @transaction.atomic
    def put(self, request):
        if set(request.data) != {"file"} or len(request.FILES.getlist("file")) != 1:
            raise ValidationError({"file": "Envía un único PDF en el campo file."})
        document, filename = validated_pdf(request.FILES["file"])
        curriculum, created = UploadedCurriculum.objects.update_or_create(
            candidate=request.user, defaults={"document": document, "filename": filename, "size_bytes": len(document)},
        )
        return Response({"uploaded": uploaded_data(curriculum)}, status=201 if created else 200)

    def delete(self, request):
        UploadedCurriculum.objects.filter(candidate=request.user).delete()
        return Response({"uploaded": None})


class GeneratedCurriculumView(OwnCurriculumView):
    def get(self, request):
        curriculum = GeneratedCurriculum.objects.filter(candidate=request.user).first()
        return Response({
            "exists": curriculum is not None,
            "curriculum": generated_data(curriculum) if curriculum else {
                "template": GeneratedCurriculum.Template.CLASSIC,
                "data": initial_data(request.user), "updated_at": None,
            },
        }, headers={"Cache-Control": "private, no-store", "Vary": "Authorization"})

    @transaction.atomic
    def put(self, request):
        serializer = GeneratedCurriculumSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        # Serializer.data convierte fechas a ISO antes de guardarlas en JSON.
        curriculum, created = GeneratedCurriculum.objects.update_or_create(candidate=request.user, defaults=serializer.data)
        return Response({"exists": True, "curriculum": generated_data(curriculum)}, status=201 if created else 200)

    @transaction.atomic
    def patch(self, request):
        curriculum = GeneratedCurriculum.objects.select_for_update().filter(candidate=request.user).first()
        if curriculum is None:
            raise NotFound("Guarda tu currículum antes de editarlo.")
        if not isinstance(request.data, dict) or not request.data:
            raise ValidationError({"message": "Envía la plantilla o los datos que quieres guardar."})
        serializer = GeneratedCurriculumSerializer(data={"template": curriculum.template, "data": curriculum.data, **request.data})
        serializer.is_valid(raise_exception=True)
        curriculum.template = serializer.data["template"]
        curriculum.data = serializer.data["data"]
        curriculum.save()
        return Response({"exists": True, "curriculum": generated_data(curriculum)})

    def delete(self, request):
        GeneratedCurriculum.objects.filter(candidate=request.user).delete()
        return Response({"exists": False})


class GeneratedCurriculumPdfView(OwnCurriculumView):
    def get(self, request):
        curriculum = GeneratedCurriculum.objects.filter(candidate=request.user).first()
        if curriculum is None:
            raise NotFound("Guarda tu currículum antes de descargarlo.")
        return pdf_response(render_curriculum(curriculum.template, curriculum.data), "curriculum.pdf", download=True)


class CurriculumPreviewView(OwnCurriculumView):
    def post(self, request):
        serializer = GeneratedCurriculumSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.data
        return pdf_response(render_curriculum(data["template"], data["data"]), "vista-previa.pdf")
