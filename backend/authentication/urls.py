from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    RegisterView, OTPSendView, OTPVerifyView, GoogleLoginView,
    MedicalProfileView, EmergencyContactViewSet
)

router = DefaultRouter()
router.register(r'contacts', EmergencyContactViewSet, basename='emergency-contacts')

urlpatterns = [
    path('auth/register/', RegisterView.as_view(), name='register'),
    path('auth/otp/send/', OTPSendView.as_view(), name='otp-send'),
    path('auth/otp/verify/', OTPVerifyView.as_view(), name='otp-verify'),
    path('auth/google/', GoogleLoginView.as_view(), name='google-login'),
    path('user/medical/', MedicalProfileView.as_view(), name='medical-profile'),
    path('user/', include(router.urls)),
]
