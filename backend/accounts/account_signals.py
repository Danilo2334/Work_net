"""Revocar accesos cuando cambian las credenciales, también desde HU003."""

from django.db.models.signals import pre_save
from django.dispatch import receiver
from rest_framework.authtoken.models import Token

from .models import User


@receiver(pre_save, sender=User, dispatch_uid="accounts.revoke_account_tokens")
def revoke_account_tokens(sender, instance, using, raw=False, update_fields=None, **kwargs):
    if raw or instance._state.adding:
        return
    if update_fields is not None and not {"password", "is_active"}.intersection(update_fields):
        return

    previous = sender.objects.using(using).filter(pk=instance.pk).values(
        "password", "is_active"
    ).first()
    if previous and (
        previous["password"] != instance.password
        or (previous["is_active"] and not instance.is_active)
    ):
        Token.objects.using(using).filter(user_id=instance.pk).delete()
