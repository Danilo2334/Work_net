"""HU024: conteos completos del titular; la paginación solo afecta al detalle."""
from django.db import transaction
from django.db.models import Count, Exists, OuterRef, Q
from django.utils import timezone
from rest_framework.response import Response

from .applications import CandidateApplicationsView, no_query
from .applicants import OfferSelectionParameters, paginated
from .favorites import FavoritesView
from .models import Application, JobOffer, active_offers
from .selection import ApprovedCompanyPermission
from rest_framework.permissions import IsAuthenticated


STATES = tuple(Application.Status.values)


def counts(*, relation=""):
    field = relation + "status"
    return {
        "applications_count": Count(relation + "pk"),
        **{state: Count(relation + "pk", filter=Q(**{field: state})) for state in STATES},
        "other": Count(relation + "pk", filter=~Q(**{field + "__in": STATES})),
    }


def states(data):
    return {key: data[key] for key in (*STATES, "other")}


class CandidateStatisticsView(CandidateApplicationsView):
    http_method_names = ["get", "head", "options"]

    @transaction.atomic
    def get(self, request):
        no_query(request)
        totals = Application.objects.filter(candidate=request.user).aggregate(**counts())
        return Response({"role": "candidato", "as_of": timezone.now(),
                         "scope": "all_persisted_applications", "applications_count": totals["applications_count"],
                         "states": states(totals)})


class CompanyStatisticsView(FavoritesView):
    permission_classes = [IsAuthenticated, ApprovedCompanyPermission]
    http_method_names = ["get", "head", "options"]

    @transaction.atomic
    def get(self, request):
        params = OfferSelectionParameters(data=request.query_params)
        params.is_valid(raise_exception=True)
        now = timezone.now()
        own_offers = JobOffer.objects.filter(company=request.user)
        totals = Application.objects.filter(offer__company=request.user).aggregate(**counts())
        active = active_offers(own_offers, at=now)
        query = own_offers.values("id", "title", "status").annotate(**counts(relation="application__"),
                                   is_active=Exists(active.filter(pk=OuterRef("pk")))).order_by("-pk")
        meta, rows = paginated(query, params.validated_data)
        # values() evita cargar descripciones y cualquier dato de candidatos/CV.
        rows = rows.values("id", "title", "status", "is_active", "applications_count", *STATES, "other")
        return Response({"role": "empresa", "as_of": now, "scope": "all_persisted_applications",
                         "applications_count": totals["applications_count"], "states": states(totals),
                         "active_offers_count": active.count(), "offers": {
                             **meta, "rows": [{"id": row["id"], "title": row["title"], "status": row["status"],
                                              "is_active": row["is_active"], "applications_count": row["applications_count"],
                                              "states": states(row)} for row in rows]}})
