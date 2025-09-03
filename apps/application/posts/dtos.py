from dataclasses import dataclass
from datetime import datetime
from typing import Dict, List


@dataclass
class PostDetailDTO:
    sender_id: str
    post_format: str | None = None
    text_content: str | None = None
    image_content: str | None = None
    audio_content: str | None = None
    video_content: str | None = None
    is_reply: bool = False
    previous_post_id: str | None = None
    sender_username: str | None = None
    is_published: bool = True
    scheduled_at: datetime | None = None
    tagged_user_ids: List[str] | None = None

    def __post_init__(self):
        if self.tagged_user_ids is None:
            self.tagged_user_ids = []


@dataclass
class PostResponseDTO(PostDetailDTO):
    id: str | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None
    reaction_counts: Dict[str, int] | None = None
    share_count: int = 0
    current_user_reaction: str | None = None

    def __post_init__(self):
        super().__post_init__()
        if self.reaction_counts is None:
            self.reaction_counts = {}


@dataclass
class PostListDTO:
    page: int = 1
    page_size: int = 20
    feed_type: str = "timeline"  # timeline, trending, popular


@dataclass
class PaginatedPostsResponseDTO:
    result: List[PostResponseDTO]
    previous_posts_data: str | None = None
    next_posts_data: str | None = None


@dataclass
class UserPostsDTO:
    user_id: str
    page: int = 1
    page_size: int = 20


@dataclass
class PaginatedUserPostsResponseDTO:
    result: List[PostResponseDTO]
    previous_posts_data: str | None = None
    next_posts_data: str | None = None


@dataclass
class PostReactionDTO:
    user_id: str
    post_id: str
    reaction_type: str


@dataclass
class PostReactionResponseDTO:
    id: str
    user_id: str
    post_id: str
    reaction_type: str
    created_at: datetime
    updated_at: datetime


@dataclass
class PostShareDTO:
    user_id: str
    post_id: str
    shared_with_message: str | None = None


@dataclass
class PostShareResponseDTO:
    id: str
    user_id: str
    post_id: str
    shared_with_message: str | None
    created_at: datetime
    updated_at: datetime


@dataclass
class PostTagDTO:
    post_id: str
    tagged_user_id: str
    tagged_by_user_id: str


@dataclass
class PostTagResponseDTO:
    id: str
    post_id: str
    tagged_user_id: str
    tagged_by_user_id: str
    created_at: datetime
    updated_at: datetime
