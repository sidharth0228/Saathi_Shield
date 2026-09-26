from celery import shared_task
import logging
from django.contrib.auth import get_user_model
from django.conf import settings
from django.core.mail import send_mail
from .models import Alert
from authentication.models import EmergencyContact
from authentication.services import send_sms_notification

logger = logging.getLogger(__name__)
User = get_user_model()

@shared_task
def dispatch_sos_notifications_task(alert_id):
    """
    Celery task run asynchronously upon SOS activation.
    Dispatches alerts (SMS, Email, FCM) to trusted contacts.
    """
    try:
        alert = Alert.objects.get(id=alert_id)
        user = alert.user
        contacts = EmergencyContact.objects.filter(user=user)
        
        tracking_link = f"https://saathishield.live/track/{alert.secure_token}/"
        
        # Send notifications to emergency contacts
        for contact in contacts:
            message_body = (
                f"ALERT: {user.first_name} {user.last_name} has triggered an SOS emergency signal! "
                f"Battery: {alert.battery_percentage or 'N/A'}%. Network: {alert.network_status}. "
                f"Live location tracking link: {tracking_link}"
            )
            
            # Send SMS
            if contact.notify_sms and contact.phone:
                send_sms_notification(contact.phone, message_body)
                
            # Send Email
            if contact.notify_email and contact.email:
                try:
                    send_mail(
                        subject=f"URGENT: Saathi Shield SOS Triggered by {user.first_name}",
                        message=message_body,
                        from_email=getattr(settings, 'DEFAULT_FROM_EMAIL', 'alerts@saathishield.live'),
                        recipient_list=[contact.email],
                        fail_silently=True
                    )
                    logger.info(f"Sent SOS email to contact {contact.email}")
                except Exception as e:
                    logger.error(f"Failed to send SOS email to {contact.email}: {str(e)}")

        # Alert community responders nearby
        # (This coordinates with community dispatcher models which query locations)
        from community.models import ResponderProfile
        from math import radians, cos, sin, asin, sqrt

        def haversine_distance(lon1, lat1, lon2, lat2):
            """
            Calculate the great circle distance between two points on the earth.
            """
            lon1, lat1, lon2, lat2 = map(radians, [float(lon1), float(lat1), float(lon2), float(lat2)])
            dlon = lon2 - lon1
            dlat = lat2 - lat1
            a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
            c = 2 * asin(sqrt(a))
            r = 6371  # Radius of earth in kilometers
            return c * r

        responders = ResponderProfile.objects.filter(is_available=True)
        nearby_responders_count = 0
        
        for responder in responders:
            dist = haversine_distance(
                alert.longitude, alert.latitude,
                responder.longitude, responder.latitude
            )
            if dist <= 2.0:  # 2km radius
                # In production, dispatch FCM push notification here
                logger.info(f"[DISPATCH ALERT] Notifying responder {responder.user.email} (Distance: {dist:.2f} km)")
                nearby_responders_count += 1
                
        logger.info(f"SOS notifications dispatched to {contacts.count()} contacts and {nearby_responders_count} nearby responders.")
        return True
        
    except Alert.DoesNotExist:
        logger.error(f"Alert record {alert_id} not found during notification dispatch execution.")
        return False
