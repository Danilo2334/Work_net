from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import User
from .password_recovery import send_password_recovery_email
from .serializer import (
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

            return Response(
                {
                    "message":
                        "Usuario registrado correctamente.",

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


class PasswordRecoveryRequestView(APIView):
    authentication_classes = []
    permission_classes = []

    def post(self, request):
        serializer = PasswordRecoveryRequestSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                {"message": "No fue posible procesar la solicitud.",
                 "errors": serializer.errors},
                status=status.HTTP_400_BAD_REQUEST,
            )
        email = serializer.validated_data["email"]
        user = User.objects.filter(
            email__iexact=email, is_active=True
        ).first()
        if user and user.has_usable_password():
            send_password_recovery_email(user)
        return Response({
            "message": "Si el correo está registrado, recibirás un enlace para restablecer tu contraseña."
        })


class PasswordRecoveryConfirmView(APIView):
    authentication_classes = []
    permission_classes = []

    def post(self, request):
        serializer = PasswordRecoveryConfirmSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                {"message": "No fue posible restablecer la contraseña.",
                 "errors": serializer.errors},
                status=status.HTTP_400_BAD_REQUEST,
            )
        serializer.save()
        return Response({"message": "Contraseña restablecida correctamente."})
