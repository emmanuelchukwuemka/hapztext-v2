"""
WebRTCConsumer
"""

import logging
from datetime import datetime
from typing import Any, Dict, List

from channels.db import database_sync_to_async
from channels.layers import get_channel_layer
from django.contrib.auth import get_user_model
from django.contrib.auth.models import AnonymousUser
from django.utils import timezone

from apps.infrastructure.calls.generics import CustomAsyncJsonWebsocketConsumer
from apps.infrastructure.calls.repository.call_record_repo import (
    CallRecordRepository,
)
from apps.infrastructure.calls.custom_exceptions import (
    CustomWebRTCBaseError,
    CustomWebRTCMediaStateError,
)
from apps.infrastructure.calls.custom_exceptions import (
    CUstomCallParticipantForeignKeyError,
)
from apps.infrastructure.calls.dto import MediaStateValidatorDto
from apps.infrastructure.calls.utils.call_app_util import CallAppUtil

User = get_user_model()
logger = logging.getLogger(__name__)

CLIENT_EVENT_TYPES = [
    "join_call",
    "leave_call",
    "media_state",
    "webrtc_offer",
    "webrtc_answer",
    "ice_candidate",
    "invite_users",
    "end_call",
    "user_reaction",
]

BACKEND_EVENT_TYPES = [
    "user_left",
    "call_joined",
    "user_reacted",
    "ice_candidate",
    "webrtc_answer",
    "webrtc_offer",
    "media_state_changed",
    "call_invite",
    "end_call",
    "call_busied",
    "error",
]


class WebRTCConsumer(CustomAsyncJsonWebsocketConsumer):
    """
    WebRTCConsumer
    """

    async def connect(self):
        """
        Handle WebSocket connection with authentication and call joining.
        """
        try:
            self.user = self.scope["user"]  # type: ignore
            assert self.user
            self.call_id = self.scope["url_route"]["kwargs"]["call_id"]  # type: ignore
            if self.user == AnonymousUser():
                await self.close(code=4001)
                return

            # Validate user can access this call
            if not await self._validate_call_access():
                logger.warning("User %s not allowed to access call", self.user.id)
                await self.close(code=4003)
                return

            await self.accept()

            await self.channel_layer.send(
                channel=self.channel_name,
                message={
                    "message": "Connection successful.",
                    "data": {
                        "events": {
                            "client_to_send": CLIENT_EVENT_TYPES,
                            "backend_to_send": BACKEND_EVENT_TYPES,
                        }
                    },
                    "type": "single_user_message",
                    "client_type": "connection_success",
                },
            )

            self.call_group_name = f"call_{self.call_id}"
            # Join call group
            await self.channel_layer.group_add(
                group=self.call_group_name,
                channel=self.channel_name,
            )

            # Notify others that user is connecting
            await self.channel_layer.group_send(
                self.call_group_name,
                {
                    "type": "user_connecting",
                    "data": {
                        "user_id": self.user and str(self.user.id),
                        "username": self.user and self.user.username,
                        "call_id": self.call_id,
                        "timestamp": timezone.now().isoformat(),
                    },
                    "message": f"{self.user and self.user.username} User is connecting",
                },
            )

            logger.info("User %s connected to call %s", self.user.id, self.call_id)

        except Exception as exc:
            logger.error("Error connecting to websockets: %s", str(exc))
            await self.close(code=5000)

    async def disconnect(self, code: int) -> None:
        """
        Handle WebSocket disconnection.
        """
        try:
            if hasattr(self, "call_group_name") and self.call_group_name:
                # Notify others that user is disconnecting
                await self.channel_layer.group_send(
                    self.call_group_name,
                    {
                        "type": "user_disconnecting",
                        "user_id": self.user and str(self.user.id),
                        "username": self.user and self.user.username,
                        "call_id": self.call_id,
                    },
                )

                # Remove from group
                await self.channel_layer.group_discard(
                    self.call_group_name, self.channel_name
                )

            logger.info(
                "User %s disconnected from call %s",
                self.user and self.user.id,
                self.call_id,
            )

        except Exception as e:
            logger.error("WebSocket disconnection error: %s", str(e))

    async def user_connecting(self, event: Dict[str, Any]):
        """
        Handle user connecting to WebSocket.
        """
        if (event.get("data") or {}).get("user_id") == str(self.user and self.user.id):
            return
        await self.send_json(event)

    async def user_disconnecting(self, event: Dict[str, Any]):
        """
        Handle user disconnecting from WebSocket.
        """
        data = event.get("data") or {}
        if data.get("user_id") == str(self.user and self.user.id):
            return
        await self.send_json(
            {
                "type": "user_disconnecting",
                "data": data,
                "message": "User is disconnecting",
            }
        )

    async def receive_json(self, content: Any = {}, **kwargs: Any) -> None:
        """
        Receive and handle messages from WebSocket.
        """
        try:
            if not isinstance(content, dict):
                await self.channel_layer.send(
                    channel=self.channel_name,
                    message={
                        "type": "single_user_message",
                        "message": f"Expected json but got {str(type(content))}",
                        "errors": [f"Expected json but got {str(type(content))}"],
                        "status_code": 4000,
                        "client_type": "error",
                    },
                )
                return
            message_type = content.get("type")
            if (
                not isinstance(message_type, str)
                or message_type not in CLIENT_EVENT_TYPES
            ):
                await self.channel_layer.send(
                    channel=self.channel_name,
                    message={
                        "type": "single_user_message",
                        "message": "type must be a valid string.",
                        "errors": [
                            "type must be a valid string",
                            f"type must be one of {CLIENT_EVENT_TYPES}",
                        ],
                        "status_code": 4000,
                        "client_type": "error",
                    },
                )
                return

            handler_map = {
                "invite_users": self._handle_invite_users,
                "join_call": self._handle_join_call,
                "leave_call": self._handle_leave_call,
                "media_state": self._handle_media_state,
                "webrtc_offer": self._handle_webrtc_offer,
                "webrtc_answer": self._handle_webrtc_answer,
                "ice_candidate": self._handle_ice_candidate,
                "user_reaction": self._handle_reactions,
                "end_call": self._handle_end_call,
            }
            handler = handler_map.get(message_type)
            if handler:
                await handler(content)
                return
            logger.warning("Unknown message type: %s", message_type)

            await self.send_json(
                {
                    "type": "error",
                    "message": f"Unknown message type: {message_type}",
                    "errors": [
                        f"Unknown message type: {message_type}",
                        f"message type must be one of {CLIENT_EVENT_TYPES}",
                    ],
                    "status_code": 4000,
                    "client_type": "error",
                }
            )

        except CustomWebRTCBaseError as exc:
            logger.error("Error recieving json data: %s", str(exc))
            await self.channel_layer.send(
                channel=self.channel_name,
                message={
                    "type": "single_user_message",
                    "message": "Internal Server Error.",
                    "errors": [],
                    "status_code": 5000,
                    "client_type": "error",
                },
            )

    # #################### CLIENT RECEIVED EVENTS HANDLERS ##################

    async def _handle_invite_users(self, content: Dict[str, Any]):
        """
        Handle inviting another user to a call.
        Expects content = {"user_ids": ["<invitee-id>"], "call_id": "<call-id>"}
        """
        try:
            invitee_ids: List[str] | None = content.get("user_ids")
            if not invitee_ids or len(invitee_ids) < 1:
                await self.send_json(
                    content={
                        "message": "user_ids missing",
                        "status_code": 4000,
                        "errors": [
                            "user_ids missing",
                            "user_ids must have at least one user ID",
                        ],
                        "type": "error",
                    }
                )
                return
            call_type = content.get("call_type")
            if call_type not in ["video", "audio"]:
                await self.send_json(
                    content={
                        "message": "call_type must be one of video, voice",
                        "status_code": 4000,
                        "errors": [
                            "call_type must be one of video, voice",
                        ],
                        "type": "error",
                    }
                )
                return

            channel_layer = get_channel_layer()
            assert channel_layer

            success = await database_sync_to_async(CallRecordRepository.invite_to_call)(
                call_id=self.call_id or "",
                inviter_id=(self.user and str(self.user.id) or ""),
                new_user_ids=invitee_ids,
            )
            if success:
                for invitee_id in invitee_ids:
                    if (
                        not isinstance(invitee_id, str)
                        or len(invitee_id) < 21
                        or len(invitee_id) > 21
                    ):
                        logger.warning(
                            "Skipping invitee ID from invitation: %s", invitee_id
                        )
                        continue
                    group_name = f"user_{invitee_id}_notifications"

                    # Send a call notification event
                    await channel_layer.group_send(
                        group=group_name,
                        message={
                            "type": "notify",  # notify_consumer.notify
                            "data": {
                                "type": "call_invite",
                                "data": {
                                    "from_user_id": str(self.user and self.user.id),
                                    "from_username": self.user and self.user.username,
                                    "call_id": self.call_id,
                                    "call_type": call_type,
                                    "timestamp": timezone.now().isoformat(),
                                },
                                "message": "Incoming call invitation",
                            },
                        },
                    )
        except CUstomCallParticipantForeignKeyError as exc:
            logger.error("Invited User not found: %s", str(exc))
            await self.send_json(
                {
                    "type": "error",
                    "message": "Invited User not found",
                    "status_code": 4004,
                    "errors": ["Invited User not found"],
                }
            )
        except Exception as exc:
            logger.error("Invite user error: %s", str(exc))
            await self.send_json(
                {
                    "type": "error",
                    "message": "Failed to invite users",
                    "status_code": 5000,
                    "errors": [
                        "An Unexpected Error Occurred.",
                        "Failed to invite users",
                    ],
                }
            )

    async def _handle_media_state(self, content: Dict[str, Any]):
        """
        Handle user media state changes (audio/video).

        {
            "type": "media_state",
            "audio": {
                "enabled": true,
                "muted": false
            },
            "video": {
                "enabled": true,
                "muted": false
            },
            "screen": {
                "sharing": false
            },
            "device_info": {
                "audio_input_id": "default",
                "video_input_id": "front-camera-uuid",
                "audio_output_id": "default"
            },
            "timestamp": "2025-01-01T12:00:00.000Z"
        }

        """
        try:
            try:
                media_state_dto = MediaStateValidatorDto(**content)
                media_state_dto.validate()
            except CustomWebRTCMediaStateError as exc:
                await self.channel_layer.send(
                    channel=self.channel_name,
                    message={
                        "type": "single_user_message",
                        "client_type": "error",
                        "message": f"{str(exc)}",
                        "errors": [
                            f"{str(exc)}",
                        ],
                        "status_code": 4000,
                    },
                )
                return

            # Update media state in repository
            success = await database_sync_to_async(
                CallRecordRepository.update_participant_media_state
            )(
                call_id=self.call_id or "",
                user_id=self.user and str(self.user.id) or "",
                video_enabled=media_state_dto.video.get("enabled", True),
                audio_enabled=media_state_dto.audio.get("enabled", True),
            )

            if success:
                content.pop("type", None)
                await self.channel_layer.group_send(
                    self.call_group_name or "",
                    {
                        "type": "media_state_changed",
                        "data": {
                            "user_id": self.user and str(self.user.id),
                            "username": self.user and self.user.username,
                            "timestamp": timezone.now().isoformat(),
                            "media": content,
                        },
                    },
                )

        except Exception as e:
            logger.error("Media state error: %s", str(e))
            await self.send_json(
                {
                    "type": "error",
                    "message": "Failed to update media state",
                    "status_code": 5000,
                    "errors": [
                        "An Unexpected Error Occurred.",
                        "Failed to update media state",
                    ],
                }
            )

    async def _handle_webrtc_offer(self, content: Dict[str, Any]):
        """
        Handle WebRTC offer from a user.
        """
        try:
            offer = content.get("offer")
            if not offer:
                logger.warning(
                    "offer missing in webrtc offer. content: %s", str(content)
                )
                await self.channel_layer.send(
                    channel=self.channel_name,
                    message={
                        "type": "single_user_message",
                        "client_type": "error",
                        "message": "webrtc offer is missing",
                        "errors": [
                            "webrtc offer is missing",
                        ],
                        "status_code": 4000,
                    },
                )
                return

            await self.channel_layer.group_send(
                group=self.call_group_name or "",
                message={
                    "type": "webrtc_offer",
                    "data": {
                        "user_id": self.user and str(self.user.id),
                        "username": self.user and str(self.user.username),
                        "offer": offer,
                        "timestamp": timezone.now().isoformat(),
                    },
                },
            )

        except Exception as e:
            logger.error("WebRTC offer error: %s", str(e))
            await self.send_json(
                {
                    "type": "error",
                    "message": "Failed to propagate webrtc offer",
                    "status_code": 5000,
                    "errors": [
                        "An Unexpected Error Occurred.",
                        "Failed to propagate webrtc offer",
                    ],
                }
            )

    async def _handle_webrtc_answer(self, content: Dict[str, Any]):
        """
        Handle WebRTC answer from a user.
        """
        try:
            answer = content.get("answer")

            if not answer:
                logger.warning(
                    "answer missing in webrtc answer. content: %s", str(content)
                )
                await self.channel_layer.send(
                    channel=self.channel_name,
                    message={
                        "type": "single_user_message",
                        "client_type": "error",
                        "message": "webrtc answer is missing",
                        "errors": [
                            "webrtc answer is missing",
                        ],
                        "status_code": 4000,
                    },
                )
                return

            await self.channel_layer.group_send(
                group=self.call_group_name or "",
                message={
                    "type": "webrtc_answer",
                    "data": {
                        "user_id": self.user and str(self.user.id),
                        "username": self.user and str(self.user.username),
                        "answer": answer,
                        "timestamp": timezone.now().isoformat(),
                    },
                },
            )

        except Exception as e:
            logger.error("WebRTC answer error: %s", str(e))
            await self.send_json(
                {
                    "type": "error",
                    "message": "Failed to propagate webrtc answer",
                    "status_code": 5000,
                    "errors": [
                        "An Unexpected Error Occurred.",
                        "Failed to propagate webrtc answer",
                    ],
                }
            )

    async def _handle_ice_candidate(self, content: Dict[str, Any]):
        """
        Handle ICE candidate exchange.
        """
        try:
            ice_candidate = content.get("ice_candidate")
            if not ice_candidate:
                logger.warning(
                    "ice_candidate missing in webrtc ice_candidate. content: %s",
                    str(content),
                )
                await self.channel_layer.send(
                    channel=self.channel_name,
                    message={
                        "type": "single_user_message",
                        "client_type": "error",
                        "message": "webrtc ice_candidate is missing",
                        "errors": [
                            "webrtc ice_candidate is missing",
                        ],
                        "status_code": 4000,
                    },
                )
                return

            await self.channel_layer.group_send(
                self.call_group_name or "",
                {
                    "type": "ice_candidate",
                    "data": {
                        "user_id": self.user and str(self.user.id),
                        "username": self.user and str(self.user.username),
                        "ice_candidate": ice_candidate,
                        "timestamp": timezone.now().isoformat(),
                    },
                },
            )

        except Exception as e:
            logger.error("ICE candidate error: %s", str(e))
            await self.send_json(
                {
                    "type": "error",
                    "message": "Failed to propagate ICE CANDIDATE",
                    "status_code": 5000,
                    "errors": [
                        "An Unexpected Error Occurred.",
                        "Failed to propagate ICE CANDIDATE",
                    ],
                }
            )

    async def _handle_end_call(self, content: Dict[str, Any]):
        """
        Handle Call Ended Signal.
        """
        try:
            await self.channel_layer.group_send(
                self.call_group_name or "",
                {
                    "type": "end_call",
                    "data": {
                        "user_id": self.user and str(self.user.id),
                        "username": self.user and str(self.user.username),
                        "timestamp": timezone.now().isoformat(),
                    },
                },
            )

        except Exception as e:
            logger.error("End call error: %s", str(e))
            await self.send_json(
                {
                    "type": "error",
                    "message": "Failed to propagate ICE CANDIDATE",
                    "status_code": 5000,
                    "errors": [
                        "An Unexpected Error Occurred.",
                        "Failed to propagate end call signal",
                    ],
                }
            )

    async def _handle_reactions(self, content: Dict[str, Any]):
        """
        Handle hand raise events.
        """
        try:
            reaction = content.get("reaction")
            if not reaction:
                logger.warning(
                    "reaction missing in content: %s",
                    str(content),
                )
                await self.channel_layer.send(
                    channel=self.channel_name,
                    message={
                        "type": "single_user_message",
                        "client_type": "error",
                        "message": "reaction missing in content payload",
                        "errors": [
                            "reaction missing in content payload",
                        ],
                        "status_code": 4000,
                    },
                )
                return
            try:
                CallAppUtil.is_valid_emoji(reaction)
            except ValueError as exc:
                logger.warning("Invalid emoji used in reactions: %s", str(exc))
                await self.channel_layer.send(
                    channel=self.channel_name,
                    message={
                        "type": "single_user_message",
                        "client_type": "error",
                        "message": str(exc),
                        "errors": [
                            str(exc),
                        ],
                        "status_code": 4000,
                    },
                )
                return
            await self.channel_layer.group_send(
                group=self.call_group_name or "",
                message={
                    "type": "user_reacted",
                    "data": {
                        "user_id": self.user and self.user.id,
                        "username": self.user and self.user.username,
                        "reaction": reaction,
                        "timestamp": content.get("timestamp")
                        or timezone.now().isoformat(),
                    },
                },
            )
        except Exception as e:
            logger.error("User Reaction error: %s", str(e))
            await self.send_json(
                {
                    "type": "error",
                    "message": "Failed to propagate User Reaction",
                    "status_code": 5000,
                    "errors": [
                        "An Unexpected Error Occurred.",
                        "Failed to propagate User Reaction",
                    ],
                }
            )

    async def _handle_join_call(self, content: Dict[str, Any]):
        """
        Handle user joining the call.
        """
        try:
            logger.info("join call content: %s", str(content))
            assert self.call_group_name
            success = await database_sync_to_async(CallRecordRepository.join_call)(
                self.call_id or "", (self.user and str(self.user.id) or "")
            )

            if success:
                # Get updated call state
                call_state = await database_sync_to_async(
                    CallRecordRepository.get_call_summary
                )(self.call_id or "")

                if call_state:
                    start_time = (call_state.get("call_info") or {}).get(
                        "start_time", None
                    )
                    if isinstance(start_time, datetime):
                        call_state["call_info"]["start_time"] = start_time.isoformat()

                # Notify all participants
                await self.channel_layer.group_send(
                    group=self.call_group_name,
                    message={
                        "type": "user_joined",
                        "data": {
                            "user_id": self.user and str(self.user.id),
                            "username": self.user and self.user.username,
                            "call_state": call_state,
                            "timestamp": timezone.now().isoformat(),
                        },
                        "message": f"{self.user and self.user.username} User joined",
                        "client_type": "user_joined",
                    },
                )

                # Send current call state to the joining user
                await self.send_json(
                    {
                        "type": "call_joined",
                        "data": {
                            "call_id": self.call_id,
                            "call_state": call_state,
                        },
                        "message": "Successfully joined call",
                    }
                )
            else:
                await self.send_json(
                    {
                        "client_type": "error",
                        "message": "Failed to join call",
                        "type": "single_user_message",
                        "status_code": 5000,
                        "errors": ["Internal Server Error."],
                    },
                )

        except Exception as e:
            logger.error("Join call error: %s", str(e))
            await self.send_json(
                {
                    "type": "error",
                    "message": "Failed to join call",
                    "status_code": 5000,
                    "errors": ["An Unexpected Error Occurred."],
                }
            )

    async def _handle_leave_call(self, content: Dict[str, Any]):
        """
        Handle user leaving the call.
        """
        try:
            logger.info("leave call content: %s", str(content))
            success = await database_sync_to_async(CallRecordRepository.leave_call)(
                self.call_id or "", self.user and str(self.user.id) or ""
            )

            if success:
                await self.channel_layer.group_send(
                    group=self.call_group_name or "",
                    message={
                        "type": "user_left",
                        "data": {
                            "user_id": self.user and str(self.user.id),
                            "username": self.user and self.user.username,
                            "timestamp": timezone.now().isoformat(),
                        },
                        "message": f"{self.user and self.user.username} User left",
                        "client_type": "user_left",
                    },
                )

                await self.send_json(
                    {
                        "type": "call_left",
                        "message": "Successfully left call",
                        "data": {"call_id": self.call_id},
                    }
                )
            else:
                await self.send_json(
                    {
                        "client_type": "error",
                        "message": "Failed to leave call",
                        "type": "single_user_message",
                        "status_code": 5000,
                        "errors": ["Internal Server Error."],
                    },
                )

        except Exception as e:
            logger.error("Leave call error: %s", str(e))
            await self.send_json(
                {
                    "type": "error",
                    "message": "Failed to leave call",
                    "status_code": 5000,
                    "errors": ["Something went wrong. Could not leave call."],
                },
            )

    # #################### HANDLER FOR SERVER EMITTED EVENTS ##################

    async def user_joined(self, event: Dict[str, Any]):
        """
        Handle user joining the call.
        """
        data = event.get("data") or {}
        if data.get("user_id") == str(self.user and self.user.id):
            return
        await self.send_json(
            {
                "type": event.get("client_type"),
                "data": data,
                "message": event.get("message"),
            }
        )

    async def user_left(self, event: Dict[str, Any]):
        """
        Handle user leaving the call.
        """
        data = event.get("data") or {}
        if data.get("user_id") == str(self.user and self.user.id):
            return
        await self.send_json(
            {
                "type": event.get("client_type"),
                "data": data,
                "message": event.get("message"),
            }
        )

    async def media_state_changed(self, event: Dict[str, Any]):
        """
        Handle media state changes.
        """
        data = event.get("data") or {}
        if data.get("user_id") == str(self.user and self.user.id):
            return
        await self.send_json(event)

    async def end_call(self, event: Dict[str, Any]):
        """
        Handle end call.
        """
        data = event.get("data") or {}
        if data.get("user_id") == str(self.user and self.user.id):
            return
        await self.send_json(event)

        if self.call_group_name:
            await self.channel_layer.group_discard(
                self.call_group_name, self.channel_name
            )
        await self.close(code=1000, reason="call ended")

    async def webrtc_offer(self, event: Dict[str, Any]):
        """
        Handle WebRTC offer.
        """
        if event["data"]["user_id"] == str(self.user and self.user.id or ""):
            return
        await self.send_json(content=event)

    async def webrtc_answer(self, event: Dict[str, Any]):
        """
        Handle WebRTC answer.
        """
        if event["data"]["user_id"] == str(self.user and self.user.id or ""):
            return

        await self.send_json(event)

    async def ice_candidate(self, event: Dict[str, Any]):
        """
        Handle ICE candidate.
        """
        if event["data"]["user_id"] == str(self.user and self.user.id or ""):
            return
        await self.send_json(event)

    async def user_reacted(self, event: Dict[str, Any]):
        """
        Handle User reaction.
        """

        if event["data"]["user_id"] == str(self.user and self.user.id or ""):
            return
        await self.send_json(event)

    async def call_accepted(self, event: Dict[str, Any]):
        """
        Call answer helper
        """
        await self.send_json(content=event)

    async def call_declined(self, event: Dict[str, Any]):
        """
        Call decline helper
        """
        await self.send_json(content=event)

    async def call_busied(self, event: Dict[str, Any]):
        """
        Call Busy helper
        """
        await self.send_json(content=event)

    async def call_cancelled(self, event: Dict[str, Any]):
        """
        Call Busy helper
        """
        await self.send_json(content=event)

    async def call_missed(self, event: Dict[str, Any]):
        """
        Call Missed helper
        """
        await self.send_json(content=event)

    async def call_ringing(self, event: Dict[str, Any]):
        """
        Call Missed helper
        """
        await self.send_json(content=event)

    async def single_user_message(self, event: Dict[str, Any]):
        """
        Send message to the connected user
        """
        data = {
            "type": event.get("client_type", "direct"),
            "message": event["message"],
            "status_code": event.get("status_code", 2000),
            "data": event.get("data", {}),
        }
        errors = event.get("errors")
        if errors:
            data["errors"] = errors
        await self.send_json(data)

    # ##################### HELPER METHODS #######################
    @database_sync_to_async
    def _validate_call_access(self) -> bool:
        """
        Validate that user has access to this call.
        """
        call_exists = CallRecordRepository.get_call_by_id(call_id=self.call_id or "")

        return call_exists is not None
