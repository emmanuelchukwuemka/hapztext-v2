from django.urls import path
from django.conf import settings

from apps.infrastructure.chat.consumers import ChatConsumer

websocket_urlpatterns = [
    path(
        f"{'ws' if str(settings.BACKEND_DOMAIN).startswith('http://') else 'wss'}/chat/<str:conversation_id>/",
        ChatConsumer.as_asgi(),
    ),
]
