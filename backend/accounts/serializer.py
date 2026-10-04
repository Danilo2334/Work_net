from django.contrib.auth.password_validation import validate_password
from rest_framework import serializers

from .models import User


class RegisterSerializer(serializers.ModelSerializer):

    password = serializers.CharField(
        write_only=True
    )

    password_confirm = serializers.CharField(
        write_only=True
    )

    class Meta:
        model = User

        fields = [
            "id",
            "full_name",
            "email",
            "password",
            "password_confirm",
            "role",
        ]

        read_only_fields = [
            "id"
        ]

    def validate_email(self, value):

        email = value.strip().lower()

        if User.objects.filter(
            email__iexact=email
        ).exists():

            raise serializers.ValidationError(
                "Este correo ya está registrado."
            )

        return email

    def validate(self, data):

        if (
            data["password"]
            != data["password_confirm"]
        ):
            raise serializers.ValidationError({
                "password_confirm":
                    "Las contraseñas no coinciden."
            })

        validate_password(
            data["password"]
        )

        return data

    def create(self, validated_data):

        validated_data.pop(
            "password_confirm"
        )

        password = validated_data.pop(
            "password"
        )

        user = User.objects.create_user(
            password=password,
            **validated_data
        )

        return user