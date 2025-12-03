"""
WebRTC Notify Consumer
"""

import logging
from typing import Any, Dict

from channels.generic.websocket import AsyncJsonWebsocketConsumer
from channels.db import database_sync_to_async
from channels.layers import get_channel_layer
from django.contrib.auth.models import AnonymousUser
from django.utils import timezone

from apps.infrastructure.users.models.tables import User
from apps.infrastructure.calls.repository import CallRecordRepository
from apps.infrastructure.calls.models import CallParticipantModel


logger = logging.Logger(__name__)

CLIENT_EVENT_TYPES = [
    "accept_call",
    "decline_call",
    "busy_call",
    "missed_call",
    # "cancel_call",
    # "call_ringing",
]

BACKEND_EVENT_TYPES = [
    "direct",
    "error",
    "call_accepted",
    "call_declined",
    # "call_busied",
    # "call_cancelled",
    # "call_ringing",
]


class WebRTCNotifyConsumer(AsyncJsonWebsocketConsumer):
    """
    WebRTCNotifyConsumer.
    Handles all *call notification* signaling:
    - call_invite
    - accept_call
    - decline_call
    - busy_call
    - missed_call
    - cancel_call
    """

    def __init__(self, *args: object, **kwargs: object) -> None:
        """
        Constructor
        """
        self.user: None | User | AnonymousUser = None
        self.group_name = None
        super().__init__(*args, **kwargs)

    async def connect(self):
        """
        Connection
        """
        try:
            self.user = self.scope["user"]  # type: ignore

            # Each user has a personal notification group
            self.group_name = f"user_{self.user and self.user.id}_notifications"

            await self.channel_layer.group_add(
                self.group_name,
                self.channel_name,
            )

            await self.accept()

            if not self.user or isinstance(self.user, AnonymousUser):
                await self.channel_layer.send(
                    channel=self.channel_name,
                    message={
                        "message": "Unauthorized",
                        "status_code": 40001,
                        "errors": ["Unauthorized"],
                        "type": "single_user_message",
                        "client_type": "error",
                    },
                )
                await self.close(code=4001)
                return

            await self.send_json(
                {
                    "type": "connection_success",
                    "message": "Connected to notifications channel",
                    "timestamp": timezone.now().isoformat(),
                    "data": {
                        "events": {
                            "client_to_send": CLIENT_EVENT_TYPES,
                            "backend_to_send": BACKEND_EVENT_TYPES,
                        }
                    },
                }
            )
            logger.info("User %s connected to call notifier", self.user.id)
        except Exception as exc:
            logger.error("Error connecting to Notify WS: %s", str(exc))

    async def disconnect(self, code: int):
        """
        Disconnect
        """
        try:
            await self.channel_layer.group_discard(
                group=self.group_name or "",
                channel=self.channel_name,
            )
            logger.info(
                "User %s disconnected from call notifier",
                self.user and self.user.id,
            )
        except Exception as exc:
            logger.error("Error dis-connecting to Notify WS: %s", str(exc))

    async def receive_json(self, content: Dict[str, Any], **kwargs: Any):
        """
        Receievs content
        """
        try:
            event_type = content.get("type")

            if not isinstance(event_type, str):
                await self.send_json(
                    {
                        "type": "error",
                        "message": "'event_type' must be of type string",
                        "errors": ["'event_type' must be of type string"],
                        "status_code": 4000,
                    }
                )
                return

            handler_collection = {
                "accept_call": self._handle_accept_call,
                "decline_call": self._handle_decline_call,
                "busy_call": self._handle_busy_call,
                "missed_call": self._handle_missed_call,
                "call_ringing": self._handle_ringing,
                "cancel_call": self._handle_cancel_call,
            }

            handler = handler_collection.get(event_type)
            if not handler:
                await self.send_json(
                    {
                        "type": "error",
                        "message": f"Unknown notification event '{event_type}'",
                        "errors": [
                            f"Unknown notification event '{event_type}'",
                            f"event_type must be one of {CLIENT_EVENT_TYPES}",
                        ],
                        "status_code": 4000,
                    }
                )
                return

            await handler(content=content)
        except Exception as exc:
            logger.error("Error receiving notify payload: %s", str(exc))
            await self.send_json(
                {
                    "type": "error",
                    "message": "An unexpected error occurred.",
                    "errors": [
                        "An unexpected error occurred.",
                        "Internal server error",
                    ],
                    "status_code": 5000,
                }
            )
            return

    # #################### CLIENT RECEIVED EVENTS HANDLERS ##################

    async def _handle_accept_call(self, content: Dict[str, Any]):
        """
        Handle call acception
        """
        try:
            call_id = content.get("call_id")
            if not self.__validate_call_id(call_id=call_id):
                return
            is_successful = await database_sync_to_async(
                CallRecordRepository.update_participant_status
            )(
                call_id=str(call_id),
                user_id=self.user.id,  # type: ignore
                new_status=CallParticipantModel.ParticipantStatus.JOINED,
            )
            if is_successful:
                channel_layer = get_channel_layer()
                if channel_layer:
                    call_group_name = f"call_{call_id}"
                    await channel_layer.group_send(
                        group=call_group_name,
                        message={
                            "type": "call_accepted",
                            "data": {
                                "call_id": call_id,
                                "user_id": str(self.user and self.user.id),
                                "username": self.user and self.user.username,
                            },
                        },
                    )
                    return

        except Exception as exc:
            logger.error("Error accepting call: %s", str(exc))
        await self.send_json(
            {
                "type": "error",
                "message": "An Unxpected Error occurred",
                "errors": ["An Unxpected Error occurred"],
                "status_code": 5000,
            }
        )

    async def _handle_decline_call(self, content: Dict[str, Any]):
        """
        Handle decline call
        """

        try:
            call_id = content.get("call_id")
            if not self.__validate_call_id(call_id=call_id):
                return
            reason = content.get("reason")
            if reason is not None and not isinstance(reason, str):
                await self.send_json(
                    {
                        "errors": ["reason must be of type string"],
                        "type": "error",
                        "message": "reason must be of type string",
                        "status_code": 4000,
                    }
                )
                return
            is_successful = await database_sync_to_async(
                CallRecordRepository.update_participant_status
            )(
                call_id=str(call_id),
                user_id=self.user.id,  # type: ignore
                new_status=CallParticipantModel.ParticipantStatus.DECLINED,
            )
            if is_successful:
                channel_layer = get_channel_layer()
                if channel_layer:
                    call_group_name = f"call_{call_id}"
                    await channel_layer.group_send(
                        group=call_group_name,
                        message={
                            "type": "call_declined",
                            "data": {
                                "call_id": call_id,
                                "user_id": str(self.user and self.user.id),
                                "username": self.user and self.user.username,
                                "reason": content.get("reason", "declined"),
                            },
                        },
                    )
                    return
        except Exception as exc:
            logger.error("Error declining call: %s", str(exc))
        await self.send_json(
            {
                "type": "error",
                "message": "An Unxpected Error occurred",
                "errors": ["An Unxpected Error occurred"],
                "status_code": 4000,
            }
        )

    async def _handle_busy_call(self, content: Dict[str, Any]):
        """
        Handle Busy call
        """

        try:
            call_id = content.get("call_id")
            if not self.__validate_call_id(call_id=call_id):
                return
            is_successful = await database_sync_to_async(
                CallRecordRepository.update_participant_status
            )(
                call_id=str(call_id),
                user_id=self.user.id,  # type: ignore
                new_status=CallParticipantModel.ParticipantStatus.BUSY,
            )
            if is_successful:
                channel_layer = get_channel_layer()
                if channel_layer:
                    call_group_name = f"call_{call_id}"
                    await channel_layer.group_send(
                        group=call_group_name,
                        message={
                            "type": "call_busied",
                            "data": {
                                "call_id": call_id,
                                "user_id": str(self.user and self.user.id),
                                "username": self.user and self.user.username,
                            },
                        },
                    )
                    return
        except Exception as exc:
            logger.error("Error busying call: %s", str(exc))
        await self.send_json(
            {
                "type": "error",
                "message": "An Unxpected Error occurred",
                "errors": ["An Unxpected Error occurred"],
                "status_code": 4000,
            }
        )

    async def _handle_missed_call(self, content: Dict[str, Any]):
        """
        Handle missed calls
        """

        try:
            call_id = content.get("call_id")
            if not self.__validate_call_id(call_id=call_id):
                return
            is_successful = await database_sync_to_async(
                CallRecordRepository.update_participant_status
            )(
                call_id=str(call_id),
                user_id=self.user.id,  # type: ignore
                new_status=CallParticipantModel.ParticipantStatus.MISSED,
            )
            if is_successful:
                await self.channel_layer.send(
                    channel=f"call_{call_id}",
                    message={
                        "type": "call_missed",
                        "data": {
                            "call_id": call_id,
                            "user_id": str(self.user and self.user.id),
                            "username": self.user and self.user.username,
                        },
                    },
                )
                return
        except Exception as exc:
            logger.error("Error propagating missed call: %s", str(exc))
        await self.send_json(
            {
                "type": "error",
                "message": "An Unxpected Error occurred",
                "errors": ["An Unxpected Error occurred"],
                "status_code": 4000,
            }
        )

    async def _handle_ringing(self, content: Dict[str, Any]):
        """
        Handle Call ringing
        """

        try:
            call_id = content.get("call_id")
            if not self.__validate_call_id(call_id=call_id):
                return

            channel_layer = get_channel_layer()
            if channel_layer:
                call_group_name = f"call_{call_id}"

                await channel_layer.group_send(
                    group=call_group_name,
                    message={
                        "type": "call_ringing",
                        "data": {
                            "call_id": call_id,
                            "user_id": str(self.user and self.user.id),
                            "username": self.user and self.user.username,
                        },
                    },
                )
        except Exception as exc:
            logger.error("Error busying call: %s", str(exc))
            await self.send_json(
                {
                    "type": "error",
                    "message": "An Unxpected Error occurred",
                    "errors": ["An Unxpected Error occurred"],
                    "status_code": 4000,
                }
            )

    async def _handle_cancel_call(self, content: Dict[str, Any]):
        """
        Handle cancel call
        """
        try:
            call_id = content.get("call_id")
            if not self.__validate_call_id(call_id=call_id):
                return
            is_successful = await database_sync_to_async(
                CallRecordRepository.update_participant_status
            )(
                call_id=str(call_id),
                user_id=self.user.id,  # type: ignore
                new_status=CallParticipantModel.ParticipantStatus.MISSED,
            )
            if is_successful:
                await self.channel_layer.send(
                    channel=self.channel_name,
                    message={
                        "type": "call_cancelled",
                        "data": {
                            "call_id": call_id,
                            "from_user_id": str(self.user and self.user.id),
                            "from_username": self.user and self.user.username,
                        },
                    },
                )
                return
        except Exception as exc:
            logger.error("Error busying call: %s", str(exc))
        await self.send_json(
            {
                "type": "error",
                "message": "An Unxpected Error occurred",
                "errors": ["An Unxpected Error occurred"],
                "status_code": 4000,
            }
        )

    # #################### HANDLER FOR SERVER EMITTED EVENTS ##################

    async def notify(self, event: Dict[str, Any]):
        """
        Generic handler for all notification events.
        """
        await self.send_json(
            content=event.get("data", {}),
            close=False,
        )

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

    # ############################ UTIL HELPER METHOD #######################
    async def __validate_call_id(self, call_id: Any) -> bool:
        """
        Validates call ID
        """

        is_valid = True
        if not isinstance(call_id, str) or len(call_id) < 21 or len(call_id) > 21:
            is_valid = False

        if not is_valid:
            await self.send_json(
                {
                    "type": "error",
                    "message": "call_id must be a valid 21 characters string",
                    "errors": ["call_id must be a valid 21 characters string"],
                    "status_code": 4000,
                }
            )
        return is_valid
