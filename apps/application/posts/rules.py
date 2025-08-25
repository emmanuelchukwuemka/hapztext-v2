from dataclasses import asdict

from loguru import logger

from apps.domain.posts.entities import Post

from .dtos import (
    PaginatedPostsResponseDTO,
    PaginatedUserPostsResponseDTO,
    PostDetailDTO,
    PostListDTO,
    PostResponseDTO,
    UserPostsDTO,
)
from .ports import PostRepositoryInterface


class PostListRule:
    def __init__(
        self,
        post_repository: PostRepositoryInterface,
    ) -> None:
        self.post_repository = post_repository

    def __call__(self, dto: PostListDTO) -> PaginatedPostsResponseDTO:
        posts, previous_link, next_link = self.post_repository.posts_list(
            page=dto.page, page_size=dto.page_size
        )

        posts_data = [
            PostResponseDTO(
                **{
                    key: value
                    for key, value in asdict(post).items()
                    if key in PostResponseDTO.__dataclass_fields__
                }
            )
            for post in posts
        ]

        return PaginatedPostsResponseDTO(
            result=posts_data,
            previous_posts_data=previous_link,
            next_posts_data=next_link,
        )


class CreatePostRule:
    def __init__(
        self,
        post_repository: PostRepositoryInterface,
    ) -> None:
        self.post_repository = post_repository

    def __call__(self, dto: PostDetailDTO) -> PostResponseDTO:
        post = Post(
            sender_id=dto.sender_id,
            post_format=dto.post_format,
            text_content=dto.text_content,
            image_content=dto.image_content,
            audio_content=dto.audio_content,
            video_content=dto.video_content,
            is_reply=dto.is_reply,
            previous_post_id=dto.previous_post_id,
            sender_username=dto.sender_username,
        )

        created_post = self.post_repository.create(post)

        return PostResponseDTO(
            **{
                key: value
                for key, value in asdict(created_post).items()
                if key in PostResponseDTO.__dataclass_fields__
            }
        )


class UserPostsRule:
    def __init__(
        self,
        post_repository: PostRepositoryInterface,
    ) -> None:
        self.post_repository = post_repository

    def __call__(self, dto: UserPostsDTO) -> PaginatedUserPostsResponseDTO:
        posts, previous_link, next_link = self.post_repository.user_posts_list(
            user_id=dto.user_id, page=dto.page, page_size=dto.page_size
        )

        posts_data = [
            PostResponseDTO(
                **{
                    key: value
                    for key, value in asdict(post).items()
                    if key in PostResponseDTO.__dataclass_fields__
                }
            )
            for post in posts
        ]

        return PaginatedUserPostsResponseDTO(
            result=posts_data,
            previous_posts_data=previous_link,
            next_posts_data=next_link,
        )
