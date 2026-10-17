"""Base persistente del resumen HU005; las APIs de escritura pertenecen a otras HU."""

from django.conf import settings
from django.db import models


class CandidateProfile(models.Model):
    candidate = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    professional_summary = models.TextField(blank=True)
    # Listas vacías representan secciones aún pendientes de completar.
    education = models.JSONField(default=list, blank=True)
    experience = models.JSONField(default=list, blank=True)
    skills = models.JSONField(default=list, blank=True)
    languages = models.JSONField(default=list, blank=True)


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
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.DRAFT)
    published_at = models.DateTimeField(null=True, blank=True, db_index=True)
    expires_at = models.DateTimeField(null=True, blank=True)


class Application(models.Model):
    candidate = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    offer = models.ForeignKey(JobOffer, on_delete=models.CASCADE)
    created_at = models.DateTimeField(auto_now_add=True)

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
