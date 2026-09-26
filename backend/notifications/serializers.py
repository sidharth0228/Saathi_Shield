from rest_framework import serializers
from .models import Notification, DisasterAlert

class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = ['id', 'title', 'message', 'notification_type', 'is_read', 'sent_at']
        read_only_fields = ['id', 'sent_at']


class DisasterAlertSerializer(serializers.ModelSerializer):
    class Meta:
        model = DisasterAlert
        fields = ['id', 'title', 'message', 'event_type', 'severity', 'location_center_lat', 'location_center_lng', 'radius_meters', 'created_at', 'expires_at']
        read_only_fields = ['id', 'created_at']
