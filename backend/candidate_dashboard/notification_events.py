"""HU023: avisos de eventos dentro de la transacción que los origina.

La preferencia se observa al crear el evento. Deshabilitarlo afecta solo avisos
futuros: conserva historial/lecturas y no reconstruye avisos al reintentar.
El ajuste push de HU004 sigue siendo independiente; no hay envío push externo.
"""
from .models import Notification, NotificationPreference

EVENTS = ('application_created', 'application_status_changed', 'message_received', 'company_reviewed')


def notify(*, recipient_id, event_kind, title, **context):
    if event_kind not in EVENTS:
        raise ValueError('Tipo de evento no admitido.')
    preference = NotificationPreference.objects.filter(user_id=recipient_id).values(event_kind).first()
    if preference and not preference[event_kind]:
        return None
    return Notification.objects.create(recipient_id=recipient_id, event_kind=event_kind,
                                       title=title[:200], **context)
