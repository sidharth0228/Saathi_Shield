import uuid
from django.db import models
from django.conf import settings

class TravelSession(models.Model):
    STATUS_CHOICES = (
        ('PLANNED', 'Planned'),
        ('ACTIVE', 'Active'),
        ('DEVIATED', 'Deviated'),
        ('SOS_TRIGGERED', 'SOS Triggered'),
        ('COMPLETED', 'Completed'),
        ('CANCELLED', 'Cancelled'),
    )

    RISK_CHOICES = (
        ('LOW', 'Low Risk'),
        ('MEDIUM', 'Medium Risk'),
        ('HIGH', 'High Risk'),
    )

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='travel_sessions')
    source_address = models.CharField(max_length=255)
    source_lat = models.DecimalField(max_digits=9, decimal_places=6)
    source_lng = models.DecimalField(max_digits=9, decimal_places=6)
    dest_address = models.CharField(max_length=255)
    dest_lat = models.DecimalField(max_digits=9, decimal_places=6)
    dest_lng = models.DecimalField(max_digits=9, decimal_places=6)
    current_lat = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    current_lng = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    route_geojson = models.JSONField(null=True, blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='PLANNED')
    risk_level = models.CharField(max_length=10, choices=RISK_CHOICES, default='LOW')
    start_time = models.DateTimeField(auto_now_add=True)
    expected_duration_minutes = models.IntegerField(default=30)
    actual_end_time = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"TravelSession {self.id} - {self.user} ({self.status})"


class TravelLocationHistory(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    session = models.ForeignKey(TravelSession, on_delete=models.CASCADE, related_name='location_history')
    latitude = models.DecimalField(max_digits=9, decimal_places=6)
    longitude = models.DecimalField(max_digits=9, decimal_places=6)
    speed_mps = models.DecimalField(max_digits=5, decimal_places=2, null=True, blank=True)
    timestamp = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['timestamp']
        verbose_name_plural = "Travel location histories"
