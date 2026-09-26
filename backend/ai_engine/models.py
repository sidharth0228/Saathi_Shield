import uuid
from django.db import models
from django.conf import settings

class ThreatAssessment(models.Model):
    RISK_CHOICES = (
        ('SAFE', 'Safe'),
        ('SUSPICIOUS', 'Suspicious'),
        ('DANGEROUS', 'Dangerous'),
    )

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='threat_assessments')
    travel_session = models.ForeignKey('travel.TravelSession', on_delete=models.SET_NULL, null=True, blank=True, related_name='threat_assessments')
    alert = models.ForeignKey('alerts.Alert', on_delete=models.SET_NULL, null=True, blank=True, related_name='threat_assessments')
    latitude = models.DecimalField(max_digits=9, decimal_places=6)
    longitude = models.DecimalField(max_digits=9, decimal_places=6)
    risk_score = models.DecimalField(max_digits=5, decimal_places=2)
    risk_label = models.CharField(max_length=15, choices=RISK_CHOICES, default='SAFE')
    factors_json = models.JSONField()
    assessed_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'ai_threatassessment'
        ordering = ['-assessed_at']

    def __str__(self):
        return f"ThreatAssessment {self.id} for {self.user.email} - Score {self.risk_score} ({self.risk_label})"
