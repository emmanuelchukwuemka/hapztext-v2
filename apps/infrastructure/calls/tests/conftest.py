"""
Conftest
"""

import uuid
import pytest
from rest_framework.test import APIClient
from channels.testing import WebsocketCommunicator
from django.contrib.auth import get_user_model

from config.asgi import application
from apps.infrastructure.calls.tests.factories import (
    UserFactory,
    CallRecordFactory,
    CallParticipantFactory,
)

User = get_user_model()


@pytest.fixture
def api_client_fx():
    """
    api client
    """
    return APIClient()


@pytest.fixture(autouse=True)
def configure_channels(settings):
    """
    Use in-memory channel layer for all tests.
    """
    settings.CHANNEL_LAYERS = {
        "default": {
            "BACKEND": "channels.layers.InMemoryChannelLayer",
        }
    }


@pytest.fixture
def django_user_model():
    """
    django_user_model
    """
    return User


@pytest.fixture
def user_fx():
    """
    user
    """
    return UserFactory()


@pytest.fixture
def auth_client_fx(user_fx):
    """
    auth client
    """
    client = APIClient()
    client.force_authenticate(user=user_fx, token="12345678910")
    return client


@pytest.fixture
def call_record_fx():
    """
    call record
    """
    return CallRecordFactory()


@pytest.fixture
def call_with_participants_fx():
    """
    call with participants
    """
    call = CallRecordFactory()
    CallParticipantFactory(call=call)
    CallParticipantFactory(call=call)
    return call


@pytest.fixture
async def ws_client_fx():
    """
    WebSocket test client for Channels.
    """
    communicator = WebsocketCommunicator(application, "/ws/chats/test/")
    connected, _ = await communicator.connect()
    assert connected
    yield communicator
    await communicator.disconnect()


@pytest.fixture
def users_fx(django_user_model):
    """
    users fx
    """
    return [
        django_user_model.objects.create_user(
            username=str(uuid.uuid4()).replace("-", ""),
            password="Johnson1234#",
            email=f"{i}@test.com",
        )
        for i in range(3)
    ]


@pytest.fixture
def initiator(users_fx):
    """
    initiator
    """
    return users_fx[0]


@pytest.fixture
def participants(users_fx):
    """
    Participants
    """
    return users_fx[1:]
