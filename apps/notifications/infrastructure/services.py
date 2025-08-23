import django_eventstream

from apps.notifications.application.ports import (
    NotificationDispatcherInterface,
    NotificationServiceInterface,
)
from apps.notifications.domain.entities import Notification
from core.infrastructure.logging.base import logger


class SSENotificationService(NotificationServiceInterface):
    def send_real_time_notification(
        self, user_id: str, notification_data: dict
    ) -> None:
        """Send notification via SSE to online users"""
        channel = self.get_user_channel(user_id)

        try:
            # Add metadata for better client handling
            enhanced_data = {
                **notification_data,
                "timestamp": notification_data.get("created_at"),
                "channel": channel,
                "user_id": user_id,
            }

            django_eventstream.send_event(channel, "notification", enhanced_data)
            logger.info(
                f"Sent real-time notification to user {user_id} on channel {channel}"
            )
        except Exception as e:
            logger.error(
                f"Failed to send real-time notification to user {user_id}: {e}"
            )

    def get_user_channel(self, user_id: str) -> str:
        """Get SSE channel name for user"""
        return f"notifications-{user_id}"

    def send_unread_count_update(self, user_id: str, unread_count: int) -> None:
        """Send updated unread count to user"""
        channel = self.get_user_channel(user_id)

        try:
            django_eventstream.send_event(
                channel,
                "unread_count_update",
                {"unread_count": unread_count, "user_id": user_id},
            )
            logger.info(f"Sent unread count update to user {user_id}: {unread_count}")
        except Exception as e:
            logger.error(f"Failed to send unread count update to user {user_id}: {e}")


# Enhanced Notification Dispatcher
class NotificationDispatcher(NotificationDispatcherInterface):
    def __init__(self, notification_service: SSENotificationService):
        self.notification_service = notification_service

    def dispatch_notification(self, notification: Notification) -> None:
        """Handle both persistence and real-time delivery"""
        # Convert notification to dict for SSE
        notification_data = {
            "id": notification.id,
            "type": notification.notification_type,
            "message": notification.message,
            "data": notification.data,
            "sender_id": notification.sender_id,
            "created_at": notification.created_at.isoformat(),
            "is_read": notification.is_read,
        }

        # Send real-time notification
        self.notification_service.send_real_time_notification(
            notification.recipient_id, notification_data
        )

    def update_unread_count(self, user_id: str) -> None:
        """Update unread count for user after marking notifications as read"""
        from apps.notifications.infrastructure.repositories import (
            DjangoNotificationRepository,
        )

        repo = DjangoNotificationRepository()
        unread_count = repo.get_unread_count(user_id)

        self.notification_service.send_unread_count_update(user_id, unread_count)
