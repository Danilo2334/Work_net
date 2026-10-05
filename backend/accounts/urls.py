from django.urls import path

from .views import (
    LoginView,
    PasswordRecoveryConfirmView,
    PasswordRecoveryRequestView,
    RegisterView,
    VerifyEmailView,
)


urlpatterns = [

    path(
        "register/",
        RegisterView.as_view(),
        name="register"
    ),

    path(
        "verify-email/",
        VerifyEmailView.as_view(),
        name="verify-email"
    ),

    path(
        "login/",
        LoginView.as_view(),
        name="login"
    ),

    path(
        "password-recovery/request/",
        PasswordRecoveryRequestView.as_view(),
        name="password-recovery-request"
    ),

    path(
        "password-recovery/confirm/",
        PasswordRecoveryConfirmView.as_view(),
        name="password-recovery-confirm"
    ),
]