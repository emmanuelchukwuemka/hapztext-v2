"""
Call Generics
"""

from channels.generic.websocket import AsyncWebsocketConsumer
from channels.generic.websocket import AsyncJsonWebsocketConsumer
from django.contrib.auth.models import AnonymousUser

from apps.infrastructure.users.models.tables import User
from apps.infrastructure.calls.models import CallRecordModel


class CustomAsyncWebsocketConsumer(AsyncWebsocketConsumer):
    """
    CustomAsyncWebsocketConsumer
    """

    user: User | AnonymousUser | None
    other_user_id: str | None = None
    other_user: User | None | AnonymousUser = None
    room_name: str | None = None
    room_group_name: str | None = None
    call_record: CallRecordModel | None = None


class CustomAsyncJsonWebsocketConsumer(AsyncJsonWebsocketConsumer):
    """
    CustomAsyncJsonWebsocketConsumer
    """

    user: User | AnonymousUser | None
    other_user_id: str | None = None
    other_user: User | None = None
    room_name: str | None = None
    room_group_name: str | None = None
    call_group_name: str | None = None
    call_record: CallRecordModel | None = None
    call_id: str | None = None
