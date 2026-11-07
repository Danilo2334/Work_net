"""Perfil profesional HU008 y actividad del resumen HU005."""

from django.conf import settings
from django.core.exceptions import ValidationError
from django.db import models, transaction
from django.db.models import Q
from django.utils import timezone


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


def lock_accepting_offers(offer_ids, using):
    """Comparte bloqueo de oferta con cierre/archivado, sin crear una API HU018."""
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
        if {"offer", "offer_id", "candidate", "candidate_id"} & kwargs.keys():
            raise ValidationError("No se pueden reasignar las relaciones de una postulación.")
        return super().update(**kwargs)


class Application(models.Model):
    candidate = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    offer = models.ForeignKey(JobOffer, on_delete=models.CASCADE)
    created_at = models.DateTimeField(auto_now_add=True)
    objects = ApplicationQuerySet.as_manager()

    def save(self, *args, **kwargs):
        using = kwargs.get("using") or self._state.db or "default"
        with transaction.atomic(using=using):
            if self._state.adding:
                lock_accepting_offers([self.offer_id], using)
            else:
                original = type(self).objects.using(using).filter(pk=self.pk).values("offer_id", "candidate_id").first()
                if original is None or original != {"offer_id": self.offer_id, "candidate_id": self.candidate_id}:
                    raise ValidationError("No se pueden reasignar las relaciones de una postulación.")
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


class Notification(models.Model):
    recipient = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    title = models.CharField(max_length=200)
    created_at = models.DateTimeField(auto_now_add=True)
    read_at = models.DateTimeField(null=True, blank=True)
