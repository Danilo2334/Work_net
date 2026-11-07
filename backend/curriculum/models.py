from django.conf import settings
from django.db import models


class UploadedCurriculum(models.Model):
    candidate = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    filename = models.CharField(max_length=150)
    size_bytes = models.PositiveIntegerField()
    document = models.BinaryField(editable=False)
    updated_at = models.DateTimeField(auto_now=True)


class GeneratedCurriculum(models.Model):
    class Template(models.TextChoices):
        CLASSIC = "clasica", "Clásica"
        MODERN = "moderna", "Moderna"
        MINIMAL = "minimalista", "Minimalista"

    candidate = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    template = models.CharField(max_length=12, choices=Template.choices, default=Template.CLASSIC)
    data = models.JSONField(default=dict)
    updated_at = models.DateTimeField(auto_now=True)
