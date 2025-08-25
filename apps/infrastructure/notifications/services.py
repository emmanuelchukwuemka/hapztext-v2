import django_eventstream
from loguru import logger

from apps.application.notifications.ports import (
    NotificationDispatcherInterface,
    NotificationServiceInterface,
)
from apps.domain.notifications.entities import Notification


class SSENotificationService(NotificationServiceInterface):
    def send_real_time_notification(
        self, user_id: str, notification_data: dict
    ) -> None:
        channel = self.get_user_channel(user_id)

        try:
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
        return f"notifications-{user_id}"

    def send_unread_count_update(self, user_id: str, unread_count: int) -> None:
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


class NotificationDispatcher(NotificationDispatcherInterface):
    def __init__(self, notification_service: SSENotificationService):
        self.notification_service = notification_service

    def dispatch_notification(self, notification: Notification) -> None:
        notification_data = {
            "id": notification.id,
            "type": notification.notification_type,
            "message": notification.message,
            "data": notification.data,
            "sender_id": notification.sender_id,
            "created_at": notification.created_at.isoformat(),
            "is_read": notification.is_read,
        }

        self.notification_service.send_real_time_notification(
            notification.recipient_id, notification_data
        )

    def update_unread_count(self, user_id: str) -> None:
        from apps.infrastructure.notifications.repositories import (
            DjangoNotificationRepository,
        )

        repo = DjangoNotificationRepository()
        unread_count = repo.get_unread_count(user_id)

        self.notification_service.send_unread_count_update(user_id, unread_count)
