"""HU018: postulación propia, copia privada del CV y aviso empresarial único."""
import hashlib
import time

from django.core.files.uploadedfile import SimpleUploadedFile
from django.core.exceptions import ValidationError as ModelValidationError
from django.db import OperationalError, connection, transaction
from django.db.models import Exists, OuterRef
from rest_framework import serializers
from rest_framework.exceptions import APIException, NotFound, ValidationError
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated

from accounts.account_configuration import StrictInputSerializer
from curriculum.models import GeneratedCurriculum, UploadedCurriculum
from curriculum.pdf import render_curriculum
from curriculum.serializers import GeneratedCurriculumSerializer
from curriculum.uploads import MAX_UPLOAD_BYTES, validated_pdf
from curriculum.views import pdf_response
from .favorites import FavoritesView, SavedPageParameters
from .models import Application, JobOffer, Notification, SavedOffer, visible_offers
from .selection import ApplicationProfileView
from .profile import ProfileCandidatePermission


class ApplicationPermission(ProfileCandidatePermission):
    message = "Las postulaciones están disponibles para candidatos autenticados con correo verificado."


class CandidateApplicationsView(FavoritesView):
    permission_classes = [IsAuthenticated, ApplicationPermission]


class ApplicationInput(StrictInputSerializer):
    cv_source = serializers.ChoiceField(choices=("uploaded", "generated"))
    cv_id = serializers.IntegerField(min_value=1)
    cv_revision = serializers.DateTimeField()
    confirm = serializers.BooleanField()

    def validate_confirm(self, value):
        if self.initial_data.get("confirm") is not True:
            raise serializers.ValidationError("Confirma el envío de esta postulación.")
        return value


class ApplicationsBusy(APIException):
    status_code = 503
    default_detail = "No pudimos confirmar la postulación. Consulta su estado antes de repetir el envío."


def no_query(request):
    if request.query_params:
        raise ValidationError({"detail": "Esta operación no admite parámetros."})


def offer_data(offer, *, active=None):
    return {"id": offer.pk, "title": offer.title, "company_name": offer.company_name,
            "location": offer.location, "contract_type": offer.contract_type,
            "status": offer.status,
            "is_active": visible_offers(JobOffer.objects.filter(pk=offer.pk)).exists() if active is None else active}


def application_data(item, *, offer=None):
    return {"id": item.pk, "offer": offer or offer_data(item.offer, active=getattr(item, "available", None)),
            "created_at": item.created_at, "status": item.status,
            "status_change": {"version": item.status_version, "modified_at": item.status_modified_at,
                              "comment": item.status_comment},
            "cv": {"source": item.cv_source, "source_id": item.cv_source_id,
                   "source_updated_at": item.cv_source_updated_at,
                   "filename": item.cv_filename, "template": item.cv_template,
                   "sha256": item.cv_sha256, "size_bytes": item.cv_size_bytes} if item.cv_source else None}


def cv_options(candidate):
    options = []
    for source, model in (("uploaded", UploadedCurriculum), ("generated", GeneratedCurriculum)):
        item = model.objects.defer("document").filter(candidate=candidate).first() if source == "uploaded" else model.objects.filter(candidate=candidate).first()
        if item:
            label = item.filename if source == "uploaded" else "CV " + item.get_template_display()
            options.append({"source": source, "id": item.pk, "revision": item.updated_at, "label": label})
    return options


def snapshot(candidate, data):
    source = data["cv_source"]
    model = UploadedCurriculum if source == "uploaded" else GeneratedCurriculum
    item = model.objects.select_for_update().filter(candidate=candidate, pk=data["cv_id"]).first()
    if item is None:
        raise ValidationError({"cv_id": "El CV elegido no está disponible en tu cuenta. Actualiza los datos."})
    if item.updated_at != data["cv_revision"]:
        raise ValidationError({"cv_revision": "El CV cambió desde que lo elegiste. Actualiza y revisa la nueva versión antes de enviarla."})
    if source == "uploaded":
        raw = bytes(item.document)
        if len(raw) != item.size_bytes:
            raise ValidationError({"cv_id": "El documento guardado no es válido. Reemplaza tu CV."})
        raw, filename = validated_pdf(SimpleUploadedFile(item.filename, raw, content_type="application/pdf"))
        template = ""
    else:
        valid = GeneratedCurriculumSerializer(data={"template": item.template, "data": item.data})
        valid.is_valid(raise_exception=True)
        raw = render_curriculum(valid.data["template"], valid.data["data"])
        filename, template = "curriculum-" + item.template + ".pdf", item.template
        if len(raw) > MAX_UPLOAD_BYTES:
            raise ValidationError({"cv_id": "El PDF generado es demasiado grande. Reduce su contenido."})
    return {"cv_source": source, "cv_source_id": item.pk, "cv_source_updated_at": item.updated_at,
            "cv_filename": filename, "cv_template": template, "cv_document": raw,
            "cv_sha256": hashlib.sha256(raw).hexdigest(), "cv_size_bytes": len(raw)}


def submit(candidate, offer_id, data):
    deadline = time.monotonic() + 1.0
    for attempt in range(6):
        try:
            with transaction.atomic():
                # Mismo bloqueo de oferta que HU015, sin invertir su orden con empresa.
                offer = JobOffer.objects.select_for_update().filter(pk=offer_id).first()
                if offer is None:
                    raise NotFound("No encontramos esa oferta.")
                existing = Application.objects.filter(candidate=candidate, offer=offer).first()
                if existing:
                    return existing, False  # Conserva CV/fecha/aviso incluso tras cierre o borrado de fuente.
                if not visible_offers(JobOffer.objects.filter(pk=offer_id)).exists():
                    raise NotFound("Esta oferta ya no está activa y no recibe nuevas postulaciones.")
                frozen = snapshot(candidate, data)
                if not visible_offers(JobOffer.objects.filter(pk=offer_id)).exists():
                    raise NotFound("Esta oferta ya no está activa y no recibe nuevas postulaciones.")
                # El UNIQUE existente y el bloqueo serializan envíos sobre PostgreSQL.
                try:
                    item = Application.objects.create(candidate=candidate, offer=offer, **frozen)
                except ModelValidationError as exc:
                    # El guard del modelo vuelve a comprobar vigencia al insertar.
                    raise NotFound("Esta oferta ya no está activa y no recibe nuevas postulaciones.") from exc
                from .notification_events import notify
                notify(application=item, event_kind="application_created", recipient_id=offer.company_id,
                    title=f"Nueva postulación: {candidate.full_name} · {offer.title}"[:200])
                return item, True
        except OperationalError as exc:
            if connection.vendor != "sqlite" or not any(w in str(exc).lower() for w in ("locked", "busy")):
                raise
            if attempt == 5 or time.monotonic() >= deadline:
                raise ApplicationsBusy() from exc
            time.sleep(0.01 * (attempt + 1))


class OfferApplicationView(CandidateApplicationsView):
    http_method_names = ["get", "post", "head", "options"]

    def get(self, request, offer_id):
        no_query(request)
        offer = JobOffer.objects.filter(pk=offer_id).first()
        if offer is None:
            raise NotFound("No encontramos esa oferta.")
        own = Application.objects.filter(candidate=request.user, offer=offer).first()
        summary = offer_data(offer)
        if not summary["is_active"] and own is None and not SavedOffer.objects.filter(candidate=request.user, offer=offer).exists():
            raise NotFound("Esta oferta ya no está activa y no recibe nuevas postulaciones.")
        return Response({"offer": summary, "candidate": {"full_name": request.user.full_name},
                         "cv_options": cv_options(request.user),
                         "application": application_data(own, offer=summary) if own else None})

    def post(self, request, offer_id):
        no_query(request)
        serializer = ApplicationInput(data=request.data)
        serializer.is_valid(raise_exception=True)
        item, created = submit(request.user, offer_id, serializer.validated_data)
        return Response({"created": created, "message": "Postulación enviada correctamente." if created else "Tu postulación ya estaba registrada.",
                         "application": application_data(item)}, status=201 if created else 200)


class ApplicationsView(CandidateApplicationsView):
    http_method_names = ["get", "head", "options"]

    def get(self, request):
        params = SavedPageParameters(data=request.query_params)
        params.is_valid(raise_exception=True)
        page, size = params.validated_data["page"], params.validated_data["page_size"]
        qs = Application.objects.filter(candidate=request.user).select_related("offer").defer("cv_document").annotate(
            available=Exists(visible_offers(JobOffer.objects.filter(pk=OuterRef("offer_id"))))).order_by("-created_at", "-pk")
        count = qs.count()
        pages = (count + size - 1) // size
        if page > max(1, pages):
            raise ValidationError({"page": "La página solicitada no existe."})
        return Response({"count": count, "page": page, "page_size": size, "total_pages": pages,
                         "next_page": page + 1 if page < pages else None,
                         "previous_page": page - 1 if page > 1 else None,
                         "applications": [application_data(item) for item in qs[(page-1)*size:page*size]]})


class OwnApplicationView(CandidateApplicationsView):
    http_method_names = ["get", "head", "options"]

    def application(self, request, application_id):
        no_query(request)
        item = Application.objects.select_related("offer").filter(pk=application_id, candidate=request.user).first()
        if item is None:
            raise NotFound("No encontramos esa postulación en tu cuenta.")
        return item

    def get(self, request, application_id):
        return Response({"application": application_data(self.application(request, application_id))})


def application_pdf(item):
    if not item.cv_source or not item.cv_document:
        raise NotFound("Esta postulación anterior no tiene un CV registrado.")
    return pdf_response(bytes(item.cv_document), item.cv_filename)


class OwnApplicationPdfView(OwnApplicationView):
    def get(self, request, application_id):
        return application_pdf(self.application(request, application_id))


class CompanyApplicationView(ApplicationProfileView):
    def get(self, request, application_id):
        no_query(request)
        item = self.application(request, application_id)
        return Response({"application": application_data(item),
                         "candidate": {"id": item.candidate_id, "full_name": item.candidate.full_name}},
                        headers={"Cache-Control": "private, no-store", "Vary": "Authorization"})


class CompanyApplicationPdfView(CompanyApplicationView):
    def get(self, request, application_id):
        no_query(request)
        return application_pdf(self.application(request, application_id))
