from django.urls import path

from .account_configuration import AccountView, ChangePasswordView, DeleteAccountView
from .notification_preferences import NotificationPreferencesView
from .company import (CompanyView, CompanyLogoView, SubmitCompanyView, PendingCompaniesView, ReviewCompanyView, CompanyDashboardView, AdminDashboardView)

from .views import (
    LoginView,
    PasswordRecoveryConfirmView,
    PasswordRecoveryRequestView,
    RegisterView,
    VerifyEmailView,
    SelectRoleView,
    LogoutView,
)


urlpatterns = [
    path("register/role/", SelectRoleView.as_view(), name="select-role"),
    path("logout/", LogoutView.as_view(), name="logout"),
    path("company/", CompanyView.as_view(), name="company-information"),
    path("company/logo/", CompanyLogoView.as_view(), name="company-logo"),
    path("company/submit/", SubmitCompanyView.as_view(), name="company-submit"),
    path("admin/companies/", PendingCompaniesView.as_view(), name="pending-companies"),
    path("admin/companies/<int:pk>/review/", ReviewCompanyView.as_view(), name="company-review"),
    path("dashboard/company/", CompanyDashboardView.as_view(), name="company-dashboard"),
    path("dashboard/admin/", AdminDashboardView.as_view(), name="admin-dashboard"),
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
