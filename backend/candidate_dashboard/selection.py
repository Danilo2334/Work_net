"""Lectura de perfiles limitada a postulaciones de la propia empresa."""
from rest_framework.authentication import TokenAuthentication
from rest_framework.exceptions import NotFound
from rest_framework.permissions import BasePermission, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.company import company_state, require_company
from accounts.models import CompanyProfile
from .models import Application, CandidateProfile
from .profile import payload, profile_photo_response


class ApprovedCompanyPermission(BasePermission):
    message = "Verifica tu correo y completa la aprobación de tu empresa para consultar postulantes."

    def has_permission(self, request, view):
        require_company(request.user)
        return request.user.email_verified and company_state(request.user) == CompanyProfile.State.APPROVED


class ApplicationProfileView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated, ApprovedCompanyPermission]
    http_method_names = ["get", "head", "options"]

    def application(self, request, application_id):
        application = Application.objects.select_related("candidate").filter(
            pk=application_id, offer__company=request.user,
        ).first()
        if application is None:
            raise NotFound("No encontramos esa postulación entre las ofertas de tu empresa.")
        return application

    def get(self, request, application_id):
        application = self.application(request, application_id)
        candidate = application.candidate
        profile = CandidateProfile.objects.filter(candidate=candidate).first()
        response = Response({
            "application": {"id": application.pk, "offer_id": application.offer_id},
            "candidate": {"id": candidate.pk, "full_name": candidate.full_name},
            **payload(candidate, profile),
        })
        response["Cache-Control"] = "private, no-store"
        response["Vary"] = "Authorization"
        return response


class ApplicationProfilePhotoView(ApplicationProfileView):
    def get(self, request, application_id):
        application = self.application(request, application_id)
        profile = CandidateProfile.objects.filter(candidate=application.candidate).first()
        if profile is None or not profile.photo_data:
            raise NotFound("El candidato no ha agregado una fotografía.")
        return profile_photo_response(profile.photo_data)
