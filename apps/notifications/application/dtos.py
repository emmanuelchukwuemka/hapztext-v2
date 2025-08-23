from dataclasses import dataclass
from datetime import datetime
from typing import Any, Dict, List


@dataclass
class CreateNotificationDTO:
    recipient_id: str
    sender_id: str
    notification_type: str
    message: str
    data: Dict[str, Any] = None

    def __post_init__(self):
        if self.data is None:
            self.data = {}


@dataclass
class NotificationResponseDTO:
    id: str
    recipient_id: str
    sender_id: str
    notification_type: str
    message: str
    data: Dict[str, Any]
    is_read: bool
    created_at: datetime
    updated_at: datetime


@dataclass
class NotificationListDTO:
    user_id: str
    page: int = 1
    page_size: int = 20
    unread_only: bool = False


@dataclass
class PaginatedNotificationsResponseDTO:
    result: List[NotificationResponseDTO]
    previous_notifications_data: str | None = None
    next_notifications_data: str | None = None
    unread_count: int = 0


@dataclass
class MarkNotificationsReadDTO:
    user_id: str
    notification_ids: List[str] | None = None  # None means mark all as read


@dataclass
class UpdateNotificationPreferencesDTO:
    user_id: str
    post_notifications_enabled: bool = True
    follow_notifications_enabled: bool = True
    reply_notifications_enabled: bool = True


@dataclass
class NotificationPreferencesResponseDTO:
    id: str
    user_id: str
    post_notifications_enabled: bool
    follow_notifications_enabled: bool
    reply_notifications_enabled: bool
    created_at: datetime
    updated_at: datetime
