from dataclasses import asdict

from ..domain.entities import Post
from .dtos import PaginatedPostsResponseDTO, PostDetailDTO, PostListDTO, PostResponseDTO
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
        post = Post(**asdict(dto))

        created_post = self.post_repository.create(post)

        return PostResponseDTO(
            **{
                key: value
                for key, value in asdict(created_post).items()
                if key in PostResponseDTO.__dataclass_fields__
            }
        )
