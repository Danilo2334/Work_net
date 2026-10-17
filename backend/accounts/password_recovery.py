from django.conf import settings
from django.contrib.auth.tokens import default_token_generator
from django.core.mail import send_mail
from django.utils.encoding import force_bytes
from django.utils.http import urlsafe_base64_encode


def send_password_recovery_email(user):
    uid = urlsafe_base64_encode(force_bytes(user.pk))
    token = default_token_generator.make_token(user)
    reset_link = (
        f"{settings.PASSWORD_RESET_FRONTEND_URL}"
        f"?uid={uid}&token={token}"
    )
    message = (
        f"Hola {user.full_name},\n\n"
        "Recibimos una solicitud para restablecer "
        "la contraseña de tu cuenta.\n\n"
        "Utiliza el siguiente enlace:\n"
        f"{reset_link}\n\n"
        "Si no solicitaste este cambio, puedes ignorar este mensaje."
    )
    send_mail(
        "Recuperación de contraseña - Work_net",
        message,
        settings.DEFAULT_FROM_EMAIL,
        [user.email],
        fail_silently=False,
    )
