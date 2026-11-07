"""Publicación HU013 y edición HU014 de ofertas propias activas."""
from decimal import Decimal

from django.db import transaction
from django.utils import timezone
from rest_framework import serializers
from rest_framework.authentication import TokenAuthentication
from rest_framework.exceptions import APIException, NotFound, PermissionDenied, ValidationError
from rest_framework.pagination import PageNumberPagination
from rest_framework.permissions import BasePermission, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.company import require_company
from accounts.models import CompanyProfile
from .models import JobOffer, active_offers


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


def offer_data(offer):
    return {"id": offer.pk, **PublishOfferSerializer(offer).data,
            "company_name": offer.company_name, "status": offer.status,
            "published_at": offer.published_at, "expires_at": offer.expires_at}


class OfferNotEditable(APIException):
    status_code = 409
    default_detail = "La oferta ya no está activa y no se puede editar."


class EditCompanyPermission(PublishCompanyPermission):
    message = "Verifica tu correo y espera la aprobación de tu empresa para editar ofertas."


class ActiveOffersView(PublishOfferView):
    permission_classes = [IsAuthenticated, EditCompanyPermission]
    http_method_names = ["get", "head", "options"]

    def get(self, request):
        offers = active_offers(JobOffer.objects.filter(company=request.user)).order_by("-published_at", "-id")
        paginator = PageNumberPagination()
        paginator.page_size = 20
        page = paginator.paginate_queryset(offers, request, view=self)
        return Response({"count": paginator.page.paginator.count,
                         "next_page": paginator.page.next_page_number() if paginator.page.has_next() else None,
                         "previous_page": paginator.page.previous_page_number() if paginator.page.has_previous() else None,
                         "offers": [offer_data(offer) for offer in page]},
                        headers={"Cache-Control": "private, no-store", "Vary": "Authorization"})


class EditOfferView(PublishOfferView):
    permission_classes = [IsAuthenticated, EditCompanyPermission]
    http_method_names = ["get", "patch", "head", "options"]

    def own_offer(self, request, offer_id, *, lock=False):
        offers = JobOffer.objects.filter(company=request.user)
        if lock:
            offers = offers.select_for_update()
        offer = offers.filter(pk=offer_id).first()
        if offer is None:
            raise NotFound("No encontramos esa oferta entre las de tu empresa.")
        if not active_offers(offers.filter(pk=offer.pk)).exists():
            raise OfferNotEditable()
        return offer

    def get(self, request, offer_id):
        return Response({"offer": offer_data(self.own_offer(request, offer_id))},
                        headers={"Cache-Control": "private, no-store", "Vary": "Authorization"})

    @transaction.atomic
    def patch(self, request, offer_id):
        # Mismo orden de bloqueo que publicación/revisión empresarial.
        company = CompanyProfile.objects.select_for_update().filter(company=request.user).first()
        if company is None or company.state != CompanyProfile.State.APPROVED:
            raise PermissionDenied(EditCompanyPermission.message)
        offer = self.own_offer(request, offer_id, lock=True)
        if not isinstance(request.data, dict) or not request.data:
            raise ValidationError({"message": "Envía los campos que quieres modificar."})
        serializer = PublishOfferSerializer(data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        for field, value in serializer.validated_data.items():
            setattr(offer, field, value)
        offer.save(update_fields=list(serializer.validated_data))
        return Response({"message": "Cambios guardados correctamente.", "offer": offer_data(offer)},
                        headers={"Cache-Control": "private, no-store", "Vary": "Authorization"})
