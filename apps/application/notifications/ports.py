from abc import ABC, abstractmethod
from typing import Any, List, Tuple

from apps.domain.notifications.entities import Notification, NotificationPreferences


class NotificationRepositoryInterface(ABC):
    @abstractmethod
    def create(self, notification: Notification) -> Notification:
        pass

    @abstractmethod
    def find_by_id(self, notification_id: str) -> Notification | None:
        pass

    @abstractmethod
    def get_user_notifications(
        self, user_id: str, page: int, page_size: int, unread_only: bool = False
    ) -> Tuple[List[Any], str, str]:
        pass

    @abstractmethod
    def mark_as_read(self, notification_ids: List[str], user_id: str) -> None:
        pass

    @abstractmethod
    def mark_all_as_read(self, user_id: str) -> None:
        pass

    @abstractmethod
    def get_unread_count(self, user_id: str) -> int:
        pass


class NotificationPreferencesRepositoryInterface(ABC):
    @abstractmethod
    def create(self, preferences: NotificationPreferences) -> NotificationPreferences:
        pass

    @abstractmethod
    def find_by_user(self, user_id: str) -> NotificationPreferences | None:
        pass

    @abstractmethod
    def update(
        self, preferences: NotificationPreferences, **kwargs
    ) -> NotificationPreferences:
        pass

    @abstractmethod
    def get_or_create_for_user(self, user_id: str) -> NotificationPreferences:
        pass


class NotificationServiceInterface(ABC):
    @abstractmethod
    def send_real_time_notification(
        self, user_id: str, notification_data: dict
    ) -> None:
        """Send notification via SSE to online users"""
        pass

    @abstractmethod
    def get_user_channel(self, user_id: str) -> str:
        """Get SSE channel name for user"""
        pass


class NotificationDispatcherInterface(ABC):
    @abstractmethod
    def dispatch_notification(self, notification: Notification) -> None:
        """Handle both persistence and real-time delivery"""
        pass
