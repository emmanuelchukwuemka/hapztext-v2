from dataclasses import dataclass
from datetime import UTC, datetime

from .value_objects import PostFormat


@dataclass
class Post:
    sender_id: str
    post_format: PostFormat
    text_content: str | None = None
    image_content: str | None = None
    audio_content: str | None = None
    video_content: str | None = None
    is_reply: bool = False
    previous_post_id: str | None = None
    sender_username: str | None = None
    is_published: bool = True
    scheduled_at: datetime | None = None
    id: str | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None


@dataclass
class PostReaction:
    user_id: str
    post_id: str
    reaction: str
    id: str | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None


@dataclass
class PostShare:
    user_id: str
    post_id: str
    shared_with_message: str | None = None
    id: str | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None


@dataclass
class PostTag:
    post_id: str
    tagged_user_id: str
    tagged_by_user_id: str
    id: str | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None
