from django.utils import timezone
from rest_framework import status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from notifications.models import DisasterAlert
from travel.views import haversine_distance
from .models import ThreatAssessment
from decimal import Decimal

class RouteSafetyScoreView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        lat_str = request.query_params.get('lat')
        lng_str = request.query_params.get('lng')

        if not lat_str or not lng_str:
            return Response({"error": "Latitude and longitude query parameters are required."}, status=status.HTTP_400_BAD_REQUEST)

        try:
            lat = Decimal(lat_str)
            lng = Decimal(lng_str)
        except Exception:
            return Response({"error": "Invalid coordinates format."}, status=status.HTTP_400_BAD_REQUEST)

        # Dynamic factors calculation
        # 1. Check for nearby disaster alerts
        now = timezone.now()
        active_disasters = DisasterAlert.objects.filter(expires_at__gt=now)
        disaster_factor = False
        for disaster in active_disasters:
            dist_km = haversine_distance(lng, lat, disaster.location_center_lng, disaster.location_center_lat)
            radius_km = disaster.radius_meters / 1000.0
            if dist_km <= radius_km:
                disaster_factor = True
                break

        # 2. Time of day / illumination
        current_hour = timezone.localtime(timezone.now()).hour
        is_night = current_hour >= 20 or current_hour < 6

        # Deterministic mock values based on lat/lng coordinates to make it realistic
        coord_sum = int(abs(lat * 100) + abs(lng * 100))
        
        # Crime Index
        if disaster_factor:
            crime_index = "HIGH"
        elif coord_sum % 3 == 0:
            crime_index = "HIGH"
        elif coord_sum % 3 == 1:
            crime_index = "MEDIUM"
        else:
            crime_index = "LOW"

        # Illumination
        if is_night:
            illumination = "LOW"
        elif coord_sum % 4 == 0:
            illumination = "MEDIUM"
        else:
            illumination = "HIGH"

        # Population Density
        if coord_sum % 2 == 0:
            population_density = "HIGH"
        elif coord_sum % 3 == 0:
            population_density = "MEDIUM"
        else:
            population_density = "LOW"

        # Calculate score
        # Base score starts at 15.0
        score = 15.0

        if crime_index == "HIGH":
            score += 35.0
        elif crime_index == "MEDIUM":
            score += 15.0

        if illumination == "LOW":
            score += 25.0
        elif illumination == "MEDIUM":
            score += 10.0

        if population_density == "LOW":
            # Low density late at night increases risk
            score += 10.0

        if disaster_factor:
            score += 30.0

        # Cap score
        score = min(max(score, 0.0), 100.0)

        # Label mapping
        if score <= 35.0:
            label = "SAFE"
        elif score <= 70.0:
            label = "SUSPICIOUS"
        else:
            label = "DANGEROUS"

        factors = {
            "crime_statistics_index": crime_index,
            "illumination_estimate": illumination,
            "population_density_index": population_density
        }

        # Log the threat assessment history
        ThreatAssessment.objects.create(
            user=request.user,
            latitude=lat,
            longitude=lng,
            risk_score=score,
            risk_label=label,
            factors_json=factors
        )

        return Response({
            "safety_score": score,
            "risk_label": label,
            "factors": factors
        }, status=status.HTTP_200_OK)
