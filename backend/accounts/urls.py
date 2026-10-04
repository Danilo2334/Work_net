from django.urls import path

from .views import (
    PasswordRecoveryConfirmView,
    PasswordRecoveryRequestView,
    RegisterView,
)


urlpatterns = [
    path("password-recovery/request/", PasswordRecoveryRequestView.as_view(),
         name="password-recovery-request"),
    path("password-recovery/confirm/", PasswordRecoveryConfirmView.as_view(),
         name="password-recovery-confirm"),
    path(
        "register/",
        RegisterView.as_view(),
        name="register"
    ),
]
