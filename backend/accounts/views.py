from rest_framework import status
from rest_framework.authtoken.models import Token
from rest_framework.response import Response
from rest_framework.views import APIView

from .serializer import (
    LoginSerializer,
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

            token, _ = Token.objects.get_or_create(user=user)

            return Response(
                {
                    "message":
                        "Inicio de sesión correcto.",

                    "token": token.key,

                    "user": {
                        "id": user.id,
                        "full_name": user.full_name,
                        "email": user.email,
                        "role": user.role,
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
