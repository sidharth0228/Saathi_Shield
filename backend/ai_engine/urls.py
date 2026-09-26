from django.urls import path
from .views import RouteSafetyScoreView
from notifications.views import DisasterAlertNearbyView

urlpatterns = [
    path('score/', RouteSafetyScoreView.as_view(), name='safety-score'),
    path('disasters/', DisasterAlertNearbyView.as_view(), name='safety-disasters'),
]
