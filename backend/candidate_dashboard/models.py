"""Perfil profesional HU008 y actividad del resumen HU005."""

from django.conf import settings
from django.core.exceptions import ValidationError
from django.db import models, transaction
from django.db.models import Q
from django.utils import timezone
from .selection_text import SELECTION_SECTIONS, populate_selection, selection_text


class CandidateProfileQuerySet(models.QuerySet):
    def update(self, **kwargs):
        if set(kwargs) & {"selection_" + s for s in SELECTION_SECTIONS}:
            raise ValidationError("Las proyecciones se derivan del perfil; no se modifican directamente.")
        for section in SELECTION_SECTIONS:
            if section in kwargs:
                if not isinstance(kwargs[section], list):
                    raise ValidationError("Actualiza las secciones estructuradas mediante save, sin expresiones masivas.")
                kwargs["selection_" + section] = selection_text(kwargs[section], section)
        return super().update(**kwargs)

    def bulk_create(self, objs, **kwargs):
        objs = list(objs)
        for obj in objs:
            populate_selection(obj)
        if kwargs.get("update_conflicts"):
            raise ValidationError("No se sobrescriben perfiles mediante inserción masiva.")
        return super().bulk_create(objs, **kwargs)

    def bulk_update(self, objs, fields, **kwargs):
        if set(fields) & {*SELECTION_SECTIONS, *("selection_" + s for s in SELECTION_SECTIONS)}:
            raise ValidationError("Actualiza las secciones estructuradas mediante save para conservar los filtros.")
        return super().bulk_update(objs, fields, **kwargs)


class CandidateProfile(models.Model):
    candidate = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    professional_summary = models.TextField(blank=True)
    # Listas vacías representan secciones aún pendientes de completar.
    education = models.JSONField(default=list, blank=True)
    experience = models.JSONField(default=list, blank=True)
    skills = models.JSONField(default=list, blank=True)
    languages = models.JSONField(default=list, blank=True)
    # Private bytes: never published through MEDIA_URL or an unprotected file URL.
    photo_data = models.BinaryField(default=bytes, blank=True, editable=False)
    selection_experience = models.TextField(default="", blank=True, editable=False)
    selection_education = models.TextField(default="", blank=True, editable=False)
    selection_skills = models.TextField(default="", blank=True, editable=False)
    objects = CandidateProfileQuerySet.as_manager()

    def save(self, *args, **kwargs):
        populate_selection(self)
        if kwargs.get("update_fields") is not None:
            fields = set(kwargs["update_fields"])
            fields.update("selection_" + s for s in SELECTION_SECTIONS if s in fields)
            kwargs["update_fields"] = fields
        return super().save(*args, **kwargs)


class JobOffer(models.Model):
    class Status(models.TextChoices):
        DRAFT = "draft", "Borrador"
        PUBLISHED = "published", "Publicada"
        CLOSED = "closed", "Cerrada"
        ARCHIVED = "archived", "Archivada"

    company = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    title = models.CharField(max_length=200)
    company_name = models.CharField(max_length=200)
    location = models.CharField(max_length=200)
    contract_type = models.CharField(max_length=100)
    description = models.TextField(blank=True)
    requirements = models.TextField(blank=True)
    salary = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)
    category = models.CharField(max_length=100, blank=True)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.DRAFT)
    published_at = models.DateTimeField(null=True, blank=True, db_index=True)
    expires_at = models.DateTimeField(null=True, blank=True)


def active_offers(queryset, *, at=None):
    """Oferta publicada y no vencida: consultas activas y nuevas postulaciones."""
    return queryset.filter(status=JobOffer.Status.PUBLISHED).filter(
        Q(expires_at__isnull=True) | Q(expires_at__gt=at or timezone.now())
    )


def visible_offers(queryset, *, at=None):
    """Visibilidad candidata compartida por dashboard, búsqueda y favoritos."""
    now = at or timezone.now()
    return active_offers(queryset.filter(
        published_at__lte=now, company__role="empresa", company__is_active=True,
    ), at=now)


def lock_accepting_offers(offer_ids, using):
    """Comparte bloqueo de oferta con cierre/archivado."""
    ids = set(offer_ids)
    locked = list(JobOffer.objects.using(using).select_for_update().filter(pk__in=ids).order_by("pk"))
    accepting = set(active_offers(JobOffer.objects.using(using).filter(pk__in=[o.pk for o in locked])).values_list("pk", flat=True))
    if accepting != ids:
        raise ValidationError("La oferta no está activa y no recibe nuevas postulaciones.")


class ApplicationQuerySet(models.QuerySet):
    def bulk_create(self, objs, batch_size=None, ignore_conflicts=False,
                    update_conflicts=False, update_fields=None, unique_fields=None):
        if update_conflicts:
            raise ValidationError("No se pueden sobrescribir postulaciones existentes mediante inserción masiva.")
        objs = list(objs)
        with transaction.atomic(using=self.db):
            lock_accepting_offers([o.offer_id for o in objs], self.db)
            return super().bulk_create(objs, batch_size=batch_size, ignore_conflicts=ignore_conflicts,
                                       update_conflicts=False, update_fields=update_fields, unique_fields=unique_fields)

    def update(self, **kwargs):
        if set(APPLICATION_IMMUTABLE_FIELDS) & kwargs.keys():
            raise ValidationError("No se pueden modificar las relaciones, fecha ni el CV enviado de una postulación.")
        return super().update(**kwargs)


APPLICATION_IMMUTABLE_FIELDS = (
    "candidate", "candidate_id", "offer", "offer_id", "created_at",
    "cv_source", "cv_source_id", "cv_source_updated_at", "cv_filename",
    "cv_template", "cv_sha256", "cv_document",
    "cv_size_bytes",
)


class Application(models.Model):
    class Status(models.TextChoices):
        SUBMITTED = "submitted", "Enviada"
        IN_REVIEW = "in_review", "En revisión"
        ACCEPTED = "accepted", "Aceptada"
        REJECTED = "rejected", "Rechazada"

    candidate = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    offer = models.ForeignKey(JobOffer, on_delete=models.CASCADE)
    created_at = models.DateTimeField(auto_now_add=True)
    status = models.CharField(max_length=20, default=Status.SUBMITTED, choices=Status.choices)
    status_version = models.PositiveIntegerField(default=0)
    status_modified_at = models.DateTimeField(null=True, blank=True)
    status_comment = models.TextField(blank=True, default="")
    # Los registros históricos conservan CV vacío: no se les inventa un documento.
    cv_source = models.CharField(max_length=12, blank=True, default="", choices=[("uploaded", "Subido"), ("generated", "Generado")])
    cv_source_id = models.PositiveBigIntegerField(null=True, blank=True)
    cv_source_updated_at = models.DateTimeField(null=True, blank=True)
    cv_filename = models.CharField(max_length=150, blank=True, default="")
    cv_template = models.CharField(max_length=12, blank=True, default="")
    cv_sha256 = models.CharField(max_length=64, blank=True, default="")
    cv_document = models.BinaryField(default=bytes, blank=True, editable=False)
    cv_size_bytes = models.PositiveIntegerField(default=0)
    objects = ApplicationQuerySet.as_manager()

    def save(self, *args, **kwargs):
        using = kwargs.get("using") or self._state.db or "default"
        with transaction.atomic(using=using):
            if self._state.adding:
                lock_accepting_offers([self.offer_id], using)
            else:
                fields = [f for f in APPLICATION_IMMUTABLE_FIELDS if f not in ("candidate", "offer")]
                original = type(self).objects.using(using).filter(pk=self.pk).values(*fields).first()
                if original is None or any(original[f] != getattr(self, f) for f in fields):
                    raise ValidationError("No se pueden modificar las relaciones, fecha ni el CV enviado de una postulación.")
            return super().save(*args, **kwargs)

    class Meta:
        constraints = [models.UniqueConstraint(
            fields=["candidate", "offer"], name="dashboard_unique_application",
        )]


class SavedOffer(models.Model):
    candidate = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    offer = models.ForeignKey(JobOffer, on_delete=models.CASCADE)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [models.UniqueConstraint(
            fields=["candidate", "offer"], name="dashboard_unique_saved_offer",
        )]


class ImmutableEventQuerySet(models.QuerySet):
    def bulk_create(self, objs, **kwargs):
        if kwargs.get("update_conflicts"):
            raise ValidationError("Los eventos registrados no se sobrescriben mediante upsert.")
        return super().bulk_create(objs, **kwargs)

    def update(self, **kwargs):
        raise ValidationError("Los eventos registrados no se modifican.")

    def bulk_update(self, *args, **kwargs):
        raise ValidationError("Los eventos registrados no se modifican.")


class ApplicationStatusEvent(models.Model):
    application = models.ForeignKey(Application, on_delete=models.CASCADE, related_name="status_events")
    actor = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True)
    request_id = models.UUIDField()
    version = models.PositiveIntegerField()
    from_status = models.CharField(max_length=20, choices=Application.Status.choices)
    to_status = models.CharField(max_length=20, choices=Application.Status.choices)
    comment = models.TextField(blank=True)
    changed_at = models.DateTimeField()
    objects = ImmutableEventQuerySet.as_manager()

    def save(self, *args, **kwargs):
        if not self._state.adding or kwargs.get("force_update") or kwargs.get("update_fields"):
            raise ValidationError("Los eventos registrados no se modifican.")
        kwargs["force_insert"] = True
        return super().save(*args, **kwargs)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["application", "request_id"], name="unique_application_status_request"),
            models.UniqueConstraint(fields=["application", "version"], name="unique_application_status_version"),
        ]


class Notification(models.Model):
    application = models.ForeignKey(Application, on_delete=models.CASCADE, null=True, blank=True, related_name="notifications")
    event_kind = models.CharField(max_length=32, default="legacy", choices=[
        ("legacy", "Aviso existente"), ("application_created", "Nueva postulación"),
        ("application_status_changed", "Cambio de estado"),
    ])
    status_event = models.OneToOneField(ApplicationStatusEvent, on_delete=models.CASCADE, null=True, blank=True, related_name="notification")
    recipient = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    title = models.CharField(max_length=200)
    created_at = models.DateTimeField(auto_now_add=True)
    read_at = models.DateTimeField(null=True, blank=True)

    def save(self, *args, **kwargs):
        # Compatibilidad con altas internas anteriores; HU018 escribe el tipo explícito.
        if self._state.adding and self.application_id and self.event_kind == "legacy" and not self.status_event_id:
            self.event_kind = "application_created"
        return super().save(*args, **kwargs)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["application"], condition=Q(event_kind="application_created"), name="unique_application_created_notice"),
            models.CheckConstraint(condition=(
                Q(event_kind="legacy", application__isnull=True, status_event__isnull=True)
                | Q(event_kind="application_created", application__isnull=False, status_event__isnull=True)
                | Q(event_kind="application_status_changed", application__isnull=False, status_event__isnull=False)
            ), name="notification_event_context"),
        ]


class Conversation(models.Model):
    application = models.OneToOneField(Application, on_delete=models.CASCADE, related_name="conversation")
    created_at = models.DateTimeField(auto_now_add=True)
    last_activity_at = models.DateTimeField(default=timezone.now, db_index=True)


class Message(models.Model):
    conversation = models.ForeignKey(Conversation, on_delete=models.CASCADE, related_name="messages")
    sender = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="selection_sent_messages")
    recipient = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="selection_received_messages")
    client_message_id = models.UUIDField()
    text = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)
    read_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["conversation", "sender", "client_message_id"], name="unique_selection_message_intent"),
            models.CheckConstraint(condition=~Q(sender=models.F("recipient")), name="selection_message_distinct_parties"),
        ]
        indexes = [models.Index(fields=["conversation", "recipient", "read_at"], name="selection_unread_messages")]
