"""HU016: consultas públicas de ofertas, para candidatos autenticados."""
from decimal import Decimal
import re

from django.db.models import Case, IntegerField, Q, Value, When
from django.utils import timezone
from rest_framework import serializers
from rest_framework.authentication import TokenAuthentication
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.models import User
from .models import JobOffer, active_offers
from .offers import CATEGORIES, CONTRACT_TYPES
from .profile import ProfileCandidatePermission


class SearchParameters(serializers.Serializer):
    q = serializers.CharField(max_length=120, required=False, allow_blank=True, default="")
    location = serializers.CharField(max_length=200, required=False, allow_blank=True, default="")
    salary_min = serializers.DecimalField(max_digits=12, decimal_places=2, min_value=Decimal("0"), required=False)
    salary_max = serializers.DecimalField(max_digits=12, decimal_places=2, min_value=Decimal("0"), required=False)
    category = serializers.ChoiceField(choices=CATEGORIES, required=False)
    contract_type = serializers.ChoiceField(choices=CONTRACT_TYPES, required=False)
    sort = serializers.ChoiceField(choices=("relevance", "date"), default="relevance")
    page = serializers.IntegerField(min_value=1, default=1)
    page_size = serializers.IntegerField(min_value=1, max_value=50, default=10)

    def to_internal_value(self, data):
        errors = {key: "Parámetro no permitido." for key in data if key not in self.fields}
        for key in data:
            if len(data.getlist(key)) != 1:
                errors[key] = "Envía cada parámetro una sola vez."
            if key in ("page", "page_size") and not data.get(key, "").isascii():
                errors[key] = "Introduce un entero positivo."
            elif key in ("page", "page_size") and not data.get(key, "").isdigit():
                errors[key] = "Introduce un entero positivo."
        if errors:
            raise serializers.ValidationError(errors)
        # QueryDict es tratado como formulario HTML por DRF y omitiría vacíos.
        return super().to_internal_value({key: data[key] for key in data})

    def validate(self, data):
        # Un término repetido no altera la puntuación ni el conjunto.
        terms = {}
        for term in data["q"].split():
            terms.setdefault(term.casefold(), term)
        data["q"] = " ".join(terms.values())
        if len(data["q"].split()) > 8:
            raise serializers.ValidationError({"q": "Usa como máximo ocho palabras."})
        if data.get("salary_min", 0) > data.get("salary_max", Decimal("9999999999.99")):
            raise serializers.ValidationError({"salary_max": "El máximo debe ser mayor o igual al mínimo."})
        return data


class SearchCandidatePermission(ProfileCandidatePermission):
    message = "La búsqueda está disponible para candidatos autenticados con correo verificado."


class SearchOffersView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [IsAuthenticated, SearchCandidatePermission]
    http_method_names = ["get", "head", "options"]

    def finalize_response(self, request, response, *args, **kwargs):
        response = super().finalize_response(request, response, *args, **kwargs)
        response["Cache-Control"] = "private, no-store"
        response["Vary"] = "Authorization"
        return response

    def get(self, request):
        params = SearchParameters(data=request.query_params)
        params.is_valid(raise_exception=True)
        p = params.validated_data
        now = timezone.now()
        # Mismo dominio activo y visibilidad que el dashboard del candidato.
        offers = active_offers(JobOffer.objects.filter(
            published_at__lte=now, company__role=User.Role.EMPRESA,
            company__is_active=True,
        ), at=now)
        score = Value(0, output_field=IntegerField())
        for term in p["q"].split():
            match = Q()
            for field, weight in (("title", 4), ("requirements", 2), ("description", 2), ("company_name", 1)):
                # Patrón literal escapado: SQLite LIKE no compara mayúsculas
                # Unicode (É/é); Django REGEXP sí usa re.IGNORECASE Unicode.
                condition = Q(**{f"{field}__iregex": re.escape(term)})
                match |= condition
                score += Case(When(condition, then=Value(weight)), default=Value(0), output_field=IntegerField())
            offers = offers.filter(match)
        if p["location"]:
            offers = offers.filter(location__iregex=re.escape(p["location"]))
        for key, lookup in (("salary_min", "salary__gte"), ("salary_max", "salary__lte"),
                            ("category", "category"), ("contract_type", "contract_type")):
            if key in p:
                offers = offers.filter(**{lookup: p[key]})
        offers = offers.annotate(relevance=score)
        order = ["-published_at", "-pk"]
        if p["sort"] == "relevance":
            order.insert(0, "-relevance")
        offers = offers.order_by(*order)
        count = offers.count()
        pages = (count + p["page_size"] - 1) // p["page_size"]
        if p["page"] > max(1, pages):
            raise serializers.ValidationError({"page": "La página solicitada no existe."})
        start = (p["page"] - 1) * p["page_size"]
        rows = offers.values("id", "title", "company_name", "location", "contract_type", "category",
                             "salary", "published_at", "relevance")[start:start + p["page_size"]]
        data = [{**row, "salary": f'{row["salary"]:.2f}' if row["salary"] is not None else None} for row in rows]
        return Response({
            "count": count, "page": p["page"], "page_size": p["page_size"], "total_pages": pages,
            "next_page": p["page"] + 1 if p["page"] < pages else None,
            "previous_page": p["page"] - 1 if p["page"] > 1 else None,
            "categories": CATEGORIES, "contract_types": CONTRACT_TYPES, "offers": data,
        })
