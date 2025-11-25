"""
Channels WS Routing
"""

from django.urls import re_path

from apps.infrastructure.calls.ws_consumer import (
    WebRTCConsumer,
    WebRTCNotifyConsumer,
    DiscoverConsumer,
)

websocket_urlpatterns = [
    re_path(r"ws/calls/(?P<call_id>[^/]+)/$", WebRTCConsumer.as_asgi()),  # type: ignore
    re_path(r"ws/notify/$", WebRTCNotifyConsumer.as_asgi()),  # type: ignore
    re_path(r"ws/discover/$", DiscoverConsumer.as_asgi()),  # type: ignore
]
