from django.urls import path

from .account_configuration import (
    AccountView,
    ChangePasswordView,
    DeleteAccountView,
)

from .views import (
    LoginView,
    RegisterView,
)


urlpatterns = [
    path("account/", AccountView.as_view(), name="account-configuration"),
    path("account/password/", ChangePasswordView.as_view(), name="account-password"),
    path("account/delete/", DeleteAccountView.as_view(), name="account-delete"),
    path(
        "register/",
        RegisterView.as_view(),
        name="register"
    ),
    path(
        "login/",
        LoginView.as_view(),
        name="login"
    ),
]
