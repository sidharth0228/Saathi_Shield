from django.urls import path
from .views import AlertTriggerView, AlertResolveView, PublicTrackingView, EvidenceUploadView

urlpatterns = [
    path('trigger/', AlertTriggerView.as_view(), name='alert-trigger'),
    path('resolve/', AlertResolveView.as_view(), name='alert-resolve'),
    path('track/<str:secure_token>/', PublicTrackingView.as_view(), name='public-track'),
    path('evidence/upload/', EvidenceUploadView.as_view(), name='evidence-upload'),
]
