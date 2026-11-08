from django.urls import path
from .views import CandidateDashboardView
from .profile import ProfileView, ProfileRecordsView, ProfileRecordView, ProfilePhotoView
from .selection import ApplicationProfileView, ApplicationProfilePhotoView
from .offers import PublishOfferView, ActiveOffersView, EditOfferView, PreservedOffersView, TransitionOfferView
from .search import SearchOffersView
from .favorites import SavedOffersView, SavedOfferView
from .applicants import CompanyApplicantOffersView, CompanyOfferApplicantsView
from .status_changes import ApplicationStatusView, ApplicationStatusOperationView
from .applications import (OfferApplicationView, ApplicationsView, OwnApplicationView,
                           OwnApplicationPdfView, CompanyApplicationView, CompanyApplicationPdfView)

urlpatterns = [
    path("company/applications/<int:application_id>/status/", ApplicationStatusView.as_view(), name="application-status"),
    path("company/applications/<int:application_id>/status/operations/<uuid:request_id>/", ApplicationStatusOperationView.as_view(), name="application-status-operation"),
    path("company/applicant-offers/", CompanyApplicantOffersView.as_view(), name="applicant-offer-selection"),
    path("company/offers/<int:offer_id>/applications/", CompanyOfferApplicantsView.as_view(), name="company-offer-applications"),
    path("offers/<int:offer_id>/application/", OfferApplicationView.as_view(), name="offer-application"),
    path("applications/", ApplicationsView.as_view(), name="own-applications"),
    path("applications/<int:application_id>/", OwnApplicationView.as_view(), name="own-application"),
    path("applications/<int:application_id>/cv/", OwnApplicationPdfView.as_view(), name="own-application-cv"),
    path("company/applications/<int:application_id>/", CompanyApplicationView.as_view(), name="company-application"),
    path("company/applications/<int:application_id>/cv/", CompanyApplicationPdfView.as_view(), name="company-application-cv"),
    path("offers/saved/", SavedOffersView.as_view(), name="saved-offers"),
    path("offers/<int:offer_id>/saved/", SavedOfferView.as_view(), name="saved-offer"),
    path("offers/search/", SearchOffersView.as_view(), name="search-offers"),
    path("company/offers/active/", ActiveOffersView.as_view(), name="active-company-offers"),
    path("company/offers/preserved/", PreservedOffersView.as_view(), name="preserved-company-offers"),
    path("company/offers/<int:offer_id>/transition/", TransitionOfferView.as_view(), name="transition-company-offer"),
    path("company/offers/<int:offer_id>/", EditOfferView.as_view(), name="edit-company-offer"),
    path("company/offers/", PublishOfferView.as_view(), name="publish-company-offer"),
    path("company/applications/<int:application_id>/profile/", ApplicationProfileView.as_view(), name="application-candidate-profile"),
    path("company/applications/<int:application_id>/profile/photo/", ApplicationProfilePhotoView.as_view(), name="application-candidate-photo"),
    path("profile/candidate/", ProfileView.as_view(), name="candidate-profile"),
    path("profile/candidate/photo/", ProfilePhotoView.as_view(), name="candidate-profile-photo"),
    path("profile/candidate/<str:section>/", ProfileRecordsView.as_view(), name="candidate-profile-records"),
    path("profile/candidate/<str:section>/<uuid:record_id>/", ProfileRecordView.as_view(), name="candidate-profile-record"),
    path("dashboard/candidate/", CandidateDashboardView.as_view(), name="candidate-dashboard"),
]
