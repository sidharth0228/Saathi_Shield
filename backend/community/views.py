import logging
from django.utils import timezone
from rest_framework import status, generics
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.shortcuts import get_object_or_404
from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer

from .models import ResponderProfile, AlertResponse
from .serializers import ResponderProfileSerializer, AlertResponseSerializer
from alerts.models import Alert
from travel.views import haversine_distance

logger = logging.getLogger(__name__)

class ResponderLocationView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = ResponderProfileSerializer(data=request.data, context={'request': request})
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response({
            "message": "Responder location status updated successfully."
        }, status=status.HTTP_200_OK)


class NearbyAlertsView(APIView):
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

        active_alerts = Alert.objects.filter(status='ACTIVE')
        nearby_alerts = []

        for alert in active_alerts:
            dist = haversine_distance(lng, lat, alert.longitude, alert.latitude)
            if dist <= 2.0:  # 2.0 km radius
                nearby_alerts.append({
                    "alert_id": str(alert.id),
                    "user_name": f"{alert.user.first_name} {alert.user.last_name}",
                    "distance_km": round(dist, 2),
                    "latitude": float(alert.latitude),
                    "longitude": float(alert.longitude),
                    "trigger_type": alert.trigger_type,
                    "created_at": alert.created_at
                })

        return Response(nearby_alerts, status=status.HTTP_200_OK)


class AcceptAlertResponseView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, alert_id):
        alert = get_object_or_404(Alert, id=alert_id, status='ACTIVE')
        
        # Create response dispatch log
        response_obj, created = AlertResponse.objects.get_or_create(
            alert=alert,
            responder=request.user,
            defaults={
                'status': 'ACCEPTED',
                'accepted_at': timezone.now()
            }
        )

        if not created:
            # If already exists, update status
            response_obj.status = 'ACCEPTED'
            response_obj.accepted_at = timezone.now()
            response_obj.save()

        # Alert the victim user via WebSocket Channels broadcast
        channel_layer = get_channel_layer()
        if channel_layer:
            async_to_sync(channel_layer.group_send)(
                f"sos_{alert.id}",
                {
                    "type": "sos_assistance_broadcast",
                    "data": {
                        "event": "assistance_accepted",
                        "responder_id": str(request.user.id),
                        "responder_name": f"{request.user.first_name} {request.user.last_name}",
                        "responder_phone": request.user.phone or "",
                        "eta_seconds": 180  # Mock ETA
                    }
                }
            )

        return Response({
            "message": "Assistance request accepted successfully.",
            "details": AlertResponseSerializer(response_obj).data
        }, status=status.HTTP_200_OK)


class UpdateResponseStatusView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        response_id = request.data.get('response_id')
        new_status = request.data.get('status')
        lat = request.data.get('latitude')
        lng = request.data.get('longitude')

        if not response_id or not new_status:
            return Response({"error": "Missing response_id or status."}, status=status.HTTP_400_BAD_REQUEST)

        response_obj = get_object_or_404(AlertResponse, id=response_id, responder=request.user)
        response_obj.status = new_status

        if lat and lng:
            response_obj.responder_lat = lat
            response_obj.responder_lng = lng

        # Timestamp updates
        if new_status == 'ARRIVED':
            response_obj.arrived_at = timezone.now()
        elif new_status == 'COMPLETED':
            response_obj.completed_at = timezone.now()
        elif new_status == 'CANCELLED':
            response_obj.cancelled_at = timezone.now()

        response_obj.save()

        # Update tracking loved ones/victim via channel layers
        channel_layer = get_channel_layer()
        if channel_layer:
            async_to_sync(channel_layer.group_send)(
                f"sos_{response_obj.alert.id}",
                {
                    "type": "sos_assistance_broadcast",
                    "data": {
                        "event": "responder_status_changed",
                        "responder_id": str(request.user.id),
                        "status": new_status,
                        "latitude": float(lat) if lat else None,
                        "longitude": float(lng) if lng else None
                    }
                }
            )

        return Response({
            "message": "Response status updated successfully.",
            "details": AlertResponseSerializer(response_obj).data
        }, status=status.HTTP_200_OK)
