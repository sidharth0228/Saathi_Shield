import jwt
from channels.generic.websocket import AsyncJsonWebsocketConsumer
from channels.db import database_sync_to_async
from django.contrib.auth.models import AnonymousUser
from django.conf import settings
from django.contrib.auth import get_user_model
from .models import Alert, AlertLocationHistory

User = get_user_model()

@database_sync_to_async
def get_user_from_token(token_str):
    try:
        # Decodes the standard simplejwt signed token
        payload = jwt.decode(token_str, settings.SIMPLE_JWT['SIGNING_KEY'], algorithms=[settings.SIMPLE_JWT['ALGORITHM']])
        user_id = payload.get('user_id')
        return User.objects.get(id=user_id)
    except Exception:
        return AnonymousUser()

@database_sync_to_async
def save_alert_location(alert_id, latitude, longitude, battery):
    try:
        alert = Alert.objects.get(id=alert_id)
        # Log to location logs table
        AlertLocationHistory.objects.create(
            alert=alert,
            latitude=latitude,
            longitude=longitude,
            battery_percentage=battery
        )
        # Update current coordinates on the main Alert object
        alert.latitude = latitude
        alert.longitude = longitude
        alert.save()
        return True
    except Exception:
        return False

class SOSConsumer(AsyncJsonWebsocketConsumer):
    async def connect(self):
        self.alert_id = self.scope['url_route']['kwargs']['alert_id']
        self.group_name = f"sos_{self.alert_id}"

        # Parse token from query parameters: /ws/sos/<alert_id>/?token=<token>
        query_string = self.scope.get('query_string', b'').decode()
        token = ""
        if 'token=' in query_string:
            token = query_string.split('token=')[-1].split('&')[0]

        self.user = await get_user_from_token(token)

        # Join the tracking channel group
        await self.channel_layer.group_add(
            self.group_name,
            self.channel_name
        )
        await self.accept()

    async def disconnect(self, close_code):
        # Leave the tracking channel group
        await self.channel_layer.group_discard(
            self.group_name,
            self.channel_name
        )

    async def receive_json(self, content):
        event_type = content.get('event')
        
        if event_type == 'location_update':
            # Protect writes: verify user is authenticated
            if isinstance(self.user, AnonymousUser):
                await self.send_json({"error": "Unauthorized. Authenticated connection required to update telemetry."})
                return

            data = content.get('data', {})
            latitude = data.get('latitude')
            longitude = data.get('longitude')
            battery = data.get('battery_percentage')

            if latitude is not None and longitude is not None:
                await save_alert_location(self.alert_id, latitude, longitude, battery)
                
                # Broadcast coordinate updates to all listening sockets (loved ones / responders)
                await self.channel_layer.group_send(
                    self.group_name,
                    {
                        "type": "sos_location_broadcast",
                        "data": {
                            "alert_id": self.alert_id,
                            "latitude": str(latitude),
                            "longitude": str(longitude),
                            "battery_percentage": battery,
                        }
                    }
                )

    async def sos_location_broadcast(self, event):
        """
        Sends telemetry update broadcasts to connected clients.
        """
        await self.send_json({
            "event": "tracker_telemetry",
            "data": event["data"]
        })

    async def sos_assistance_broadcast(self, event):
        """
        Sends responder dispatch updates (assistance accepted / status changed) to clients.
        """
        await self.send_json({
            "event": event["data"]["event"],
            "data": event["data"]
        })
