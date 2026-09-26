import os
import uuid
from rest_framework import status, generics, viewsets
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny, IsAuthenticated
from django.shortcuts import get_object_or_404
from django.utils import timezone
from django.core.files.storage import default_storage
from django.core.files.base import ContentFile

from .models import Alert, AlertLocationHistory, EvidenceFile
from .serializers import AlertSerializer, AlertResolveSerializer, AlertDetailSerializer, EvidenceFileSerializer
from .tasks import dispatch_sos_notifications_task

class AlertTriggerView(generics.CreateAPIView):
    serializer_class = AlertSerializer
    permission_classes = [IsAuthenticated]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        alert = serializer.save()

        # Log the initial coordinates to history logs
        AlertLocationHistory.objects.create(
            alert=alert,
            latitude=alert.latitude,
            longitude=alert.longitude,
            battery_percentage=alert.battery_percentage
        )

        # Trigger background Celery notifications task
        dispatch_sos_notifications_task.delay(str(alert.id))

        return Response({
            "alert_id": str(alert.id),
            "secure_token": alert.secure_token,
            "tracking_url": f"https://saathishield.live/track/{alert.secure_token}/",
            "message": "SOS alert registered. Notifications are being dispatched."
        }, status=status.HTTP_201_CREATED)


class AlertResolveView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = AlertResolveSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        alert_id = serializer.validated_data['alert_id']
        is_false_alarm = serializer.validated_data['is_false_alarm']

        # Ensure user owns this alert (or is an Admin/Responder)
        alert = get_object_or_404(Alert, id=alert_id)
        if alert.user != request.user and request.user.role not in ['ADMIN', 'RESPONDER']:
            return Response({"error": "Permission denied. You cannot resolve this alert."}, status=status.HTTP_403_FORBIDDEN)

        alert.status = 'FALSE_ALARM' if is_false_alarm else 'RESOLVED'
        alert.resolved_at = timezone.now()
        alert.resolved_by = request.user
        alert.save()

        return Response({
            "message": "Emergency alert resolved successfully."
        }, status=status.HTTP_200_OK)


class PublicTrackingView(APIView):
    permission_classes = [AllowAny]

    def get(self, request, secure_token):
        alert = get_object_or_404(Alert, secure_token=secure_token)
        serializer = AlertDetailSerializer(alert)
        return Response(serializer.data)


class EvidenceUploadView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        alert_id = request.data.get('alert_id')
        file_type = request.data.get('file_type')
        encryption_iv = request.data.get('encryption_iv')
        uploaded_file = request.FILES.get('file')

        if not all([alert_id, file_type, encryption_iv, uploaded_file]):
            return Response({"error": "Missing required fields (alert_id, file_type, encryption_iv, file)."}, status=status.HTTP_400_BAD_REQUEST)

        alert = get_object_or_404(Alert, id=alert_id, user=request.user)

        # Mock S3 file upload: Save local file inside /media/ directory for local development testing
        file_name = f"evidence/{alert_id}/{uuid.uuid4()}_{uploaded_file.name}"
        stored_path = default_storage.save(file_name, ContentFile(uploaded_file.read()))
        file_url = request.build_absolute_uri(default_storage.url(stored_path))

        evidence = EvidenceFile.objects.create(
            alert=alert,
            file_url=file_url,
            file_type=file_type,
            encryption_iv=encryption_iv,
            file_size_bytes=uploaded_file.size,
            duration_seconds=request.data.get('duration_seconds')
        )

        return Response({
            "evidence_id": str(evidence.id),
            "status": "UPLOADED",
            "message": "Evidence file received and registered."
        }, status=status.HTTP_202_ACCEPTED)
