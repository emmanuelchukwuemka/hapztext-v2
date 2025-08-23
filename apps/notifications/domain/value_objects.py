from dataclasses import dataclass
from typing import Any, Dict

from .enums import NotificationType as NotificationTypeEnum


@dataclass(frozen=True)
class NotificationType:
    value: str

    def __post_init__(self):
        if not self._is_valid():
            raise ValueError(
                f"Invalid NotificationType. Select a value from {NotificationTypeEnum.values()}."
            )

    def _is_valid(self) -> bool:
        return self.value in NotificationTypeEnum.values()


@dataclass(frozen=True)
class NotificationData:
    value: Dict[str, Any]

    def __post_init__(self):
        if not isinstance(self.value, dict):
            raise ValueError("Notification data must be a dictionary.")
