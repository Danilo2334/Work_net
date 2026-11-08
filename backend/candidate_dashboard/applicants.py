"""HU020: candidatos y filtros del perfil actual, solo para ofertas propias."""
from django.db.models import Count, Exists, OuterRef
from django.db.models.functions import Lower
from rest_framework import serializers
from rest_framework.exceptions import NotFound, ValidationError
from rest_framework.response import Response

from .applications import application_data, offer_data
from .models import Application, JobOffer, visible_offers
from .selection import ApplicationProfileView
from .selection_text import normalized


class ApplicantParameters(serializers.Serializer):
    page = serializers.IntegerField(min_value=1, default=1)
    page_size = serializers.IntegerField(min_value=1, max_value=50, default=10)
    experience = serializers.CharField(max_length=100, allow_blank=True, default="")
    education = serializers.CharField(max_length=100, allow_blank=True, default="")
    skill = serializers.CharField(max_length=100, allow_blank=True, default="")
    order = serializers.ChoiceField(choices=("newest", "oldest", "name", "name_desc"), default="newest")

    def to_internal_value(self, data):
        errors = {}
        for key in data:
            if key not in self.fields:
                errors[key] = "Parámetro no permitido."
            elif len(data.getlist(key)) != 1:
                errors[key] = "Envía este parámetro una sola vez."
            elif key in ("page", "page_size") and (not data[key].isascii() or not data[key].isdigit()):
                errors[key] = "Envía un entero positivo."
            elif any(ord(c) < 32 or ord(c) == 127 for c in data[key]):
                errors[key] = "El filtro no admite caracteres de control."
        if errors:
            raise serializers.ValidationError(errors)
        return super().to_internal_value({key: data[key] for key in data})

    def validate(self, data):
        for key in ("experience", "education", "skill"):
            if data.get(key) and not normalized(data[key]):
                raise serializers.ValidationError({key: "Escribe un texto de búsqueda válido."})
        return data


class OfferSelectionParameters(ApplicantParameters):
    experience = education = skill = order = None


def paginated(query, params):
    page, size = params["page"], params["page_size"]
    count = query.count()
    pages = (count + size - 1) // size
    if page > max(1, pages):
        raise ValidationError({"page": "La página solicitada no existe."})
    return {"count": count, "page": page, "page_size": size, "total_pages": pages,
            "next_page": page + 1 if page < pages else None,
            "previous_page": page - 1 if page > 1 else None}, query[(page - 1) * size:page * size]


class CompanyApplicantOffersView(ApplicationProfileView):
    def get(self, request):
        params = OfferSelectionParameters(data=request.query_params)
        params.is_valid(raise_exception=True)
        query = JobOffer.objects.filter(company=request.user).annotate(applicant_count=Count("application")).order_by("-pk")
        meta, rows = paginated(query, params.validated_data)
        return Response({**meta, "offers": [{"id": o.pk, "title": o.title, "status": o.status,
                                            "applicants_count": o.applicant_count} for o in rows]},
                        headers={"Cache-Control": "private, no-store", "Vary": "Authorization"})


class CompanyOfferApplicantsView(ApplicationProfileView):
    def get(self, request, offer_id):
        offer = JobOffer.objects.filter(pk=offer_id, company=request.user).first()
        if offer is None:
            raise NotFound("No encontramos esa oferta entre las de tu empresa.")
        serializer = ApplicantParameters(data=request.query_params)
        serializer.is_valid(raise_exception=True)
        params = serializer.validated_data
        query = Application.objects.filter(offer=offer).select_related("offer", "candidate").defer("cv_document").annotate(
            available=Exists(visible_offers(JobOffer.objects.filter(pk=OuterRef("offer_id")))))
        for key, section in (("experience", "experience"), ("education", "education"), ("skill", "skills")):
            text = normalized(params[key])
            if text:
                query = query.filter(**{"candidate__candidateprofile__selection_" + section + "__contains": text})
        order = {"newest": ("-created_at", "-pk"), "oldest": ("created_at", "pk"),
                 "name": (Lower("candidate__full_name"), "candidate_id", "pk"),
                 "name_desc": (Lower("candidate__full_name").desc(), "-candidate_id", "-pk")}[params["order"]]
        meta, rows = paginated(query.order_by(*order), params)
        return Response({**meta, "offer": offer_data(offer), "filter_scope": "current_profile",
                         "applications": [{**application_data(item), "candidate": {
                             "id": item.candidate_id, "full_name": item.candidate.full_name}} for item in rows]},
                        headers={"Cache-Control": "private, no-store", "Vary": "Authorization"})
