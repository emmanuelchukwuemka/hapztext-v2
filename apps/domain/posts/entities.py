from dataclasses import dataclass
from datetime import UTC, datetime

import nanoid

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
    id: str | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None
