"""HU022: conversaciones por postulación, texto e intenciones de lectura acotadas."""
from django.db import transaction
from django.db.models import Count, OuterRef, Q, Subquery
from django.utils import timezone
from rest_framework import serializers
from accounts.authentication import TokenAuthentication
from rest_framework.exceptions import NotFound, PermissionDenied, ValidationError
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from accounts.account_configuration import StrictInputSerializer
from accounts.models import CompanyProfile, User
from .applications import no_query
from .favorites import SavedPageParameters
from .models import Application, Conversation, JobOffer, Message
from .status_changes import Conflict, clean_text, retry_write


def valid_user(user, role):
    return user.role == role and user.is_active and user.email_verified and not user.is_staff and not user.is_superuser


def authorize(user):
    actor = User.objects.get(pk=user.pk)
    if not (valid_user(actor, 'candidato') or valid_user(actor, 'empresa')):
        raise PermissionDenied('Mensajes requiere una cuenta candidata o empresarial verificada.')
    if actor.role == 'empresa' and not CompanyProfile.objects.filter(company=actor, state='approved').exists():
        raise PermissionDenied('La empresa debe estar aprobada para usar Mensajes.')
    return actor


def permitted_applications(user):
    return Application.objects.filter(
        Q(candidate=user) | Q(offer__company=user),
        candidate__role='candidato', candidate__is_active=True, candidate__email_verified=True,
        candidate__is_staff=False, candidate__is_superuser=False,
        offer__company__role='empresa', offer__company__is_active=True, offer__company__email_verified=True,
        offer__company__is_staff=False, offer__company__is_superuser=False,
        offer__company__companyprofile__state='approved')


def conversations(user):
    return Conversation.objects.filter(application__in=permitted_applications(user))


def own_conversation(user, pk):
    conv = conversations(user).select_related('application__offer__company__companyprofile', 'application__candidate').defer('application__cv_document').filter(pk=pk).first()
    if conv is None:
        raise NotFound('No encontramos esa conversación en tu cuenta.')
    return conv


def lock_context(user, application_id):
    # Orden estable de ambos usuarios. NO KEY UPDATE admite las FK de HU018.
    app = permitted_applications(user).select_related('offer').defer('cv_document').filter(pk=application_id).first()
    if app is None:
        raise NotFound('No encontramos una postulación autorizada para conversar.')
    users = list(User.objects.select_for_update(no_key=True).filter(pk__in=[app.candidate_id, app.offer.company_id]).order_by('pk'))
    by_id = {u.pk: u for u in users}
    candidate, company = by_id.get(app.candidate_id), by_id.get(app.offer.company_id)
    profile = CompanyProfile.objects.select_for_update().filter(company_id=app.offer.company_id).first()
    if not candidate or not company or not valid_user(candidate,'candidato') or not valid_user(company,'empresa') or not profile or profile.state != 'approved':
        raise NotFound('Las cuentas del proceso ya no están habilitadas para conversar.')
    offer = JobOffer.objects.select_for_update().filter(pk=app.offer_id,company_id=company.pk).first()
    app = Application.objects.select_for_update().defer('cv_document').filter(pk=application_id,candidate_id=candidate.pk,offer=offer).first()
    if app is None:
        raise NotFound('El contexto de selección ya no está disponible.')
    app.offer = offer;app.candidate = candidate
    return app


def page_data(qs, params, field, encode, *, reverse=False):
    page, size = params['page'], params['page_size'];count=qs.count();pages=(count+size-1)//size
    if page > max(1,pages):raise ValidationError({'page':'La página solicitada no existe.'})
    rows=list(qs[(page-1)*size:page*size])
    if reverse:rows.reverse()
    return {'count':count,'page':page,'page_size':size,'total_pages':pages,
            'next_page':page+1 if page<pages else None,'previous_page':page-1 if page>1 else None,
            field:[encode(row) for row in rows]}


def conversation_data(conv, user):
    app=conv.application;offer=app.offer;company=offer.company
    contact = company if user.pk==app.candidate_id else app.candidate
    name=(company.companyprofile.legal_name or offer.company_name) if contact.pk==company.pk else contact.full_name
    return {'id':conv.pk,'application_id':app.pk,'offer':{'id':offer.pk,'title':offer.title,'company_name':offer.company_name},
            'contact':{'id':contact.pk,'full_name':name,'role':contact.role},
            'created_at':conv.created_at,'last_activity_at':conv.last_activity_at,
            'unread_count':getattr(conv,'pending_count',None) if hasattr(conv,'pending_count') else Message.objects.filter(conversation=conv,recipient=user,read_at__isnull=True).count(),
            'last_message':getattr(conv,'last_text',None)}


def message_data(msg):
    return {'id':msg.pk,'conversation_id':msg.conversation_id,'sender_id':msg.sender_id,
            'recipient_id':msg.recipient_id,'client_message_id':str(msg.client_message_id),
            'text':msg.text,'created_at':msg.created_at,'read_at':msg.read_at}


class MessageView(APIView):
    authentication_classes=[TokenAuthentication]
    permission_classes=[IsAuthenticated]

    def initial(self, request, *args, **kwargs):
        super().initial(request,*args,**kwargs)
        authorize(request.user)

    def finalize_response(self, request, response, *args, **kwargs):
        response=super().finalize_response(request,response,*args,**kwargs)
        response['Cache-Control']='private, no-store';response['Vary']='Authorization'
        return response


class ConversationParameters(SavedPageParameters):
    q=serializers.CharField(max_length=100,allow_blank=True,default='')

    def to_internal_value(self, data):
        if any(key not in self.fields or len(data.getlist(key))!=1 for key in data):
            raise ValidationError({'query':'Envía únicamente parámetros permitidos una sola vez.'})
        for key in ('page','page_size'):
            if key in data and (not data[key].isascii() or not data[key].isdigit()):raise ValidationError({key:'Envía un entero positivo.'})
        if 'q' in data:
            try:clean_text(data['q'],max_length=100,allow_empty=True)
            except ValidationError as exc:raise ValidationError({'q':exc.detail}) from exc
        return serializers.Serializer.to_internal_value(self,{key:data[key] for key in data})


class StartInput(StrictInputSerializer):
    application_id=serializers.IntegerField(min_value=1)

    def validate_application_id(self,value):
        if type(self.initial_data.get('application_id')) is not int:raise ValidationError('Envía un identificador entero.')
        return value


class MessageParameters(SavedPageParameters):
    through_id=serializers.IntegerField(min_value=0,max_value=9223372036854775807,required=False)


class MessageInput(StrictInputSerializer):
    text=serializers.CharField(max_length=4000,trim_whitespace=False)
    client_message_id=serializers.UUIDField()

    def validate_text(self,value):
        if not isinstance(self.initial_data.get('text'),str):raise ValidationError('Envía un mensaje de texto.')
        return clean_text(value,max_length=4000)


class ReadInput(StrictInputSerializer):
    message_ids=serializers.ListField(child=serializers.IntegerField(min_value=1),max_length=50,allow_empty=True)

    def validate_message_ids(self,value):
        raw=self.initial_data['message_ids']
        if any(type(n) is not int for n in raw) or len(set(value))!=len(value):raise ValidationError('Envía IDs enteros sin duplicados, hasta 50 mensajes consultados.')
        return value


class ConversationsView(MessageView):
    http_method_names=['get','post','head','options']

    def get(self, request):
        params=ConversationParameters(data=request.query_params);params.is_valid(raise_exception=True);p=params.validated_data
        qs=conversations(request.user)
        if p['q']:
            qs=qs.filter(Q(application__candidate__full_name__icontains=p['q'])|Q(application__offer__company_name__icontains=p['q'])|Q(application__offer__title__icontains=p['q'])|Q(application__offer__company__companyprofile__legal_name__icontains=p['q']))
        last=Message.objects.filter(conversation=OuterRef('pk')).order_by('-pk')
        qs=qs.select_related('application__offer__company__companyprofile','application__candidate').defer('application__cv_document').annotate(
            pending_count=Count('messages',filter=Q(messages__recipient=request.user,messages__read_at__isnull=True)),
            last_text=Subquery(last.values('text')[:1])).order_by('-last_activity_at','-pk')
        return Response(page_data(qs,p,'conversations',lambda x:conversation_data(x,request.user)))

    def post(self, request):
        no_query(request);data=StartInput(data=request.data);data.is_valid(raise_exception=True)
        def write():
            with transaction.atomic():
                app=lock_context(request.user,data.validated_data['application_id'])
                conv,created=Conversation.objects.get_or_create(application=app)
                # Canonical context is reloaded for the contact, not supplied by client.
                return conv.pk,created
        pk,created=retry_write(write)
        return Response({'conversation':conversation_data(own_conversation(request.user,pk),request.user),'created':created},status=201 if created else 200)


class ConversationDetailView(MessageView):
    http_method_names=['get','head','options']
    def get(self,request,conversation_id):
        no_query(request)
        return Response({'conversation':conversation_data(own_conversation(request.user,conversation_id),request.user)})


class MessagesView(MessageView):
    http_method_names=['get','post','head','options']
    def get(self,request,conversation_id):
        conv=own_conversation(request.user,conversation_id)
        params=MessageParameters(data=request.query_params);params.is_valid(raise_exception=True)
        qs=Message.objects.filter(conversation=conv)
        anchor=params.validated_data.get('through_id')
        if anchor is None:anchor=qs.order_by('-pk').values_list('pk',flat=True).first() or 0
        result=page_data(qs.filter(pk__lte=anchor).order_by('-pk'),params.validated_data,'messages',message_data,reverse=True)
        result['conversation']=conversation_data(conv,request.user)
        result['through_id']=anchor
        result['order']='latest_windows_chronological'
        return Response(result)

    def post(self,request,conversation_id):
        no_query(request);data=MessageInput(data=request.data);data.is_valid(raise_exception=True);p=data.validated_data
        conv=own_conversation(request.user,conversation_id)
        def write():
            with transaction.atomic():
                app=lock_context(request.user,conv.application_id)
                locked=Conversation.objects.select_for_update().get(pk=conv.pk,application=app)
                previous=Message.objects.filter(conversation=locked,sender=request.user,client_message_id=p['client_message_id']).first()
                if previous:
                    if previous.text!=p['text']:raise Conflict('Esta clave identifica otro mensaje. Conserva el texto original o inicia un mensaje nuevo.')
                    return previous,False
                recipient_id=app.offer.company_id if request.user.pk==app.candidate_id else app.candidate_id
                msg=Message.objects.create(conversation=locked,sender_id=request.user.pk,recipient_id=recipient_id,
                    text=p['text'],client_message_id=p['client_message_id'])
                locked.last_activity_at=msg.created_at;locked.save(update_fields=['last_activity_at'])
                from .notification_events import notify
                notify(recipient_id=recipient_id,event_kind='message_received',message=msg,
                       title=f'Nuevo mensaje sobre {app.offer.title}')
                return msg,True
        msg,created=retry_write(write)
        return Response({'message':message_data(msg),'created':created},status=201 if created else 200)


class MessageOperationView(MessageView):
    http_method_names=['get','head','options']
    def get(self,request,conversation_id,client_message_id):
        no_query(request);conv=own_conversation(request.user,conversation_id)
        msg=Message.objects.filter(conversation=conv,sender=request.user,client_message_id=client_message_id).first()
        if msg is None:raise NotFound('Este mensaje todavía no está registrado. Puedes reintentar con la misma clave.')
        return Response({'message':message_data(msg),'created':False})


class ConversationReadView(MessageView):
    http_method_names=['post','options']
    def post(self,request,conversation_id):
        no_query(request);data=ReadInput(data=request.data);data.is_valid(raise_exception=True);ids=data.validated_data['message_ids']
        conv=own_conversation(request.user,conversation_id)
        def write():
            with transaction.atomic():
                app=lock_context(request.user,conv.application_id)
                locked=Conversation.objects.select_for_update().get(pk=conv.pk,application=app)
                received=Message.objects.filter(conversation=locked,recipient=request.user,pk__in=ids)
                if received.count()!=len(ids):raise NotFound('No encontramos esos mensajes recibidos en esta conversación.')
                changed=received.filter(read_at__isnull=True).update(read_at=timezone.now())
                return changed,Message.objects.filter(conversation=locked,recipient=request.user,read_at__isnull=True).count()
        changed,pending=retry_write(write)
        return Response({'marked_read':changed,'unread_count':pending})


class MessageSummaryView(MessageView):
    http_method_names=['get','head','options']
    def get(self,request):
        no_query(request)
        unread=Message.objects.filter(conversation__in=conversations(request.user),recipient=request.user,read_at__isnull=True)
        return Response({'unread_count':unread.count()})
