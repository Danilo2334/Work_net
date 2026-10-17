from django.urls import path
from .views import CandidateDashboardView

urlpatterns = [
    path("dashboard/candidate/", CandidateDashboardView.as_view(), name="candidate-dashboard"),
]
