from django.urls import path
from .views import NotificationListView, NotificationMarkReadView, DisasterAlertCreateView, DisasterAlertNearbyView

urlpatterns = [
    path('list/', NotificationListView.as_view(), name='notification-list'),
    path('<uuid:pk>/read/', NotificationMarkReadView.as_view(), name='notification-read'),
    path('disaster/create/', DisasterAlertCreateView.as_view(), name='disaster-create'),
    path('disaster/nearby/', DisasterAlertNearbyView.as_view(), name='disaster-nearby'),
]
