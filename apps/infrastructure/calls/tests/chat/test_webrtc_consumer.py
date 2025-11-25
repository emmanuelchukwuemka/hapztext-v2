"""
WEBRTC CONSUMER TEST
"""

import asyncio
from typing import List

import pytest
from channels.testing import WebsocketCommunicator
from channels.routing import URLRouter
from channels.db import database_sync_to_async
from django.contrib.auth import get_user_model
from django.contrib.auth.models import AnonymousUser

from apps.infrastructure.calls.tests.routing import websocket_urlpatterns
from apps.infrastructure.calls.repository import (
    CallRecordRepository,
)
from apps.infrastructure.users.models.tables import User as USER


User = get_user_model()


@pytest.mark.asyncio
@pytest.mark.django_db(transaction=True)
class TestWebRTCConsumer:
    """
    TestWebRTCConsumer
    """

    async def test_a_webrtc_connect_success(
        self,
        initiator: USER,
        participants: List[USER],
        settings,
    ):
        """
        A valid authenticated user should successfully connect
        and broadcast `user_connecting` for groups and `direct` for current user only.
        """

        application = URLRouter(websocket_urlpatterns)

        call = await database_sync_to_async(CallRecordRepository.create_group_call)(
            initiator_id=initiator.id,
            participant_ids=[participants[0].id, participants[1].id],
            call_type="voice",
            title="Test Call",
        )

        # initiator connects
        communicator1 = WebsocketCommunicator(
            application=application, path=f"/ws/calls/{call.id}/"
        )

        # initiator authenticates to scope
        communicator1.scope["user"] = initiator  # type: ignore

        connected1, subprotocol = await communicator1.connect()
        assert connected1 is True

        #  initiator message. First message should be connection_success
        connection_success_response1 = await communicator1.receive_json_from(timeout=2)
        assert connection_success_response1["type"] == "connection_success"
        assert isinstance(
            connection_success_response1["data"]["events"]["client_to_send"], list
        )
        assert isinstance(
            connection_success_response1["data"]["events"]["backend_to_send"], list
        )

        # Second user connects
        communicator2 = WebsocketCommunicator(application, f"/ws/calls/{call.id}/")
        # Second user authenticates to scope
        communicator2.scope["user"] = participants[0]  # type: ignore
        connected2, subprotocol = await communicator2.connect()
        assert connected2 is True

        #  second user First message should be connection_success
        connection_success_response2 = await communicator2.receive_json_from(timeout=2)
        assert connection_success_response2["type"] == "connection_success"
        assert isinstance(
            connection_success_response2["data"]["events"]["client_to_send"], list
        )

        # Initiator Second message should be the group broadcast
        group_response1 = await communicator1.receive_json_from(timeout=2)
        assert group_response1["type"] == "user_connecting"
        assert group_response1["data"]["user_id"] == str(participants[0].id)
        assert group_response1["data"]["call_id"] == call.id

        # Second message should NOT arrive because group message is skipped
        with pytest.raises(asyncio.TimeoutError):
            await communicator2.receive_json_from(timeout=1)

        await communicator1.disconnect()

    async def test_b_webrtc_reject_anonymous(
        self,
        settings,
    ):
        """
        AnonymousUser should be rejected with code=4001.
        """

        application = URLRouter(websocket_urlpatterns)

        communicator = WebsocketCommunicator(
            application=application, path="/ws/calls/WYFmOfC7P6pfoe0Exmunc/"
        )
        communicator.scope["user"] = AnonymousUser()  # type: ignore

        connected, subprotocol = await communicator.connect(timeout=5)
        # Should NOT connect
        assert connected is False
        assert subprotocol == 4001

    async def test_c_invalid_call_id_returns_4003(
        self,
        initiator: USER,
        settings,
    ):
        """
        Tests for invalid call id during connection
        """
        application = URLRouter(websocket_urlpatterns)

        communicator = WebsocketCommunicator(
            application=application, path="/ws/calls/swwwwwwwwwwwwwwwwwwww/"
        )

        communicator.scope["user"] = initiator  # type: ignore

        connected, subprotocol = await communicator.connect()
        assert connected is False
        assert subprotocol == 4003

    async def test_d_join_call(
        self,
        initiator: USER,
        participants: List[USER],
        settings,
    ):
        """
        Tests join call
        """
        application = URLRouter(websocket_urlpatterns)

        call = await database_sync_to_async(CallRecordRepository.create_group_call)(
            initiator_id=initiator.id,
            participant_ids=[participants[0].id, participants[1].id],
            call_type="voice",
            title="Test Call",
        )

        # initiator connects
        communicator1 = WebsocketCommunicator(
            application=application, path=f"/ws/calls/{call.id}/"
        )

        # initiator authenticates to scope
        communicator1.scope["user"] = initiator  # type: ignore

        connected1, subprotocol = await communicator1.connect()
        assert connected1 is True

        #  initiator message. First message should be connection_success
        communicator1_response1 = await communicator1.receive_json_from(timeout=2)
        print("communicator1_response1: ", communicator1_response1)
        assert communicator1_response1["type"] == "connection_success"
        assert communicator1_response1["message"] == "Connection successful."

        # Second user connects
        communicator2 = WebsocketCommunicator(application, f"/ws/calls/{call.id}/")
        # Second user authenticates to scope
        communicator2.scope["user"] = participants[0]  # type: ignore
        connected2, subprotocol = await communicator2.connect()
        assert connected2 is True

        #  second user First message should be connection_success
        communicator2_response1 = await communicator2.receive_json_from(timeout=2)
        print("communicator2_response1: ", communicator2_response1)
        assert communicator2_response1["type"] == "connection_success"
        assert communicator2_response1["message"] == "Connection successful."

        # initiator receives user connecting
        communicator1_response2 = await communicator1.receive_json_from(timeout=2)
        print("communicator1_response2: ", communicator1_response2)
        assert communicator1_response2["type"] == "user_connecting"
        assert (
            communicator1_response2["message"]
            == f"{participants[0].username} User is connecting"
        )

        # # second user send jon call
        await communicator2.send_json_to({"type": "join_call"})

        # second joining user receives current state.
        communicator2_response3 = await communicator2.receive_json_from(timeout=2)
        print("communicator2_response3: ", communicator2_response3)
        assert communicator2_response3["type"] == "call_joined"
        assert communicator2_response3["message"] == "Successfully joined call"

        # # initiator receives user_joined as one of participants
        communicator1_response3 = await communicator1.receive_json_from(timeout=2)
        print("communicator1_response3: ", communicator1_response3)
        assert communicator1_response3["type"] == "user_joined"
        assert (
            communicator1_response3["data"]["call_state"]["call_info"]["id"] == call.id
        )
        assert (
            communicator1_response3["data"]["call_state"]["call_info"]["initiator_id"]
            == initiator.id
        )

        # # Second message should NOT recive join call message
        with pytest.raises(asyncio.TimeoutError):
            await communicator2.receive_json_from(timeout=1)

        await communicator1.disconnect()
        # await communicator2.disconnect()

    async def test_e_leave_call(
        self,
        initiator: USER,
        participants: List[USER],
        settings,
    ):
        """
        Tests leave call
        """
        application = URLRouter(websocket_urlpatterns)

        call = await database_sync_to_async(CallRecordRepository.create_group_call)(
            initiator_id=initiator.id,
            participant_ids=[participants[0].id, participants[1].id],
            call_type="voice",
            title="Test Call",
        )

        # initiator connects
        communicator1 = WebsocketCommunicator(
            application=application, path=f"/ws/calls/{call.id}/"
        )

        # initiator authenticates to scope
        communicator1.scope["user"] = initiator  # type: ignore

        connected1, subprotocol = await communicator1.connect()
        assert connected1 is True

        #  initiator message. First message should be connection_success
        communicator1_response1 = await communicator1.receive_json_from(timeout=2)
        print("communicator1_response1: ", communicator1_response1)
        assert communicator1_response1["type"] == "connection_success"
        assert communicator1_response1["message"] == "Connection successful."

        # Second user connects
        communicator2 = WebsocketCommunicator(application, f"/ws/calls/{call.id}/")
        # Second user authenticates to scope
        communicator2.scope["user"] = participants[0]  # type: ignore
        connected2, subprotocol = await communicator2.connect()
        assert connected2 is True

        #  second user First message should be connection_success
        communicator2_response1 = await communicator2.receive_json_from(timeout=2)
        print("communicator2_response1: ", communicator2_response1)
        assert communicator2_response1["type"] == "connection_success"
        assert communicator2_response1["message"] == "Connection successful."

        # initiator receives user connecting
        communicator1_response2 = await communicator1.receive_json_from(timeout=2)
        print("communicator1_response2: ", communicator1_response2)
        assert communicator1_response2["type"] == "user_connecting"
        assert (
            communicator1_response2["message"]
            == f"{participants[0].username} User is connecting"
        )

        # # second user send leave_call
        await communicator2.send_json_to({"type": "leave_call"})

        # second joining user receives current state.
        communicator2_response3 = await communicator2.receive_json_from(timeout=2)
        print("communicator2_response3: ", communicator2_response3)
        assert communicator2_response3["type"] == "call_left"
        assert communicator2_response3["message"] == "Successfully left call"

        # # initiator receives user_joined as one of participants
        communicator1_response3 = await communicator1.receive_json_from(timeout=2)
        print("communicator1_response3: ", communicator1_response3)
        assert communicator1_response3["type"] == "user_left"
        assert (
            communicator1_response3["message"]
            == f"{participants[0].username} User left"
        )
        assert communicator1_response3["data"]["user_id"] == participants[0].id
        assert communicator1_response3["data"]["username"] == participants[0].username

        # # Second message should NOT recive left call message
        with pytest.raises(asyncio.TimeoutError):
            await communicator2.receive_json_from(timeout=1)

        await communicator1.disconnect()

    async def test_f_invite_to_call(
        self,
        initiator: USER,
        participants: List[USER],
        settings,
    ):
        """
        Tests invite users to call
        """
        application = URLRouter(websocket_urlpatterns)

        call = await database_sync_to_async(CallRecordRepository.create_group_call)(
            initiator_id=initiator.id,
            participant_ids=[participants[0].id, participants[1].id],
            call_type="voice",
            title="Test Call",
        )
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

        # initiator connects
        communicator1 = WebsocketCommunicator(
            application=application, path=f"/ws/calls/{call.id}/"
        )

        # # initiator authenticates to scope
        communicator1.scope["user"] = initiator  # type: ignore

        connected1, subprotocol = await communicator1.connect()
        assert connected1 is True

        # #  initiator message. First message should be connection_success
        communicator1_response1 = await communicator1.receive_json_from(timeout=2)
        print("communicator1_response1: ", communicator1_response1)
        assert communicator1_response1["type"] == "connection_success"
        assert communicator1_response1["message"] == "Connection successful."

        # initiator invites participant
        await communicator1.send_json_to(
            {
                "type": "invite_users",
                "user_ids": [participants[0].id],
                "call_type": "video",
            }
        )

        # notify2 receives data
        notify2_response2 = await notify2.receive_json_from(timeout=5)
        assert notify2_response2["message"] == "Incoming call invitation"
        assert notify2_response2["data"]["call_id"] == call.id
        assert notify2_response2["data"]["from_username"] == initiator.username
        assert notify2_response2["data"]["from_user_id"] == initiator.id

        # communicator1 invites unknown participant
        await communicator1.send_json_to(
            {
                "type": "invite_users",
                "user_ids": ["123456789101234567890"],
                "call_type": "video",
            }
        )
        # communicator1 receives 4000 status code
        communicator1_response2 = await communicator1.receive_json_from(timeout=3)
        assert communicator1_response2["message"] == "Invited User not found"
        assert communicator1_response2["type"] == "error"
        assert communicator1_response2["status_code"] == 4004

        await communicator1.disconnect()
        await notify1.disconnect()
        await notify2.disconnect()

    async def test_g_media_state(
        self,
        initiator: USER,
        participants: List[USER],
        settings,
    ):
        """
        Tests media state
        """
        application = URLRouter(websocket_urlpatterns)

        call = await database_sync_to_async(CallRecordRepository.create_group_call)(
            initiator_id=initiator.id,
            participant_ids=[participants[0].id, participants[1].id],
            call_type="voice",
            title="Test Call",
        )

        # initiator connects
        communicator1 = WebsocketCommunicator(
            application=application, path=f"/ws/calls/{call.id}/"
        )

        # # initiator authenticates to scope
        communicator1.scope["user"] = initiator  # type: ignore

        connected1, _ = await communicator1.connect()
        assert connected1 is True

        # #  initiator message. First message should be connection_success
        communicator1_response1 = await communicator1.receive_json_from(timeout=2)
        print("communicator1_response1: ", communicator1_response1)
        assert communicator1_response1["type"] == "connection_success"
        assert communicator1_response1["message"] == "Connection successful."

        # participant connects
        communicator2 = WebsocketCommunicator(
            application=application, path=f"/ws/calls/{call.id}/"
        )

        # # participant authenticates to scope
        communicator2.scope["user"] = participants[0]  # type: ignore

        connected2, _ = await communicator2.connect()
        assert connected2 is True

        communicator1_response2 = await communicator1.receive_json_from(timeout=2)
        print("communicator1_response2: ", communicator1_response2)
        assert communicator1_response2["type"] == "user_connecting"

        # send media state to participant
        media_state = {
            "type": "media_state",
            "audio": {"enabled": True, "muted": False},
            "video": {"enabled": True, "muted": False},
            "screen": {"sharing": False},
            "device_info": {
                "audio_input_id": "default",
                "video_input_id": "front-camera-uuid",
                "audio_output_id": "default",
            },
        }
        await communicator2.send_json_to(media_state)

        communicator1_response3 = await communicator1.receive_json_from(timeout=2)
        print("communicator1_response3: ", communicator1_response3)
        assert communicator1_response3["type"] == "media_state_changed"
        media_state.pop("type", None)
        assert communicator1_response3["data"]["media"] == media_state

        # send invalid media state
        await communicator2.send_json_to(
            {"type": "media_state", "audio": True, "video": True}
        )
        await communicator2.receive_json_from(timeout=2)
        communicator2_response2 = await communicator2.receive_json_from(timeout=2)
        print("communicator2_response2: ", communicator2_response2)
        assert communicator2_response2["type"] == "error"
        assert communicator2_response2["errors"] == ["audio must be an object"]

        await communicator1.disconnect()
        await communicator2.disconnect()

    async def test_h_offer(
        self,
        initiator: USER,
        participants: List[USER],
        settings,
    ):
        """
        Tests webrtc offer
        """
        application = URLRouter(websocket_urlpatterns)

        call = await database_sync_to_async(CallRecordRepository.create_group_call)(
            initiator_id=initiator.id,
            participant_ids=[participants[0].id, participants[1].id],
            call_type="voice",
            title="Test Call",
        )

        # initiator connects
        communicator1 = WebsocketCommunicator(
            application=application, path=f"/ws/calls/{call.id}/"
        )

        # # initiator authenticates to scope
        communicator1.scope["user"] = initiator  # type: ignore

        connected1, _ = await communicator1.connect()
        assert connected1 is True

        # #  initiator message. First message should be connection_success
        communicator1_response1 = await communicator1.receive_json_from(timeout=2)
        print("communicator1_response1: ", communicator1_response1)
        assert communicator1_response1["type"] == "connection_success"
        assert communicator1_response1["message"] == "Connection successful."

        # participant connects
        communicator2 = WebsocketCommunicator(
            application=application, path=f"/ws/calls/{call.id}/"
        )

        # # participant authenticates to scope
        communicator2.scope["user"] = participants[0]  # type: ignore

        connected2, _ = await communicator2.connect()
        assert connected2 is True

        await communicator2.receive_json_from(timeout=5)

        # participant sends offer
        await communicator2.send_json_to(
            {"type": "webrtc_offer", "offer": {"some_offer": "offer"}}
        )

        communicator1_response2 = await communicator1.receive_json_from(timeout=2)
        print("communicator1_response2: ", communicator1_response2)
        assert communicator1_response2["type"] == "user_connecting"

        communicator1_response3 = await communicator1.receive_json_from(timeout=5)
        print("communicator1_response3: ", communicator1_response3)
        assert communicator1_response3["type"] == "webrtc_offer"

        # participant sends offer without offer field
        await communicator2.send_json_to(
            {
                "type": "webrtc_offer",
            }
        )
        communicator2_response2 = await communicator2.receive_json_from(timeout=2)
        print("communicator2_response2: ", communicator2_response2)
        assert communicator2_response2["type"] == "error"
        assert communicator2_response2["errors"] == ["webrtc offer is missing"]
        assert communicator2_response2["status_code"] == 4000

        await communicator1.disconnect()
        await communicator2.disconnect()

    async def test_i_answer(
        self,
        initiator: USER,
        participants: List[USER],
        settings,
    ):
        """
        Tests webrtc answer
        """
        application = URLRouter(websocket_urlpatterns)

        call = await database_sync_to_async(CallRecordRepository.create_group_call)(
            initiator_id=initiator.id,
            participant_ids=[participants[0].id, participants[1].id],
            call_type="voice",
            title="Test Call",
        )

        # initiator connects
        communicator1 = WebsocketCommunicator(
            application=application, path=f"/ws/calls/{call.id}/"
        )

        # # initiator authenticates to scope
        communicator1.scope["user"] = initiator  # type: ignore

        connected1, _ = await communicator1.connect()
        assert connected1 is True

        # #  initiator message. First message should be connection_success
        communicator1_response1 = await communicator1.receive_json_from(timeout=2)
        print("communicator1_response1: ", communicator1_response1)
        assert communicator1_response1["type"] == "connection_success"
        assert communicator1_response1["message"] == "Connection successful."

        # participant connects
        communicator2 = WebsocketCommunicator(
            application=application, path=f"/ws/calls/{call.id}/"
        )

        # # participant authenticates to scope
        communicator2.scope["user"] = participants[0]  # type: ignore

        connected2, _ = await communicator2.connect()
        assert connected2 is True

        await communicator2.receive_json_from(timeout=5)

        communicator1_response2 = await communicator1.receive_json_from(timeout=2)
        print("communicator1_response2: ", communicator1_response2)
        assert communicator1_response2["type"] == "user_connecting"

        # participant sends answer
        await communicator2.send_json_to(
            {"type": "webrtc_answer", "answer": {"some_answer": "answer"}}
        )

        communicator1_response3 = await communicator1.receive_json_from(timeout=5)
        print("communicator1_response3: ", communicator1_response3)
        assert communicator1_response3["type"] == "webrtc_answer"

        # participant sends answer without answer field
        await communicator2.send_json_to(
            {
                "type": "webrtc_answer",
            }
        )
        communicator2_response2 = await communicator2.receive_json_from(timeout=2)
        print("communicator2_response2: ", communicator2_response2)
        assert communicator2_response2["type"] == "error"
        assert communicator2_response2["errors"] == ["webrtc answer is missing"]
        assert communicator2_response2["status_code"] == 4000

        await communicator1.disconnect()
        await communicator2.disconnect()

    async def test_j_ice_candidate(
        self,
        initiator: USER,
        participants: List[USER],
        settings,
    ):
        """
        Tests webrtc ice candidate
        """
        application = URLRouter(websocket_urlpatterns)

        call = await database_sync_to_async(CallRecordRepository.create_group_call)(
            initiator_id=initiator.id,
            participant_ids=[participants[0].id, participants[1].id],
            call_type="voice",
            title="Test Call",
        )

        # initiator connects
        communicator1 = WebsocketCommunicator(
            application=application, path=f"/ws/calls/{call.id}/"
        )

        # # initiator authenticates to scope
        communicator1.scope["user"] = initiator  # type: ignore

        connected1, _ = await communicator1.connect()
        assert connected1 is True

        # #  initiator message. First message should be connection_success
        communicator1_response1 = await communicator1.receive_json_from(timeout=2)
        print("communicator1_response1: ", communicator1_response1)
        assert communicator1_response1["type"] == "connection_success"
        assert communicator1_response1["message"] == "Connection successful."

        # participant connects
        communicator2 = WebsocketCommunicator(
            application=application, path=f"/ws/calls/{call.id}/"
        )

        # # participant authenticates to scope
        communicator2.scope["user"] = participants[0]  # type: ignore

        connected2, _ = await communicator2.connect()
        assert connected2 is True

        await communicator2.receive_json_from(timeout=5)

        communicator1_response2 = await communicator1.receive_json_from(timeout=2)
        print("communicator1_response2: ", communicator1_response2)
        assert communicator1_response2["type"] == "user_connecting"

        # participant sends answer
        await communicator2.send_json_to(
            {
                "type": "ice_candidate",
                "ice_candidate": {"some_ice_candidate": "ice_candidate"},
            }
        )

        communicator1_response3 = await communicator1.receive_json_from(timeout=5)
        print("communicator1_response3: ", communicator1_response3)
        assert communicator1_response3["type"] == "ice_candidate"

        # participant sends answer without answer field
        await communicator2.send_json_to(
            {
                "type": "ice_candidate",
            }
        )
        communicator2_response2 = await communicator2.receive_json_from(timeout=2)
        print("communicator2_response2: ", communicator2_response2)
        assert communicator2_response2["type"] == "error"
        assert communicator2_response2["errors"] == ["webrtc ice_candidate is missing"]
        assert communicator2_response2["status_code"] == 4000

        await communicator1.disconnect()
        await communicator2.disconnect()

    async def test_k_emoji_reactions(
        self,
        initiator: USER,
        participants: List[USER],
        settings,
    ):
        """
        Tests emoji reactions
        """
        application = URLRouter(websocket_urlpatterns)

        call = await database_sync_to_async(CallRecordRepository.create_group_call)(
            initiator_id=initiator.id,
            participant_ids=[participants[0].id, participants[1].id],
            call_type="voice",
            title="Test Call",
        )

        # initiator connects
        communicator1 = WebsocketCommunicator(
            application=application, path=f"/ws/calls/{call.id}/"
        )

        # # initiator authenticates to scope
        communicator1.scope["user"] = initiator  # type: ignore

        connected1, _ = await communicator1.connect()
        assert connected1 is True

        # #  initiator message. First message should be connection_success
        communicator1_response1 = await communicator1.receive_json_from(timeout=2)
        print("communicator1_response1: ", communicator1_response1)
        assert communicator1_response1["type"] == "connection_success"
        assert communicator1_response1["message"] == "Connection successful."

        # participant connects
        communicator2 = WebsocketCommunicator(
            application=application, path=f"/ws/calls/{call.id}/"
        )

        # # participant authenticates to scope
        communicator2.scope["user"] = participants[0]  # type: ignore

        connected2, _ = await communicator2.connect()
        assert connected2 is True

        await communicator2.receive_json_from(timeout=5)

        communicator1_response2 = await communicator1.receive_json_from(timeout=2)
        print("communicator1_response2: ", communicator1_response2)
        assert communicator1_response2["type"] == "user_connecting"

        # participant sends reaction
        await communicator2.send_json_to(
            {
                "type": "user_reaction",
                "reaction": "😀",
            }
        )

        # initiator receives reaction
        communicator1_response3 = await communicator1.receive_json_from(timeout=5)
        print("communicator1_response3: ", communicator1_response3)
        assert communicator1_response3["type"] == "user_reacted"

        # participant sends reaction as invalid
        await communicator2.send_json_to(
            {
                "type": "user_reaction",
                "reaction": "fake reaction",
            }
        )
        communicator2_response2 = await communicator2.receive_json_from(timeout=2)
        print("communicator2_response2: ", communicator2_response2)
        assert communicator2_response2["type"] == "error"
        assert communicator2_response2["errors"] == ["emoji reaction is invalid"]
        assert communicator2_response2["status_code"] == 4000

        await communicator1.disconnect()
        await communicator2.disconnect()
