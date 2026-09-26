from rest_framework import serializers
from django.contrib.auth import get_user_model
from .models import Alert, AlertLocationHistory, EvidenceFile
from authentication.serializers import UserSerializer, MedicalProfileSerializer

User = get_user_model()

class AlertSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)

    class Meta:
        model = Alert
        fields = ['id', 'user', 'travel_session', 'latitude', 'longitude', 'trigger_type', 'battery_percentage', 'network_status', 'status', 'secure_token', 'created_at']
        read_only_fields = ['id', 'user', 'secure_token', 'status', 'created_at']

    def create(self, validated_data):
        user = self.context['request'].user
        return Alert.objects.create(user=user, **validated_data)


class AlertResolveSerializer(serializers.Serializer):
    alert_id = serializers.UUIDField()
    is_false_alarm = serializers.BooleanField(default=False)
    resolution_pin = serializers.CharField(max_length=10, required=False, allow_blank=True)


class EvidenceFileSerializer(serializers.ModelSerializer):
    class Meta:
        model = EvidenceFile
        fields = ['id', 'alert', 'file_url', 'file_type', 'encryption_iv', 'file_size_bytes', 'duration_seconds', 'uploaded_at']
        read_only_fields = ['id', 'uploaded_at']


class AlertLocationHistorySerializer(serializers.ModelSerializer):
    class Meta:
        model = AlertLocationHistory
        fields = ['latitude', 'longitude', 'battery_percentage', 'timestamp']


class AlertDetailSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)
    location_history = AlertLocationHistorySerializer(many=True, read_only=True)
    evidence_files = EvidenceFileSerializer(many=True, read_only=True)
    medical_profile = serializers.SerializerMethodField()

    class Meta:
        model = Alert
        fields = ['id', 'user', 'travel_session', 'latitude', 'longitude', 'trigger_type', 'battery_percentage', 'network_status', 'status', 'secure_token', 'created_at', 'resolved_at', 'location_history', 'evidence_files', 'medical_profile']

    def get_medical_profile(self, obj):
        # Only expose medical details for active alerts to authorized responders / contacts
        if hasattr(obj.user, 'medical_profile'):
            return MedicalProfileSerializer(obj.user.medical_profile).data
        return None
