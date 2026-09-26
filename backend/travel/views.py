import logging
from django.utils import timezone
from django.core.cache import cache
from rest_framework import status, generics
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.shortcuts import get_object_or_404
from math import radians, cos, sin, asin, sqrt

from .models import TravelSession, TravelLocationHistory
from .serializers import TravelSessionSerializer, TravelPingSerializer
from alerts.models import Alert
from alerts.tasks import dispatch_sos_notifications_task

logger = logging.getLogger(__name__)

def haversine_distance(lon1, lat1, lon2, lat2):
    """
    Calculate the great circle distance between two points on the earth in km.
    """
    lon1, lat1, lon2, lat2 = map(radians, [float(lon1), float(lat1), float(lon2), float(lat2)])
    dlon = lon2 - lon1
    dlat = lat2 - lat1
    a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
    c = 2 * asin(sqrt(a))
    r = 6371  # Radius of earth in kilometers
    return c * r

def check_route_deviation(session, current_lat, current_lng):
    """
    Checks if current coordinates are further than 500 meters (0.5 km)
    from all coordinates in the planned route geojson.
    """
    route_json = session.route_geojson
    if not route_json or 'geometry' not in route_json or 'coordinates' not in route_json['geometry']:
        return False

    coordinates = route_json['geometry']['coordinates']  # Array of [lng, lat]
    min_distance = float('inf')

    for pt in coordinates:
        dist = haversine_distance(current_lng, current_lat, pt[0], pt[1])
        if dist < min_distance:
            min_distance = dist

    # Deviated if minimum distance to planned path > 0.5 km (500 meters)
    return min_distance > 0.5


class TravelSessionStartView(generics.CreateAPIView):
    serializer_class = TravelSessionSerializer
    permission_classes = [IsAuthenticated]


class TravelPingView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = TravelPingSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        session_id = serializer.validated_data['session_id']
        current_lat = serializer.validated_data['current_lat']
        current_lng = serializer.validated_data['current_lng']
        speed_mps = serializer.validated_data['speed_mps']

        session = get_object_or_404(TravelSession, id=session_id, user=request.user, status__in=['ACTIVE', 'DEVIATED'])

        # Log coordinate history point
        TravelLocationHistory.objects.create(
            session=session,
            latitude=current_lat,
            longitude=current_lng,
            speed_mps=speed_mps
        )

        # Update last coordinates
        session.current_lat = current_lat
        session.current_lng = current_lng

        # Route deviation checks
        is_deviated = check_route_deviation(session, current_lat, current_lng)
        risk_score = 10.0  # Base level safe
        risk_label = 'LOW'

        if is_deviated:
            session.status = 'DEVIATED'
            session.risk_level = 'HIGH'
            risk_score = 75.0
            risk_label = 'DANGEROUS'

            # Increment consecutive anomaly counter
            cache_key = f"travel_anomalies:{session_id}"
            anomalies_count = cache.get(cache_key, 0) + 1
            cache.set(cache_key, anomalies_count, timeout=600)

            # Auto trigger SOS if anomalies exceed 3 consecutive pings
            if anomalies_count >= 3:
                session.status = 'SOS_TRIGGERED'
                session.save()

                # Trigger SOS Alert automatically
                alert = Alert.objects.create(
                    user=request.user,
                    travel_session=session,
                    latitude=current_lat,
                    longitude=current_lng,
                    trigger_type='ROUTE_DEVIATION',
                    status='ACTIVE'
                )
                dispatch_sos_notifications_task.delay(str(alert.id))
                logger.warning(f"SOS auto triggered: TravelSession {session.id} exceeded deviation threshold.")
                
                return Response({
                    "risk_score": 100.0,
                    "risk_label": "DANGEROUS",
                    "route_deviation_detected": True,
                    "sos_triggered": True,
                    "alert_id": str(alert.id)
                }, status=status.HTTP_200_OK)

        else:
            # Reset anomaly counter if user returns to planned path
            cache.delete(f"travel_anomalies:{session_id}")
            session.status = 'ACTIVE'
            session.risk_level = 'LOW'

        session.save()

        return Response({
            "risk_score": risk_score,
            "risk_label": risk_label,
            "route_deviation_detected": is_deviated,
            "sos_triggered": False
        }, status=status.HTTP_200_OK)


class TravelSessionEndView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        session_id = request.data.get('session_id')
        if not session_id:
            return Response({"error": "Missing session_id."}, status=status.HTTP_400_BAD_REQUEST)

        session = get_object_or_404(TravelSession, id=session_id, user=request.user)
        
        if session.status in ['COMPLETED', 'CANCELLED']:
            return Response({"message": f"Travel session was already closed ({session.status})."})

        session.status = 'COMPLETED'
        session.actual_end_time = timezone.now()
        session.save()

        # Invalidate anomalies cache counters
        cache.delete(f"travel_anomalies:{session_id}")

        return Response({
            "message": "Travel session closed successfully. Thank you for traveling safely."
        }, status=status.HTTP_200_OK)
