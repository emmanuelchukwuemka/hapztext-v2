"""
Discover WebSocket Consumer
"""

import logging
from typing import Any, Dict

from channels.generic.websocket import AsyncJsonWebsocketConsumer
from django.contrib.auth.models import AnonymousUser

from apps.infrastructure.calls.repository import DiscoverRepository
from apps.infrastructure.users.models.tables import User

logger = logging.getLogger(__name__)


CLIENT_SEND_EVENT = [
    "get_list",
    "leave_discover",
]
BACKEND_SEND_EVENT = [
    "discover_presence",
    "discover_update_list",
    "error",
    "discover_list",
]


class DiscoverConsumer(AsyncJsonWebsocketConsumer):
    """
    DiscoverConsumer
    """

    def __init__(self, *args: object, **kwargs: object) -> None:
        """
        Constructor
        """
        self.user: AnonymousUser | None | User = None
        self.group_name: str | None = None
        self.repo: DiscoverRepository | None = None

        super().__init__(*args, **kwargs)

    async def connect(self):
        """
        Connect
        """
        try:
            self.user = self.scope["user"]  # type: ignore
            if not self.user or isinstance(self.user, AnonymousUser):
                await self.close(code=4001)
                return

            # Each discover websocket shares a group
            self.group_name = "discover_active"

            await self.channel_layer.group_add(self.group_name, self.channel_name)
            await self.accept()

            # Initialize Redis repository (Injected at ASGI scope)
            redis = self.scope["redis"]  # type: ignore
            self.repo = DiscoverRepository(redis)

            await self.send_json(
                {
                    "message": "connection usccessful",
                    "type": "connection_success",
                    "data": {
                        "events": {
                            "client_to_send": CLIENT_SEND_EVENT,
                            "backend_to_send": BACKEND_SEND_EVENT,
                        }
                    },
                }
            )

            # Send initial list to this user
            await self._send_current_list()

            # Mark user as active in discover
            await self.repo.enter_discover(str(self.user.id))

            # Notify others
            await self.channel_layer.group_send(
                group=self.group_name,
                message={
                    "type": "discover_presence",
                    "event": "user_joined",
                    "user_id": str(self.user.id),
                    "username": self.user.username,
                },
            )

            # Send updated discover list to everyone except the newly joined user
            current_users = await self.repo.get_active_users()
            await self.channel_layer.group_send(
                self.group_name,
                {
                    "type": "discover_update_list",
                    "data": current_users,
                    "user_id": self.user and self.user.id,
                },
            )

        except Exception as exc:
            logger.error("Error connecting to discover: %s", str(exc))
            raise exc

    async def disconnect(self, code: int):
        """
        Disconnect
        """
        try:
            await self.repo.leave_discover(str(self.user and self.user.id))  # type: ignore

            # Notify others
            await self.channel_layer.group_send(
                group=self.group_name or "",
                message={
                    "type": "discover_presence",
                    "event": "user_left",
                    "user_id": str(self.user and self.user.id),
                },
            )
        except Exception as e:
            logger.error("Discover disconnect error: %s", str(e))

        await self.channel_layer.group_discard(self.group_name or "", self.channel_name)

    async def receive_json(self, content: Dict[str, Any], **kwargs):
        """
        Handles client messages
        """
        try:
            event = content.get("type")

            if event == "get_list":
                await self._send_current_list()

            elif event == "leave_discover":
                await self._handle_leave()

            else:
                await self.send_json(
                    {"type": "error", "message": f"Unknown event: {event}"}
                )

        except Exception as exc:
            logger.error("Error recieving data. Discover mode: %s", str(exc))
            await self.send_json(
                {
                    "errors": ["An unexpected error occurred."],
                    "type": "error",
                    "status_code": 5000,
                    "message": "An unexpected error occurred.",
                }
            )

    # ######################### ###################
    async def _send_current_list(self):
        """
        Sends current list of users in discover mode
        """
        try:
            users = await self.repo.get_active_users()  # type: ignore
            await self.send_json(
                {
                    "type": "discover_list",
                    "data": users,
                }
            )
        except Exception as exc:
            logger.error("Error sending users in discover mode: %s", str(exc))
            await self.send_json(
                {
                    "errors": ["An unexpected error occurred."],
                    "type": "error",
                    "status_code": 5000,
                    "message": "An unexpected error occurred.",
                }
            )

    async def _handle_leave(self):
        """
        Handles leave discover mode
        """
        try:
            await self.repo.leave_discover(str(self.user and self.user.id))  # type: ignore

            # Notify others
            await self.channel_layer.group_send(
                group=self.group_name or "",
                message={
                    "type": "discover_presence",
                    "event": "user_left",
                    "user_id": str(self.user and self.user.id),
                    "username": str(self.user and self.user.username),
                },
            )

            await self.send_json({"type": "left_discover"})
            await self.close()
        except Exception as exc:
            logger.error("Error handling leave discover mode: %s", str(exc))
            await self.send_json(
                {
                    "errors": ["An unexpected error occurred."],
                    "type": "error",
                    "status_code": 5000,
                    "message": "An unexpected error occurred.",
                }
            )

    # ####################### ###############################
    async def discover_presence(self, event: Dict[str, Any]):
        """
        Sends real-time join/leave events
        """
        await self.send_json(event)

    async def discover_update_list(self, event: Dict[str, Any]):
        """
        Sends updated discover list when a user joins/leaves.
        """
        if self.user and self.user.id == event.get("user_id"):
            return
        await self.send_json(
            {
                "type": "discover_list_update",
                "data": event.get("data"),
            }
        )
