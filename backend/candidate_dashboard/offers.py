"""HU013: publicación directa por empresas aprobadas, sin gestión HU014."""
from decimal import Decimal

from django.db import transaction
from django.utils import timezone
from rest_framework import serializers
from rest_framework.authentication import TokenAuthentication
from rest_framework.exceptions import PermissionDenied
from rest_framework.permissions import BasePermission, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.company import require_company
from accounts.models import CompanyProfile
from .models import JobOffer


CATEGORIES = ("Tecnología", "Administración", "Ventas", "Operaciones", "Salud", "Educación", "Otros")
CONTRACT_TYPES = ("Indefinido", "Fijo", "Prestación de servicios", "Obra o labor", "Aprendizaje", "Otro")


class PublishCompanyPermission(BasePermission):
    message = "Verifica tu correo y espera la aprobación de tu empresa para publicar ofertas."

    def has_permission(self, request, view):
        require_company(request.user)
        return request.user.email_verified and CompanyProfile.objects.filter(
            company=request.user, state=CompanyProfile.State.APPROVED,
        ).exists()


class PublishOfferSerializer(serializers.Serializer):
    title = serializers.CharField(max_length=200)
    description = serializers.CharField(max_length=10000)
    requirements = serializers.CharField(max_length=10000)
    salary = serializers.DecimalField(max_digits=12, decimal_places=2, min_value=Decimal("0"))
    location = serializers.CharField(max_length=200)
    category = serializers.ChoiceField(choices=CATEGORIES)
    contract_type = serializers.ChoiceField(choices=CONTRACT_TYPES)

    def to_internal_value(self, data):
        # Nunca ignorar silenciosamente intentos de fijar propietario o estado.
        if isinstance(data, dict):
            unknown = set(data) - set(self.fields)
            if unknown:
                raise serializers.ValidationError({k: "Campo no permitido." for k in sorted(unknown)})
        return super().to_internal_value(data)


class PublishOfferView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated, PublishCompanyPermission]
    http_method_names = ["get", "post", "head", "options"]

    def get(self, request):
        return Response({"categories": CATEGORIES, "contract_types": CONTRACT_TYPES})

    @transaction.atomic
    def post(self, request):
        serializer = PublishOfferSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        # La revisión de empresa usa esta misma fila; serializar aprobación/publicación.
        company = CompanyProfile.objects.select_for_update().get(company=request.user)
        if company.state != CompanyProfile.State.APPROVED:
            raise PermissionDenied(PublishCompanyPermission.message)
        offer = JobOffer.objects.create(
            **serializer.validated_data, company=request.user,
            company_name=company.legal_name, status=JobOffer.Status.PUBLISHED,
            published_at=timezone.now(),
        )
        return Response({
            "message": "Oferta publicada correctamente.",
            "offer": {"id": offer.pk, **serializer.data, "company_name": offer.company_name,
                      "status": offer.status, "published_at": offer.published_at},
        }, status=201)
