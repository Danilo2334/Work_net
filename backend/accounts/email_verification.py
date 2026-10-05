from urllib.parse import urlencode

from django.conf import settings
from django.core import signing
from django.core.mail import send_mail
from django.urls import reverse


EMAIL_VERIFICATION_SALT = "worknet-email-verification"


def create_verification_token(user):
    return signing.dumps(
        {
            "user_id": user.id,
            "email": user.email,
        },
        salt=EMAIL_VERIFICATION_SALT,
    )


def send_verification_email(user, request):
    token = create_verification_token(user)

    verification_url = request.build_absolute_uri(
        reverse("verify-email")
    )

    verification_url += "?" + urlencode({
        "token": token
    })

    print("\n" + "=" * 80)
    print("ENLACE LIMPIO DE VERIFICACIÓN:")
    print(verification_url)
    print("=" * 80 + "\n")

    subject = "Verifica tu cuenta de Work_net"

    message = (
        f"Hola {user.full_name},\n\n"
        "Gracias por registrarte en Work_net.\n\n"
        "Verifica tu correo en el siguiente enlace:\n\n"
        f"{verification_url}\n\n"
        "Este enlace tiene una duración de 24 horas."
    )

    send_mail(
        subject,
        message,
        settings.DEFAULT_FROM_EMAIL,
        [user.email],
    )