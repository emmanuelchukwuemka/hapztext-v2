from enum import StrEnum
from typing import List, Tuple


class NotificationType(StrEnum):
    POST_CREATED = "post_created"
    POST_REPLY = "post_reply"
    FOLLOW_REQUEST = "follow_request"
    FOLLOW_ACCEPTED = "follow_accepted"

    @classmethod
    def choices(cls) -> List[Tuple[str]]:
        return [(tag.value, tag.name) for tag in cls]

    @classmethod
    def values(cls) -> List[str]:
        return [tag.value for tag in cls]


class NotificationStatus(StrEnum):
    UNREAD = "unread"
    READ = "read"

    @classmethod
    def choices(cls) -> List[Tuple[str]]:
        return [(tag.value, tag.name) for tag in cls]

    @classmethod
    def values(cls) -> List[str]:
        return [tag.value for tag in cls]
