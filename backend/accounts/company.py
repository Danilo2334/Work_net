"""HU009/HU010: owner submission, administrator decision and scoped summaries."""
import re

from django.db import IntegrityError, transaction
from django.db.models import F, Q
from django.utils import timezone
from django.http import HttpResponse
from rest_framework.parsers import MultiPartParser
from rest_framework import serializers
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from candidate_dashboard.models import Application, JobOffer, Notification
from candidate_dashboard.profile import validated_photo
from .models import CompanyProfile, CompanyReview, User


def administrator(user):
    return user.is_staff or user.is_superuser


def require_company(user):
    if administrator(user) or user.role != User.Role.EMPRESA:
        raise PermissionDenied("Este espacio corresponde a una cuenta de empresa.")


def require_admin(user):
    if not administrator(user):
        raise PermissionDenied("Solo un administrador puede revisar solicitudes.")


def company_state(user):
    profile = CompanyProfile.objects.filter(company=user).first()
    return profile.state if profile else CompanyProfile.State.PENDING


def profile_data(profile):
    fields = ("legal_name", "tax_id", "sector", "location", "contact_email", "description", "website")
    return {
        **{key: getattr(profile, key, "") for key in fields},
        "id": profile.pk if profile else None,
        "state": profile.state if profile else CompanyProfile.State.PENDING,
        "submitted": bool(profile and profile.submitted_at),
        "rejection_reason": profile.rejection_reason if profile else "",
        "version": profile.version if profile else 0,
        "reviewed_by": profile.reviewed_by_id if profile else None,
        "reviewed_at": profile.reviewed_at if profile else None,
        "social_links": profile.social_links if profile else [],
        "has_logo": bool(profile and profile.logo_data),
    }


class CompanySerializer(serializers.ModelSerializer):
    social_links = serializers.ListField(child=serializers.URLField(), max_length=10, required=False)
    class Meta:
        model = CompanyProfile
        fields = ("legal_name", "tax_id", "sector", "location", "contact_email", "description", "website", "social_links")
        extra_kwargs = {name: {"allow_blank": False, "required": True} for name in fields if name not in ("website", "social_links")}

    def to_internal_value(self, data):
        extra = set(data) - set(self.fields)
        if extra:
            raise serializers.ValidationError({key: "Este campo no se puede modificar." for key in extra})
        return super().to_internal_value(data)

    def validate_tax_id(self, value):
        value = value.strip()
        if not re.fullmatch(r"\d{6,15}(?:-\d)?", value):
            raise serializers.ValidationError("Escribe un NIT válido, con dígito de verificación si corresponde.")
        existing = CompanyProfile.objects.filter(tax_id=value)
        if self.instance:
            existing = existing.exclude(pk=self.instance.pk)
        if existing.exists():
            raise serializers.ValidationError("Este NIT ya está asociado a otra cuenta empresarial.")
        return value


def notices(user):
    return list(Notification.objects.filter(recipient=user).order_by("-created_at", "-id").values("id", "title", "read_at", "created_at")[:10])


class CompanyView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        require_company(request.user)
        return Response({"company": profile_data(CompanyProfile.objects.filter(company=request.user).first()), "notifications": notices(request.user)})

    @transaction.atomic
    def patch(self, request):
        require_company(request.user)
        profile, _ = CompanyProfile.objects.get_or_create(company=request.user)
        profile = CompanyProfile.objects.select_for_update().get(pk=profile.pk)
        if profile.state == CompanyProfile.State.APPROVED:
            if set(request.data) - {"website", "social_links"}:
                raise ValidationError({"message": "Los datos aprobados están protegidos. Puedes actualizar el sitio web."})
        elif profile.state == CompanyProfile.State.PENDING and profile.submitted_at:
            raise ValidationError({"message": "Tu solicitud está en revisión. Espera el resultado antes de editarla."})
        serializer = CompanySerializer(profile, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        try:
            with transaction.atomic():
                serializer.save(version=profile.version + 1)
        except IntegrityError:
            raise ValidationError({"tax_id": "Este NIT ya está asociado a otra cuenta empresarial."})
        return Response({"company": profile_data(serializer.instance)})


class SubmitCompanyView(APIView):
    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def post(self, request):
        require_company(request.user)
        profile, _ = CompanyProfile.objects.get_or_create(company=request.user)
        profile = CompanyProfile.objects.select_for_update().get(pk=profile.pk)
        if profile.state == CompanyProfile.State.APPROVED or (profile.state == CompanyProfile.State.PENDING and profile.submitted_at):
            raise ValidationError({"message": "Esta solicitud ya fue enviada o aprobada."})
        serializer = CompanySerializer(profile, data={key: getattr(profile, key) for key in CompanySerializer.Meta.fields})
        serializer.is_valid(raise_exception=True)
        profile.state = CompanyProfile.State.PENDING
        profile.submitted_at = timezone.now()
        profile.rejection_reason = ""
        profile.reviewed_at = None
        profile.reviewed_by = None
        profile.version += 1
        profile.save()
        CompanyReview.objects.create(profile=profile, actor=request.user, action="submitted", snapshot=serializer.validated_data)
        Notification.objects.bulk_create([
            Notification(recipient=admin, title=f"Nueva solicitud de empresa: {profile.legal_name}")
            for admin in User.objects.filter(Q(is_staff=True) | Q(is_superuser=True), is_active=True)
        ])
        return Response({"company": profile_data(profile), "message": "Solicitud enviada. Un administrador revisará tu información."})


class CompanyLogoView(APIView):
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser]

    def profile(self, request):
        require_company(request.user)
        profile = CompanyProfile.objects.filter(company=request.user, state="approved").first()
        if not profile:
            raise PermissionDenied("El logo se puede completar después de la aprobación.")
        return profile

    def get(self, request):
        profile = self.profile(request)
        if not profile.logo_data:
            return Response({"message": "Todavía no agregaste un logo."}, status=404)
        response = HttpResponse(bytes(profile.logo_data), content_type="image/jpeg")
        response["Cache-Control"] = "private, no-store"
        response["Vary"] = "Authorization"
        response["X-Content-Type-Options"] = "nosniff"
        return response

    def put(self, request):
        profile = self.profile(request)
        if set(request.data) != {"photo"} or len(request.FILES.getlist("photo")) != 1:
            raise ValidationError({"photo": "Envía un único logo JPEG o PNG."})
        profile.logo_data = validated_photo(request.FILES["photo"])
        profile.save(update_fields=["logo_data"])
        return Response({"company": profile_data(profile)})

    def delete(self, request):
        profile = self.profile(request)
        profile.logo_data = b""
        profile.save(update_fields=["logo_data"])
        return Response({"company": profile_data(profile)})


class PendingCompaniesView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        require_admin(request.user)
        try:
            page = max(1, int(request.query_params.get("page", 1)))
        except (TypeError, ValueError):
            raise ValidationError({"page": "Página no válida."})
        rows = CompanyProfile.objects.filter(state="pending", submitted_at__isnull=False).order_by("submitted_at", "id")
        return Response({"companies": [profile_data(p) for p in rows[(page-1)*20:page*20]], "count": rows.count(), "page": page, "has_next": rows.count() > page*20})


class ReviewCompanyView(APIView):
    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def post(self, request, pk):
        require_admin(request.user)
        action = request.data.get("decision")
        reason = request.data.get("reason", "")
        version = request.data.get("version")
        if action not in ("approved", "rejected") or type(version) is not int:
            raise ValidationError({"message": "Indica una decisión válida y la versión de la solicitud."})
        if not isinstance(reason, str) or len(reason) > 2000 or (action == "rejected" and not reason.strip()):
            raise ValidationError({"reason": "Para rechazar, escribe un motivo de hasta 2000 caracteres."})
        profile = CompanyProfile.objects.select_for_update().filter(pk=pk).first()
        if not profile:
            return Response({"message": "Solicitud no encontrada."}, status=404)
        changed = CompanyProfile.objects.filter(pk=pk, state="pending", submitted_at__isnull=False, version=version).update(
            state=action, rejection_reason=reason.strip() if action == "rejected" else "", reviewed_by=request.user,
            reviewed_at=timezone.now(), version=F("version") + 1,
        )
        if not changed:
            return Response({"message": "La solicitud cambió. Actualiza el listado antes de decidir."}, status=409)
        profile.refresh_from_db()
        CompanyReview.objects.create(profile=profile, actor=request.user, action=action, reason=profile.rejection_reason, snapshot={key: getattr(profile, key) for key in CompanySerializer.Meta.fields})
        Notification.objects.create(recipient=profile.company, title=("Tu empresa fue aprobada." if action == "approved" else f"Tu solicitud fue rechazada: {profile.rejection_reason}"))
        return Response({"company": profile_data(profile), "message": "Decisión registrada."})


class CompanyDashboardView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        require_company(request.user)
        if company_state(request.user) != "approved":
            raise PermissionDenied("Tu empresa necesita aprobación para acceder al dashboard.")
        offers = JobOffer.objects.filter(company=request.user)
        applications = Application.objects.filter(offer__company=request.user)
        active = offers.filter(status="published").filter(Q(expires_at__isnull=True) | Q(expires_at__gt=timezone.now()))
        return Response({
            "metrics": {"active_offers": active.count(), "closed_offers": offers.filter(status="closed").count(), "applications": applications.count()},
            "recent_applications": list(applications.select_related("candidate", "offer").order_by("-created_at", "-id").values("id", "candidate__full_name", "offer__title", "created_at")[:10]),
            "company": profile_data(CompanyProfile.objects.get(company=request.user)), "notifications": notices(request.user),
        })


class AdminDashboardView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        require_admin(request.user)
        users = User.objects.filter(is_staff=False, is_superuser=False)
        pending = CompanyProfile.objects.filter(state="pending", submitted_at__isnull=False)
        return Response({
            "metrics": {"candidates": users.filter(role="candidato").count(), "companies": users.filter(role="empresa").count(), "pending_companies": pending.count()},
            "notifications": notices(request.user),
            "recent_events": list(CompanyReview.objects.select_related("profile", "actor").order_by("-created_at", "-id").values("id", "profile__legal_name", "actor__full_name", "action", "created_at")[:20]),
        })
