from django.conf import settings
from django.core import signing

from rest_framework import status
from rest_framework.authtoken.models import Token
from rest_framework.response import Response
from rest_framework.views import APIView

from .email_verification import (
    EMAIL_VERIFICATION_SALT,
    send_verification_email,
)

from .models import User

from .password_recovery import (
    send_password_recovery_email,
)

from .serializer import (
    LoginSerializer,
    PasswordRecoveryConfirmSerializer,
    PasswordRecoveryRequestSerializer,
    RegisterSerializer,
)


class RegisterView(APIView):

    authentication_classes = []
    permission_classes = []

    def post(self, request):

        serializer = RegisterSerializer(
            data=request.data
        )

        if serializer.is_valid():

            user = serializer.save()

            send_verification_email(
                user,
                request
            )

            return Response(
                {
                    "message":
                        "Usuario registrado correctamente. "
                        "Revisa tu correo para verificar la cuenta.",

                    "user": {
                        "id": user.id,
                        "full_name": user.full_name,
                        "email": user.email,
                        "role": user.role,
                        "email_verified":
                            user.email_verified,
                    }
                },
                status=status.HTTP_201_CREATED
            )

        return Response(
            {
                "message":
                    "No fue posible registrar el usuario.",

                "errors":
                    serializer.errors
            },
            status=status.HTTP_400_BAD_REQUEST
        )


class VerifyEmailView(APIView):

    authentication_classes = []
    permission_classes = []

    def get(self, request):

        token = request.query_params.get(
            "token"
        )

        if not token:

            return Response(
                {
                    "message":
                        "El token de verificación "
                        "es obligatorio."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        try:

            data = signing.loads(
                token,
                salt=EMAIL_VERIFICATION_SALT,
                max_age=
                    settings.EMAIL_VERIFICATION_TIMEOUT,
            )

        except signing.SignatureExpired:

            return Response(
                {
                    "message":
                        "El enlace de verificación "
                        "ha expirado."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        except signing.BadSignature:

            return Response(
                {
                    "message":
                        "El enlace de verificación "
                        "no es válido."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        user = User.objects.filter(
            id=data.get("user_id"),
            email=data.get("email"),
        ).first()

        if not user:

            return Response(
                {
                    "message":
                        "No se encontró el usuario."
                },
                status=status.HTTP_404_NOT_FOUND
            )

        if user.email_verified:

            return Response(
                {
                    "message":
                        "El correo ya había sido verificado."
                },
                status=status.HTTP_200_OK
            )

        user.email_verified = True

        user.save(
            update_fields=[
                "email_verified"
            ]
        )

        return Response(
            {
                "message":
                    "Correo verificado correctamente."
            },
            status=status.HTTP_200_OK
        )


class LoginView(APIView):

    authentication_classes = []
    permission_classes = []

    def post(self, request):

        serializer = LoginSerializer(
            data=request.data
        )

        if serializer.is_valid():

            user = serializer.validated_data[
                "user"
            ]

            token, _ = Token.objects.get_or_create(
                user=user
            )

            effective_role = (
                "admin"
                if user.is_staff or user.is_superuser
                else user.role
            )

            return Response(
                {
                    "message":
                        "Inicio de sesión correcto.",

                    "token":
                        token.key,

                    "user": {
                        "id":
                            user.id,

                        "full_name":
                            user.full_name,

                        "email":
                            user.email,

                        "role":
                            effective_role,

                        "email_verified":
                            user.email_verified,
                    }
                },
                status=status.HTTP_200_OK
            )

        return Response(
            {
                "message":
                    "No fue posible iniciar sesión.",

                "errors":
                    serializer.errors
            },
            status=status.HTTP_400_BAD_REQUEST
        )


class PasswordRecoveryRequestView(APIView):

    authentication_classes = []
    permission_classes = []

    def post(self, request):

        serializer = PasswordRecoveryRequestSerializer(
            data=request.data
        )

        if not serializer.is_valid():

            return Response(
                {
                    "message":
                        "No fue posible procesar la solicitud.",

                    "errors":
                        serializer.errors
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        email = serializer.validated_data[
            "email"
        ]

        user = User.objects.filter(
            email__iexact=email,
            is_active=True
        ).first()

        if (
            user
            and user.has_usable_password()
        ):
            send_password_recovery_email(
                user
            )

        return Response(
            {
                "message":
                    "Si el correo está registrado, "
                    "recibirás un enlace para "
                    "restablecer tu contraseña."
            },
            status=status.HTTP_200_OK
        )


class PasswordRecoveryConfirmView(APIView):

    authentication_classes = []
    permission_classes = []

    def post(self, request):

        serializer = PasswordRecoveryConfirmSerializer(
            data=request.data
        )

        if not serializer.is_valid():

            return Response(
                {
                    "message":
                        "No fue posible restablecer "
                        "la contraseña.",

                    "errors":
                        serializer.errors
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        user = serializer.save()

        # Invalida el token anterior de autenticación.
        # El próximo login generará uno nuevo.
        Token.objects.filter(
            user=user
        ).delete()

        return Response(
            {
                "message":
                    "Contraseña restablecida correctamente."
            },
            status=status.HTTP_200_OK
        )