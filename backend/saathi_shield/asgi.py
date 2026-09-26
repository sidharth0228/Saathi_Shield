import os
from django.core.asgi import get_asgi_application
from channels.routing import ProtocolTypeRouter, URLRouter
from channels.auth import AuthMiddlewareStack

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'saathi_shield.settings')

# Initialize Django ASGI application early to populate app registry
django_asgi_app = get_asgi_application()

# We import routing details from our alerts application
import alerts.routing

application = ProtocolTypeRouter({
    "http": django_asgi_app,
    "websocket": AuthMiddlewareStack(
        URLRouter(
            alerts.routing.websocket_urlpatterns
        )
    ),
})
