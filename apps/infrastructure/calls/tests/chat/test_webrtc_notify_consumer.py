"""
TestWebRTCNotifyConsumer
"""

from typing import List

import pytest
from channels.testing import WebsocketCommunicator
from channels.routing import URLRouter
from channels.db import database_sync_to_async
from django.contrib.auth import get_user_model
from django.contrib.auth.models import AnonymousUser

from apps.infrastructure.calls.tests.routing import websocket_urlpatterns
from apps.infrastructure.users.models.tables import User as USER
from apps.infrastructure.calls.repository import (
    CallRecordRepository,
)


User = get_user_model()


@pytest.mark.asyncio
@pytest.mark.django_db(transaction=True)
class TestWebRTCNotifyConsumer:
    """
    TestWebRTCNotifyConsumer
    """

    async def test_a_connect_to_notify_channel(
        self,
        initiator: USER,
        participants: List[USER],
        settings,
    ):
        """
        Tests invite users to call
        """
        application = URLRouter(websocket_urlpatterns)

        # add users to notify
        notify1 = WebsocketCommunicator(application=application, path="/ws/notify/")
        # notify1 authenticates to scope
        notify1.scope["user"] = initiator  # type: ignore
        # connect notify1
        notify1_connect, _ = await notify1.connect()
        assert notify1_connect is True
        #  notify1 message. First message should be connection_success
        notify1_response1 = await notify1.receive_json_from(timeout=2)
        assert notify1_response1["type"] == "connection_success"
        assert notify1_response1["message"] == "Connected to notifications channel"

        notify2 = WebsocketCommunicator(application=application, path="/ws/notify/")
        # notify2 authenticates to scope
        notify2.scope["user"] = participants[0]  # type: ignore
        # connect notify2
        notify2_connect, _ = await notify2.connect()
        assert notify2_connect is True
        #  notify2 message. First message should be connection_success
        notify2_response1 = await notify2.receive_json_from(timeout=2)
        assert notify2_response1["type"] == "connection_success"
        assert notify2_response1["message"] == "Connected to notifications channel"

    async def test_b_webrtc_reject_anonymous(
        self,
        settings,
    ):
        """
        AnonymousUser should be rejected with code=4001.
        """

        application = URLRouter(websocket_urlpatterns)

        communicator = WebsocketCommunicator(
            application=application, path="/ws/notify/"
        )
        communicator.scope["user"] = AnonymousUser()  # type: ignore

        connected, subprotocol = await communicator.connect(timeout=5)
        # Should NOT connect
        assert connected is True
        # assert subprotocol == 4001

        close_message = await communicator.receive_output(timeout=3)
        print("close_message: ", close_message)

        assert close_message["type"] == "websocket.close"

        expected_close_code = 4001
        assert close_message["code"] == expected_close_code

    async def test_c_accept_call(
        self,
        initiator: USER,
        participants: List[USER],
        settings,
    ):
        """
        Tests accept call
        """
        application = URLRouter(websocket_urlpatterns)

        call = await database_sync_to_async(CallRecordRepository.create_group_call)(
            initiator_id=initiator.id,
            participant_ids=[participants[0].id, participants[1].id],
            call_type="voice",
            title="Test Call",
        )

        # add users to call
        call1_communicator1 = WebsocketCommunicator(
            application=application, path=f"/ws/calls/{call.id}/"
        )
        # notify1 authenticates to scope
        call1_communicator1.scope["user"] = initiator  # type: ignore
        # connect notify1
        notify1_connect, _ = await call1_communicator1.connect()
        assert notify1_connect is True
        #  notify1 message. First message should be connection_success
        notify1_response1 = await call1_communicator1.receive_json_from(timeout=2)
        assert notify1_response1["type"] == "connection_success"

        notify2_communicator2 = WebsocketCommunicator(
            application=application, path="/ws/notify/"
        )
        # notify2 authenticates to scope
        notify2_communicator2.scope["user"] = participants[0]  # type: ignore
        # connect notify2
        notify2_connect, _ = await notify2_communicator2.connect()
        assert notify2_connect is True
        #  notify2 message. First message should be connection_success
        notify2_response1 = await notify2_communicator2.receive_json_from(timeout=2)
        assert notify2_response1["type"] == "connection_success"
        assert notify2_response1["message"] == "Connected to notifications channel"

        # notify2 send
        await notify2_communicator2.send_json_to(
            {"type": "accept_call", "call_id": call.id}
        )

        notify1_response2 = await call1_communicator1.receive_json_from(timeout=5)
        print("notify1_response2: ", notify1_response2)
        assert notify1_response2["type"] == "call_accepted"

    async def test_d_decline_call(
        self,
        initiator: USER,
        participants: List[USER],
        settings,
    ):
        """
        Tests decline call
        """
        application = URLRouter(websocket_urlpatterns)

        call = await database_sync_to_async(CallRecordRepository.create_group_call)(
            initiator_id=initiator.id,
            participant_ids=[participants[0].id, participants[1].id],
            call_type="voice",
            title="Test Call",
        )

        # add users to call
        call1_communicator1 = WebsocketCommunicator(
            application=application, path=f"/ws/calls/{call.id}/"
        )
        # notify1 authenticates to scope
        call1_communicator1.scope["user"] = initiator  # type: ignore
        # connect notify1
        notify1_connect, _ = await call1_communicator1.connect()
        assert notify1_connect is True
        #  notify1 message. First message should be connection_success
        notify1_response1 = await call1_communicator1.receive_json_from(timeout=2)
        assert notify1_response1["type"] == "connection_success"

        notify2_communicator2 = WebsocketCommunicator(
            application=application, path="/ws/notify/"
        )
        # notify2 authenticates to scope
        notify2_communicator2.scope["user"] = participants[0]  # type: ignore
        # connect notify2
        notify2_connect, _ = await notify2_communicator2.connect()
        assert notify2_connect is True
        #  notify2 message. First message should be connection_success
        notify2_response1 = await notify2_communicator2.receive_json_from(timeout=2)
        assert notify2_response1["type"] == "connection_success"
        assert notify2_response1["message"] == "Connected to notifications channel"

        # notify2 send
        await notify2_communicator2.send_json_to(
            {"type": "decline_call", "call_id": call.id}
        )

        notify1_response2 = await call1_communicator1.receive_json_from(timeout=5)
        print("notify1_response2: ", notify1_response2)
        assert notify1_response2["type"] == "call_declined"

        await notify2_communicator2.disconnect()
        await call1_communicator1.disconnect()
