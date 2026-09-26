from rest_framework import status, generics
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, IsAdminUser
from django.shortcuts import get_object_or_404
from django.utils import timezone

from .models import Notification, DisasterAlert
from .serializers import NotificationSerializer, DisasterAlertSerializer
from travel.views import haversine_distance

class NotificationListView(generics.ListAPIView):
    serializer_class = NotificationSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Notification.objects.filter(user=self.request.user).order_by('-sent_at')


class NotificationMarkReadView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        notification = get_object_or_404(Notification, id=pk, user=request.user)
        notification.is_read = True
        notification.save()
        return Response({"message": "Notification marked as read."}, status=status.HTTP_200_OK)


class DisasterAlertCreateView(generics.CreateAPIView):
    serializer_class = DisasterAlertSerializer
    permission_classes = [IsAuthenticated]

    def perform_create(self, serializer):
        # Allow only ADMIN users to dispatch official alerts
        if self.request.user.role != 'ADMIN':
            from rest_framework.exceptions import PermissionDenied
            raise PermissionDenied("Only administrative accounts can issue regional disaster alerts.")
        serializer.save(created_by=self.request.user)


class DisasterAlertNearbyView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        lat = request.query_params.get('lat')
        lng = request.query_params.get('lng')

        if not lat or not lng:
            return Response({"error": "Latitude and longitude query parameters are required."}, status=status.HTTP_400_BAD_REQUEST)

        try:
            lat = float(lat)
            lng = float(lng)
        except ValueError:
            return Response({"error": "Invalid coordinates format."}, status=status.HTTP_400_BAD_REQUEST)

        now = timezone.now()
        # Fetch alerts that are not yet expired
        active_disasters = DisasterAlert.objects.filter(expires_at__gt=now)
        affected_alerts = []

        for disaster in active_disasters:
            dist_km = haversine_distance(lng, lat, disaster.location_center_lng, disaster.location_center_lat)
            radius_km = disaster.radius_meters / 1000.0
            
            # If user falls inside disaster radius, list it
            if dist_km <= radius_km:
                affected_alerts.append({
                    "id": str(disaster.id),
                    "title": disaster.title,
                    "message": disaster.message,
                    "event_type": disaster.event_type,
                    "severity": disaster.severity,
                    "distance_meters": int(dist_km * 1000),
                    "expires_at": disaster.expires_at
                })

        return Response(affected_alerts, status=status.HTTP_200_OK)
