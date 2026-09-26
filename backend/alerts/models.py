import uuid
import secrets
from django.db import models
from django.conf import settings

class Alert(models.Model):
    TRIGGER_CHOICES = (
        ('ONE_TAP_SOS', 'One-Tap SOS'),
        ('VOICE_COMMAND', 'Voice Command'),
        ('FALL_DETECTED', 'Fall Detected'),
        ('ROUTE_DEVIATION', 'Route Deviation'),
        ('AUDIO_DISTRESS', 'Audio Distress'),
        ('MEDICAL_EMERGENCY', 'Medical Emergency'),
    )

    STATUS_CHOICES = (
        ('ACTIVE', 'Active'),
        ('RESOLVED', 'Resolved'),
        ('FALSE_ALARM', 'False Alarm'),
    )

    NETWORK_CHOICES = (
        ('EXCELLENT', 'Excellent'),
        ('GOOD', 'Good'),
        ('POOR', 'Poor'),
        ('OFFLINE', 'Offline'),
    )

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='triggered_alerts')
    # Use string reference to avoid circular dependencies with travel app
    travel_session = models.ForeignKey('travel.TravelSession', on_delete=models.SET_NULL, null=True, blank=True, related_name='alerts')
    latitude = models.DecimalField(max_digits=9, decimal_places=6)
    longitude = models.DecimalField(max_digits=9, decimal_places=6)
    trigger_type = models.CharField(max_length=20, choices=TRIGGER_CHOICES, default='ONE_TAP_SOS')
    battery_percentage = models.IntegerField(null=True, blank=True)
    network_status = models.CharField(max_length=20, choices=NETWORK_CHOICES, default='GOOD')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='ACTIVE')
    secure_token = models.CharField(max_length=64, unique=True, editable=False)
    created_at = models.DateTimeField(auto_now_add=True)
    resolved_at = models.DateTimeField(null=True, blank=True)
    resolved_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name='resolved_alerts')

    def save(self, *args, **kwargs):
        if not self.secure_token:
            self.secure_token = secrets.token_hex(20)
        super().save(*args, **kwargs)

    def __str__(self):
        return f"Alert {self.id} - {self.user} ({self.status})"


class AlertLocationHistory(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    alert = models.ForeignKey(Alert, on_delete=models.CASCADE, related_name='location_history')
    latitude = models.DecimalField(max_digits=9, decimal_places=6)
    longitude = models.DecimalField(max_digits=9, decimal_places=6)
    battery_percentage = models.IntegerField(null=True, blank=True)
    timestamp = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['timestamp']
        verbose_name_plural = "Alert location histories"


class EvidenceFile(models.Model):
    FILE_TYPE_CHOICES = (
        ('AUDIO', 'Audio Recording'),
        ('VIDEO_FRONT', 'Front Video Recording'),
        ('VIDEO_BACK', 'Rear Video Recording'),
        ('IMAGE', 'Snapshot Image'),
    )

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    alert = models.ForeignKey(Alert, on_delete=models.CASCADE, related_name='evidence_files')
    file_url = models.URLField(max_length=512)
    file_type = models.CharField(max_length=20, choices=FILE_TYPE_CHOICES)
    encryption_iv = models.CharField(max_length=64)
    file_size_bytes = models.BigIntegerField()
    duration_seconds = models.IntegerField(null=True, blank=True)
    uploaded_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Evidence {self.id} ({self.file_type}) for Alert {self.alert_id}"
