from rest_framework import serializers
from .models import ThreatAssessment

class ThreatAssessmentSerializer(serializers.ModelSerializer):
    factors = serializers.JSONField(source='factors_json')

    class Meta:
        model = ThreatAssessment
        fields = ['id', 'latitude', 'longitude', 'risk_score', 'risk_label', 'factors', 'assessed_at']
        read_only_fields = ['id', 'risk_score', 'risk_label', 'factors', 'assessed_at']
