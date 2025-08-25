from dataclasses import dataclass
from datetime import datetime
from typing import List


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


@dataclass
class PostResponseDTO(PostDetailDTO):
    id: str | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None


@dataclass
class PostListDTO:
    page: int = 1
    page_size: int = 20


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
