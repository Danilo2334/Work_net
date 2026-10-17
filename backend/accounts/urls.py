from django.urls import path

from .account_configuration import AccountView, ChangePasswordView, DeleteAccountView
from .notification_preferences import NotificationPreferencesView

from .views import (
    LoginView,
    PasswordRecoveryConfirmView,
    PasswordRecoveryRequestView,
    RegisterView,
    VerifyEmailView,
)


urlpatterns = [
    path("account/", AccountView.as_view(), name="account-configuration"),
    path("account/password/", ChangePasswordView.as_view(), name="account-password"),
    path("account/delete/", DeleteAccountView.as_view(), name="account-delete"),
    path("account/notifications/", NotificationPreferencesView.as_view(), name="account-notifications"),

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