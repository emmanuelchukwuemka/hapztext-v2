from dataclasses import dataclass, field
from datetime import UTC, datetime
from typing import Any, Dict

from .value_objects import NotificationData, NotificationType


@dataclass
class Notification:
    recipient_id: str
    sender_id: str
    notification_type: str
    message: str
    data: Dict[str, Any] = field(default_factory=dict)
    is_read: bool = False
    id: str | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None

    def __post_init__(self) -> None:
        self.notification_type = NotificationType(self.notification_type).value
        self.data = NotificationData(self.data).value

    def mark_as_read(self) -> None:
        self.is_read = True
        self.updated_at = datetime.now(tz=UTC)


@dataclass
class NotificationPreferences:
    user_id: str
    post_notifications_enabled: bool = True
    follow_notifications_enabled: bool = True
    reply_notifications_enabled: bool = True
    id: str | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None
