"""Centro privado de avisos; una empresa pendiente/rechazada puede leer los suyos."""
from django.db import transaction
from django.db.models import Max
from django.utils import timezone
from rest_framework import serializers
from rest_framework.exceptions import NotFound, PermissionDenied, ValidationError
from rest_framework.response import Response
from accounts.account_configuration import AuthenticatedAccountView, StrictInputSerializer
from accounts.models import User
from accounts.notification_preferences import NotificationBooleanField
from .applicants import ApplicantParameters, paginated
from .applications import no_query
from .models import Notification, NotificationPreference
from .notification_events import EVENTS
from .status_changes import retry_write


class NoticeParameters(ApplicantParameters):
    experience = education = skill = order = None
    status = serializers.ChoiceField(choices=('all', 'unread', 'read'), default='all')
    through_id = serializers.IntegerField(min_value=0, max_value=9223372036854775807, required=False)


class NoticeView(AuthenticatedAccountView):
    def initial(self, request, *args, **kwargs):
        super().initial(request, *args, **kwargs)
        actor = User.objects.get(pk=request.user.pk)
        if not actor.is_active or not actor.email_verified or not (
            actor.role in ('candidato', 'empresa') or actor.is_staff or actor.is_superuser
        ):
            raise PermissionDenied('Necesitas una cuenta activa y verificada.')

    def finalize_response(self, request, response, *args, **kwargs):
        response = super().finalize_response(request, response, *args, **kwargs)
        response['Cache-Control'] = 'private, no-store'
        response['Vary'] = 'Authorization'
        return response


def notice_data(item):
    return {'id': item.pk, 'title': item.title, 'event_kind': item.event_kind,
            'created_at': item.created_at, 'read_at': item.read_at,
            'application_id': item.application_id,
            'offer_id': item.application.offer_id if item.application_id else None,
            'conversation_id': item.message.conversation_id if item.message_id else None,
            'company_review_id': item.company_review_id}


class NotificationsView(NoticeView):
    http_method_names = ['get', 'head', 'options']

    def get(self, request):
        params = NoticeParameters(data=request.query_params);params.is_valid(raise_exception=True)
        p = params.validated_data
        own = Notification.objects.filter(recipient=request.user)
        anchor = p.get('through_id', own.aggregate(value=Max('pk'))['value'] or 0)
        query = own.filter(pk__lte=anchor)
        if p['status'] != 'all':query = query.filter(read_at__isnull=p['status']=='unread')
        meta, rows = paginated(query.select_related('application', 'message').order_by('-created_at', '-pk'), p)
        return Response({**meta, 'through_id': anchor, 'unread_count': own.filter(read_at__isnull=True).count(),
                         'notifications': [notice_data(x) for x in rows]})


class NotificationSummaryView(NoticeView):
    http_method_names = ['get', 'head', 'options']

    def get(self, request):
        no_query(request)
        return Response({'unread_count': Notification.objects.filter(recipient=request.user, read_at__isnull=True).count()})


class ReadInput(StrictInputSerializer):
    notification_ids = serializers.ListField(child=serializers.IntegerField(min_value=1, max_value=9223372036854775807), min_length=1, max_length=50)

    def validate_notification_ids(self, value):
        original = self.initial_data.get('notification_ids')
        if not isinstance(original, list) or any(type(x) is not int for x in original) or len(set(value))!=len(value):
            raise ValidationError('Envía entre1 y50 identificadores enteros distintos.')
        return value


class NotificationReadView(NoticeView):
    http_method_names = ['post', 'options']

    def post(self, request):
        no_query(request);data=ReadInput(data=request.data);data.is_valid(raise_exception=True)
        ids=data.validated_data['notification_ids']
        def write():
            with transaction.atomic():
                own = Notification.objects.select_for_update().filter(recipient=request.user, pk__in=ids)
                if len(list(own.values_list('pk',flat=True))) != len(ids):
                    raise NotFound('No encontramos esos avisos en tu cuenta.')
                return own.filter(read_at__isnull=True).update(read_at=timezone.now())
        changed=retry_write(write)
        return Response({'marked_read': changed, 'unread_count':Notification.objects.filter(recipient=request.user,read_at__isnull=True).count()})


class PreferencesInput(StrictInputSerializer):
    application_created = NotificationBooleanField(required=False)
    application_status_changed = NotificationBooleanField(required=False)
    message_received = NotificationBooleanField(required=False)
    company_reviewed = NotificationBooleanField(required=False)

    def validate(self, data):
        if not data:raise ValidationError('Selecciona al menos una preferencia.')
        return data


def preferences(user):
    item=NotificationPreference.objects.filter(user=user).first()
    return {key:getattr(item,key,True) for key in EVENTS}


class NotificationPreferencesView(NoticeView):
    http_method_names = ['get', 'patch', 'head', 'options']

    def get(self, request):
        no_query(request)
        return Response({'preferences': preferences(request.user), 'scope':'future_events_only', 'push_delivery':'not_configured'})

    def patch(self, request):
        no_query(request);data=PreferencesInput(data=request.data);data.is_valid(raise_exception=True)
        with transaction.atomic():
            User.objects.select_for_update(no_key=True).get(pk=request.user.pk)
            item,_=NotificationPreference.objects.get_or_create(user=request.user)
            for key,value in data.validated_data.items():setattr(item,key,value)
            item.save(update_fields=list(data.validated_data))
        return self.get(request)
