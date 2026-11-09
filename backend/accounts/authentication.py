"""No legacy token or Django cookie can bypass administrative second factor."""
from django.utils import timezone
from django.utils.crypto import constant_time_compare
from rest_framework.authentication import TokenAuthentication as BaseTokenAuthentication
from rest_framework.exceptions import AuthenticationFailed

from .models import AdminMFASession


class TokenAuthentication(BaseTokenAuthentication):
    def authenticate_credentials(self, key):
        user, token = super().authenticate_credentials(key)
        if user.is_staff or user.is_superuser:
            grant = AdminMFASession.objects.filter(token=token).first()
            if (grant is None or grant.expires_at <= timezone.now()
                    or grant.revision != user.admin_revision
                    or not constant_time_compare(grant.password_hash, user.get_session_auth_hash())):
                raise AuthenticationFailed("El acceso administrativo requiere iniciar sesión con doble factor.")
        return user, token
