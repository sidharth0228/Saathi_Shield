from rest_framework import serializers
from django.contrib.auth import get_user_model
from .models import ResponderProfile, AlertResponse
from authentication.serializers import UserSerializer

User = get_user_model()

class ResponderProfileSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)

    class Meta:
        model = ResponderProfile
        fields = ['id', 'user', 'latitude', 'longitude', 'is_available', 'privacy_share_location', 'last_active_at']
        read_only_fields = ['id', 'user', 'last_active_at']

    def create(self, validated_data):
        user = self.context['request'].user
        profile, created = ResponderProfile.objects.update_or_create(
            user=user,
            defaults=validated_data
        )
        return profile


class AlertResponseSerializer(serializers.ModelSerializer):
    responder = UserSerializer(read_only=True)

    class Meta:
        model = AlertResponse
        fields = ['id', 'alert', 'responder', 'status', 'responder_lat', 'responder_lng', 'accepted_at', 'arrived_at', 'completed_at', 'cancelled_at']
        read_only_fields = ['id', 'alert', 'responder', 'accepted_at', 'arrived_at', 'completed_at', 'cancelled_at']
