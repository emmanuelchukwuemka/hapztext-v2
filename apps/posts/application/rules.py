from dataclasses import asdict

from ..domain.entities import Post
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

    def execute(self, dto: PostListDTO) -> PaginatedPostsResponseDTO:
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

    def execute(self, dto: PostDetailDTO) -> PostResponseDTO:
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
        
        try:
            if created_post.is_reply and created_post.previous_post_id:
                # Notify original post creator of reply
                from apps.notifications.infrastructure.factory import get_notify_post_creator_of_reply_rule
                from apps.posts.infrastructure.repositories import DjangoPostRepository
                
                post_repo = DjangoPostRepository()
                original_post = post_repo._to_domain_post_data(
                    post_repo.Post.objects.get(id=created_post.previous_post_id)
                )
                
                notify_reply_rule = get_notify_post_creator_of_reply_rule()
                notify_reply_rule.execute(
                    post_creator_id=original_post.sender_id,
                    replier_id=created_post.sender_id,
                    original_post_id=created_post.previous_post_id,
                    reply_id=created_post.id
                )
            else:
                # Notify followers of new post
                from apps.notifications.infrastructure.factory import get_notify_followers_of_post_rule
                
                notify_followers_rule = get_notify_followers_of_post_rule()
                notify_followers_rule.execute(
                    post_creator_id=created_post.sender_id,
                    post_id=created_post.id,
                    post_content=created_post.text_content or "New media post"
                )
        except Exception as e:
            # Log error but don't fail post creation
            from core.infrastructure.logging.base import logger
            logger.error(f"Failed to send post notifications: {e}")

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

    def execute(self, dto: UserPostsDTO) -> PaginatedUserPostsResponseDTO:
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
