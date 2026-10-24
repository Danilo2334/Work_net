from django.urls import path

from .views import (
    CurriculumPreviewView, CurriculumView, GeneratedCurriculumPdfView,
    GeneratedCurriculumView, UploadedCurriculumView,
)


urlpatterns = [
    path("", CurriculumView.as_view(), name="curriculum"),
    path("uploaded/", UploadedCurriculumView.as_view(), name="uploaded-curriculum"),
    path("generated/", GeneratedCurriculumView.as_view(), name="generated-curriculum"),
    path("generated/pdf/", GeneratedCurriculumPdfView.as_view(), name="generated-curriculum-pdf"),
    path("generated/preview/", CurriculumPreviewView.as_view(), name="curriculum-preview"),
]
