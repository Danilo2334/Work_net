"""HU021: transición confirmada, versionada e idempotente con aviso transaccional."""
import time
import unicodedata
from django.db import OperationalError, connection, transaction
from django.db.models import F
from django.utils import timezone
from rest_framework import serializers
from rest_framework.exceptions import APIException, NotFound, PermissionDenied, ValidationError
from rest_framework.response import Response
from accounts.account_configuration import StrictInputSerializer
from accounts.models import CompanyProfile, User
from .applications import application_data, no_query
from .models import Application, ApplicationStatusEvent, JobOffer, Notification
from .selection import ApplicationProfileView


TRANSITIONS = {"submitted": ["in_review", "accepted", "rejected"],
               "in_review": ["accepted", "rejected"], "accepted": [], "rejected": []}


class Conflict(APIException):
    status_code = 409
    default_detail = "Los datos cambiaron. Actualiza y revisa el resultado antes de confirmar."


class SelectionBusy(APIException):
    status_code = 503
    default_detail = "No pudimos completar la operación. Consulta su resultado antes de reintentar."


def retry_write(action):
    # Reintenta la transacción completa con la misma clave, nunca solo la notificación.
    for attempt in range(6):
        try:
            return action()
        except OperationalError as exc:
            if connection.vendor != "sqlite" or not any(t in str(exc).lower() for t in ("locked", "busy")):
                raise
            if attempt == 5:
                raise SelectionBusy() from exc
            time.sleep(.01 * (attempt + 1))


def clean_text(value, *, max_length, allow_empty=False):
    if isinstance(value, str):
        value = value.replace("\r\n", "\n")
    if not isinstance(value, str) or len(value) > max_length or any(
        unicodedata.category(c).startswith("C") and c not in "\n\t" for c in value
    ):
        raise ValidationError(f"Escribe texto válido de hasta {max_length} caracteres.")
    value = value.strip()
    if not value and not allow_empty:
        raise ValidationError("Escribe un mensaje de texto.")
    return value


class StatusInput(StrictInputSerializer):
    target_status = serializers.ChoiceField(choices=("in_review", "accepted", "rejected"))
    expected_version = serializers.IntegerField(min_value=0, max_value=2147483646)
    request_id = serializers.UUIDField()
    comment = serializers.CharField(max_length=2000, allow_blank=True, default="", trim_whitespace=False)
    confirm = serializers.BooleanField()

    def validate(self, data):
        if self.initial_data.get("confirm") is not True:
            raise ValidationError({"confirm": "Confirma el cambio de estado."})
        if type(self.initial_data.get("expected_version")) is not int:
            raise ValidationError({"expected_version": "Envía la versión entera consultada."})
        if not isinstance(self.initial_data.get("comment", ""), str):
            raise ValidationError({"comment": "Envía un comentario de texto."})
        data["comment"] = clean_text(data["comment"], max_length=2000, allow_empty=True)
        return data


def lock_company(user):
    # PostgreSQL: NO KEY UPDATE conserva KEY SHARE de las FK del aviso HU018.
    actor = User.objects.select_for_update(no_key=True).get(pk=user.pk)
    profile = CompanyProfile.objects.select_for_update().filter(company=actor).first()
    if actor.role != "empresa" or actor.is_staff or actor.is_superuser or not actor.is_active or not actor.email_verified or not profile or profile.state != "approved":
        raise PermissionDenied("La empresa necesita una cuenta verificada y aprobada.")
    return actor


def event_data(event):
    return {"request_id": str(event.request_id), "version": event.version,
            "from_status": event.from_status, "to_status": event.to_status,
            "comment": event.comment, "changed_at": event.changed_at}


def transition(user, application_id, data):
    def write():
        with transaction.atomic():
            actor = lock_company(user)
            offer_id = Application.objects.filter(pk=application_id, offer__company=actor).values_list("offer_id", flat=True).first()
            if offer_id is None:
                raise NotFound("No encontramos esa postulación entre tus ofertas.")
            offer = JobOffer.objects.select_for_update().get(pk=offer_id, company=actor)
            item = Application.objects.select_for_update().select_related("offer").filter(pk=application_id, offer=offer).first()
            if item is None:
                raise NotFound("No encontramos esa postulación.")
            existing = ApplicationStatusEvent.objects.filter(application=item, request_id=data["request_id"]).first()
            if existing:
                if (existing.actor_id, existing.to_status, existing.comment, existing.version - 1) != (
                    actor.pk, data["target_status"], data["comment"], data["expected_version"]
                ):
                    raise Conflict("Esta clave ya corresponde a otro cambio. Consulta el resultado original.")
                return item, existing, True
            if item.status_version != data["expected_version"]:
                raise Conflict()
            if data["target_status"] not in TRANSITIONS.get(item.status, []):
                raise Conflict("Esta transición no está permitida. Repetir el estado no modifica comentarios, fechas ni avisos.")
            changed_at = timezone.now()
            changed = Application.objects.filter(pk=item.pk, status_version=data["expected_version"], status=item.status).update(
                status=data["target_status"], status_version=F("status_version") + 1,
                status_modified_at=changed_at, status_comment=data["comment"])
            if changed != 1:
                raise Conflict()
            event = ApplicationStatusEvent.objects.create(application=item, actor=actor,
                request_id=data["request_id"], version=item.status_version + 1,
                from_status=item.status, to_status=data["target_status"], comment=data["comment"], changed_at=changed_at)
            label = Application.Status(data["target_status"]).label
            Notification.objects.create(application=item, event_kind="application_status_changed", status_event=event,
                recipient_id=item.candidate_id, title=f"{offer.company_name}: {label} · {offer.title}"[:200])
            item.refresh_from_db()
            return item, event, False
    return retry_write(write)


class ApplicationStatusView(ApplicationProfileView):
    http_method_names = ["get", "post", "head", "options"]

    def get(self, request, application_id):
        no_query(request)
        item = self.application(request, application_id)
        return Response({"application": application_data(item), "allowed_transitions": TRANSITIONS.get(item.status, [])})

    def post(self, request, application_id):
        no_query(request)
        data = StatusInput(data=request.data);data.is_valid(raise_exception=True)
        item, event, replayed = transition(request.user, application_id, data.validated_data)
        return Response({"application": application_data(item), "event": event_data(event), "replayed": replayed,
                         "allowed_transitions": TRANSITIONS.get(item.status, [])})

    def finalize_response(self, request, response, *args, **kwargs):
        response = super().finalize_response(request, response, *args, **kwargs)
        response["Cache-Control"] = "private, no-store";response["Vary"] = "Authorization"
        return response


class ApplicationStatusOperationView(ApplicationStatusView):
    http_method_names = ["get", "head", "options"]

    def get(self, request, application_id, request_id):
        no_query(request)
        item = self.application(request, application_id)
        event = ApplicationStatusEvent.objects.filter(application=item, request_id=request_id).first()
        if event is None:
            raise NotFound("Este cambio todavía no está registrado. Puedes reintentar con la misma clave.")
        return Response({"application": application_data(item), "event": event_data(event), "replayed": True,
                         "allowed_transitions": TRANSITIONS.get(item.status, [])})
