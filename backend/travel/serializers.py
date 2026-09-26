from rest_framework import serializers
from .models import TravelSession

class TravelSessionSerializer(serializers.ModelSerializer):
    class Meta:
        model = TravelSession
        fields = ['id', 'source_address', 'source_lat', 'source_lng', 'dest_address', 'dest_lat', 'dest_lng', 'status', 'risk_level', 'route_geojson', 'expected_duration_minutes', 'start_time']
        read_only_fields = ['id', 'status', 'risk_level', 'route_geojson', 'start_time']

    def create(self, validated_data):
        user = self.context['request'].user
        
        s_lat = float(validated_data['source_lat'])
        s_lng = float(validated_data['source_lng'])
        d_lat = float(validated_data['dest_lat'])
        d_lng = float(validated_data['dest_lng'])
        
        # Simulate route details for fallback
        steps = 10
        route_coordinates = []
        for i in range(steps + 1):
            ratio = i / steps
            lat_pt = s_lat + (d_lat - s_lat) * ratio
            lng_pt = s_lng + (d_lng - s_lng) * ratio
            route_coordinates.append([lng_pt, lat_pt])

        route_geojson = {
            "type": "Feature",
            "properties": {},
            "geometry": {
                "type": "LineString",
                "coordinates": route_coordinates
            }
        }

        # Build travel session with planned route parameters
        return TravelSession.objects.create(
            user=user,
            route_geojson=route_geojson,
            status='ACTIVE',
            **validated_data
        )


class TravelPingSerializer(serializers.Serializer):
    session_id = serializers.UUIDField()
    current_lat = serializers.DecimalField(max_digits=9, decimal_places=6)
    current_lng = serializers.DecimalField(max_digits=9, decimal_places=6)
    speed_mps = serializers.DecimalField(max_digits=5, decimal_places=2, default=0.0)
