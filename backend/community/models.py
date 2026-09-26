import uuid
from django.db import models
from django.conf import settings

class ResponderProfile(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='responder_profile')
    latitude = models.DecimalField(max_digits=9, decimal_places=6)
    longitude = models.DecimalField(max_digits=9, decimal_places=6)
    is_available = models.BooleanField(default=True)
    privacy_share_location = models.BooleanField(default=True)
    last_active_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Responder: {self.user.email} (Available: {self.is_available})"


class AlertResponse(models.Model):
    STATUS_CHOICES = (
        ('DISPATCHED', 'Dispatched'),
        ('ACCEPTED', 'Accepted'),
        ('EN_ROUTE', 'En Route'),
        ('ARRIVED', 'Arrived'),
        ('COMPLETED', 'Completed'),
        ('CANCELLED', 'Cancelled'),
    )

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    alert = models.ForeignKey('alerts.Alert', on_delete=models.CASCADE, related_name='responses')
    responder = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='alert_responses')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='DISPATCHED')
    responder_lat = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    responder_lng = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    accepted_at = models.DateTimeField(null=True, blank=True)
    arrived_at = models.DateTimeField(null=True, blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    cancelled_at = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return f"Response {self.id} for Alert {self.alert_id} ({self.status})"
