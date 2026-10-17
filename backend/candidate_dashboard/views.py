from django.db.models import Q
from django.utils import timezone
from rest_framework import serializers
from rest_framework.authentication import TokenAuthentication
from rest_framework.permissions import BasePermission, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.models import User
from .models import Application, CandidateProfile, JobOffer, Notification, SavedOffer


class IsCandidate(BasePermission):
    message = "Este dashboard está disponible únicamente para candidatos."

    def has_permission(self, request, view):
        user = request.user
        return user.role == User.Role.CANDIDATO and not user.is_staff and not user.is_superuser


class RecentOfferSerializer(serializers.ModelSerializer):
    class Meta:
        model = JobOffer
        fields = ("id", "title", "company_name", "location", "contract_type", "published_at")


def profile_completion(user, profile):
    """Seis secciones, con igual peso. Foto y CV no son obligatorios para el perfil."""
    sections = {
        "basic_information": bool(user.full_name.strip() and user.email.strip()),
        "professional_summary": bool(profile and profile.professional_summary.strip()),
        "education": bool(profile and profile.education),
        "experience": bool(profile and profile.experience),
        "skills": bool(profile and profile.skills),
        "languages": bool(profile and profile.languages),
    }
    completed = sum(sections.values())
    return {
        "percentage": round(completed * 100 / len(sections)),
        "status": "complete" if completed == len(sections) else "incomplete",
        "completed_sections": completed,
        "total_sections": len(sections),
        "missing_sections": [key for key, value in sections.items() if not value],
    }


class CandidateDashboardView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated, IsCandidate]

    def get(self, request):
        user = request.user
        profile = CandidateProfile.objects.filter(candidate=user).first()
        now = timezone.now()
        offers = JobOffer.objects.filter(
            status=JobOffer.Status.PUBLISHED,
            published_at__lte=now,
            company__role=User.Role.EMPRESA,
            company__is_active=True,
        ).filter(Q(expires_at__isnull=True) | Q(expires_at__gt=now)).order_by("-published_at", "-pk")[:5]
        return Response({
            "user": {"id": user.pk, "full_name": user.full_name, "role": user.role},
            "profile_completion": profile_completion(user, profile),
            "metrics": {
                "applications_count": Application.objects.filter(candidate=user).count(),
                "saved_offers_count": SavedOffer.objects.filter(candidate=user).count(),
                "pending_notifications_count": Notification.objects.filter(recipient=user, read_at__isnull=True).count(),
            },
            "recent_jobs": RecentOfferSerializer(offers, many=True).data,
        })
