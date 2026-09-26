from celery import shared_task
from django.utils import timezone
import logging

from .models import TravelSession
from alerts.models import Alert
from alerts.tasks import dispatch_sos_notifications_task

logger = logging.getLogger(__name__)

@shared_task
def monitor_active_travel_sessions_task():
    """
    Scans for active travel sessions that have gone stale (no ping for > 5 minutes).
    Escalates status to SOS_TRIGGERED and dispatches alerts.
    """
    now = timezone.now()
    cutoff_time = now - timezone.timedelta(minutes=5)
    
    stale_sessions = TravelSession.objects.filter(status='ACTIVE')
    escalated_count = 0

    for session in stale_sessions:
        last_ping = session.location_history.order_by('-timestamp').first()
        last_activity = last_ping.timestamp if last_ping else session.start_time

        if last_activity < cutoff_time:
            # Set status to SOS triggered
            session.status = 'SOS_TRIGGERED'
            session.save()

            # Create an SOS Alert
            alert = Alert.objects.create(
                user=session.user,
                travel_session=session,
                latitude=session.current_lat or session.source_lat,
                longitude=session.current_lng or session.source_lng,
                trigger_type='ROUTE_DEVIATION',
                status='ACTIVE'
            )

            # Fire off background alerts dispatcher
            dispatch_sos_notifications_task.delay(str(alert.id))
            escalated_count += 1
            logger.warning(f"Travel session {session.id} escalated due to inactivity timeout.")

    return f"Completed check. Escalated {escalated_count} inactive sessions."
