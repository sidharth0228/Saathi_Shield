import uuid
from django.db import models
from django.conf import settings

class Notification(models.Model):
    TYPE_CHOICES = (
        ('SOS_ALERT', 'SOS Alert Update'),
        ('TRAVEL_UPDATE', 'Travel Update'),
        ('DISASTER_ALERT', 'Disaster Warning'),
        ('SYSTEM_INFO', 'System Information'),
    )

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='notifications')
    title = models.CharField(max_length=255)
    message = models.TextField()
    notification_type = models.CharField(max_length=20, choices=TYPE_CHOICES, default='SYSTEM_INFO')
    is_read = models.BooleanField(default=False)
    sent_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.title} for {self.user} (Read: {self.is_read})"


class DisasterAlert(models.Model):
    EVENT_CHOICES = (
        ('FLOOD', 'Flood'),
        ('CYCLONE', 'Cyclone'),
        ('EARTHQUAKE', 'Earthquake'),
        ('FIRE', 'Fire'),
        ('PUBLIC_EMERGENCY', 'Public Emergency'),
    )

    SEVERITY_CHOICES = (
        ('INFO', 'Informational'),
        ('WARNING', 'Warning'),
        ('CRITICAL', 'Critical Alert'),
    )

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    title = models.CharField(max_length=255)
    message = models.TextField()
    event_type = models.CharField(max_length=20, choices=EVENT_CHOICES, default='PUBLIC_EMERGENCY')
    severity = models.CharField(max_length=15, choices=SEVERITY_CHOICES, default='WARNING')
    location_center_lat = models.DecimalField(max_digits=9, decimal_places=6)
    location_center_lng = models.DecimalField(max_digits=9, decimal_places=6)
    radius_meters = models.IntegerField(default=5000)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True)

    def __str__(self):
        return f"Disaster: {self.title} ({self.severity})"
