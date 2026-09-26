from django.urls import path
from .views import ResponderLocationView, NearbyAlertsView, AcceptAlertResponseView, UpdateResponseStatusView

urlpatterns = [
    path('responder/location/', ResponderLocationView.as_view(), name='responder-location'),
    path('alerts/nearby/', NearbyAlertsView.as_view(), name='nearby-alerts'),
    path('alerts/<uuid:alert_id>/accept/', AcceptAlertResponseView.as_view(), name='accept-alert'),
    path('alerts/status/', UpdateResponseStatusView.as_view(), name='update-response-status'),
]
