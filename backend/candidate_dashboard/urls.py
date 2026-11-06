from django.urls import path
from .views import CandidateDashboardView
from .profile import ProfileView, ProfileRecordsView, ProfileRecordView, ProfilePhotoView
from .selection import ApplicationProfileView, ApplicationProfilePhotoView

urlpatterns = [
    path("company/applications/<int:application_id>/profile/", ApplicationProfileView.as_view(), name="application-candidate-profile"),
    path("company/applications/<int:application_id>/profile/photo/", ApplicationProfilePhotoView.as_view(), name="application-candidate-photo"),
    path("profile/candidate/", ProfileView.as_view(), name="candidate-profile"),
    path("profile/candidate/photo/", ProfilePhotoView.as_view(), name="candidate-profile-photo"),
    path("profile/candidate/<str:section>/", ProfileRecordsView.as_view(), name="candidate-profile-records"),
    path("profile/candidate/<str:section>/<uuid:record_id>/", ProfileRecordView.as_view(), name="candidate-profile-record"),
    path("dashboard/candidate/", CandidateDashboardView.as_view(), name="candidate-dashboard"),
]
