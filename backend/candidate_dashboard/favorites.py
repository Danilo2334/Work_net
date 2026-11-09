"""HU017: membresía idempotente sobre SavedOffer y su restricción existente."""
import time

from django.db import OperationalError, connection, transaction
from django.db.models import Exists, OuterRef
from django.utils import timezone
from rest_framework import serializers
from accounts.authentication import TokenAuthentication
from rest_framework.exceptions import APIException, NotFound, ValidationError
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import JobOffer, SavedOffer, visible_offers
from .profile import ProfileCandidatePermission


class FavoritePermission(ProfileCandidatePermission):
    message = "Guardados está disponible para candidatos autenticados con correo verificado."


class FavoritesView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated, FavoritePermission]

    def finalize_response(self, request, response, *args, **kwargs):
        response = super().finalize_response(request, response, *args, **kwargs)
        response["Cache-Control"] = "private, no-store"
        response["Vary"] = "Authorization"
        return response


class SavedPageParameters(serializers.Serializer):
    page = serializers.IntegerField(min_value=1, default=1)
    page_size = serializers.IntegerField(min_value=1, max_value=50, default=10)

    def to_internal_value(self, data):
        errors = {}
        for key in data:
            if key not in self.fields:
                errors[key] = "Parámetro no permitido."
            elif len(data.getlist(key)) != 1 or not data[key].isascii() or not data[key].isdigit():
                errors[key] = "Envía un entero positivo una sola vez."
        if errors:
            raise serializers.ValidationError(errors)
        return super().to_internal_value({key: data[key] for key in data})


class SavedOffersView(FavoritesView):
    http_method_names = ["get", "head", "options"]

    def get(self, request):
        params = SavedPageParameters(data=request.query_params)
        params.is_valid(raise_exception=True)
        page, size = params.validated_data["page"], params.validated_data["page_size"]
        now = timezone.now()
        saved = SavedOffer.objects.filter(candidate=request.user).select_related("offer").annotate(
            available=Exists(visible_offers(JobOffer.objects.filter(pk=OuterRef("offer_id")), at=now)),
        ).order_by("-created_at", "-pk")
        count = saved.count()
        pages = (count + size - 1) // size
        if page > max(1, pages):
            raise ValidationError({"page": "La página solicitada no existe."})
        rows = []
        for item in saved[(page - 1) * size:page * size]:
            offer = item.offer
            if item.available:
                availability = "active"
            elif offer.status in ("closed", "archived", "draft"):
                availability = offer.status
            elif offer.expires_at and offer.expires_at <= now:
                availability = "expired"
            else:
                availability = "unavailable"
            rows.append({"id": offer.pk, "title": offer.title, "company_name": offer.company_name,
                "location": offer.location, "contract_type": offer.contract_type, "category": offer.category,
                "salary": f"{offer.salary:.2f}" if offer.salary is not None else None,
                "published_at": offer.published_at, "status": offer.status, "availability": availability,
                "is_active": item.available, "is_saved": True, "saved_at": item.created_at})
        return Response({"count": count, "page": page, "page_size": size, "total_pages": pages,
            "next_page": page + 1 if page < pages else None, "previous_page": page - 1 if page > 1 else None,
            "offers": rows})


class FavoritesBusy(APIException):
    status_code = 503
    default_detail = "No pudimos sincronizar Guardados en este momento. Vuelve a intentarlo."


def set_saved(candidate, offer_id, wanted):
    # El bloqueo de oferta comparte orden con cierre/archivado en PostgreSQL.
    # SQLite no implementa SELECT FOR UPDATE: reintentar la transacción completa
    # cuando dos escritores compiten, conservando siempre el UNIQUE de la BD.
    deadline = time.monotonic() + 1.0
    for attempt in range(6):
        try:
            with transaction.atomic():
                offer = JobOffer.objects.select_for_update().filter(pk=offer_id).first()
                own = SavedOffer.objects.filter(candidate=candidate, offer_id=offer_id)
                if not wanted:
                    own.delete()
                    return False
                if own.exists():
                    return True  # Idempotencia incluso si ahora está inactiva.
                if offer is None or not visible_offers(JobOffer.objects.filter(pk=offer.pk)).exists():
                    raise NotFound("La oferta ya no está disponible para guardarla. Actualiza la búsqueda.")
                SavedOffer.objects.get_or_create(candidate=candidate, offer=offer)
                return True
        except OperationalError as exc:
            if connection.vendor != "sqlite" or not any(word in str(exc).lower() for word in ("locked", "busy")):
                raise
            if attempt == 5 or time.monotonic() >= deadline:
                raise FavoritesBusy() from exc
            time.sleep(0.01 * (attempt + 1))


class SavedOfferView(FavoritesView):
    http_method_names = ["put", "delete", "options"]

    def mutate(self, request, offer_id, wanted):
        if request.query_params or request.data != {}:
            raise ValidationError({"detail": "No envíes campos ni parámetros; el candidato procede de su sesión."})
        saved = set_saved(request.user, offer_id, wanted)
        return Response({"offer_id": offer_id, "is_saved": saved})

    def put(self, request, offer_id):
        return self.mutate(request, offer_id, True)

    def delete(self, request, offer_id):
        return self.mutate(request, offer_id, False)
