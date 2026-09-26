from django.urls import path
from .views import TravelSessionStartView, TravelPingView, TravelSessionEndView

urlpatterns = [
    path('start/', TravelSessionStartView.as_view(), name='travel-start'),
    path('ping/', TravelPingView.as_view(), name='travel-ping'),
    path('end/', TravelSessionEndView.as_view(), name='travel-end'),
]
