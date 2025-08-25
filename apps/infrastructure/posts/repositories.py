from typing import Any, Dict, List, Tuple
from urllib.parse import urlparse

from django.conf import settings
from django.urls import reverse

from apps.application.posts.ports import PostRepositoryInterface
from apps.domain.posts.entities import Post as DomainPost
from apps.infrastructure.posts.models import Post


def is_absolute_url(url) -> bool:
    return bool(urlparse(url).scheme)


def build_absolute_url(file_field) -> Any:
    if not file_field:
        return None

    file_url = file_field.url

    if is_absolute_url(file_url):
        return file_url

    return f"{settings.BACKEND_DOMAIN}{file_url}"


def from_domain_post_data(domain_post: DomainPost) -> Dict[str, Any]:
    return {
        "sender_id": domain_post.sender_id,
        "post_format": domain_post.post_format,
        "text_content": domain_post.text_content,
        "image_content": domain_post.image_content,
        "audio_content": domain_post.audio_content,
        "video_content": domain_post.video_content,
        "is_reply": domain_post.is_reply,
        "previous_post_id": domain_post.previous_post_id,
    }


def to_domain_post_data(django_post: Post) -> DomainPost:
    return DomainPost(
        sender_id=django_post.sender.id,
        post_format=django_post.post_format,
        text_content=django_post.text_content,
        image_content=build_absolute_url(django_post.image_content),
        audio_content=build_absolute_url(django_post.audio_content),
        video_content=build_absolute_url(django_post.video_content),
        is_reply=django_post.is_reply,
        previous_post_id=django_post.previous_post_id,
        sender_username=django_post.sender.username,
        id=django_post.id,
        created_at=django_post.created_at,
        updated_at=django_post.updated_at,
    )


class DjangoPostRepository(PostRepositoryInterface):
    def create(self, post: DomainPost) -> DomainPost:
        django_post = from_domain_post_data(post)

        created_post = Post.objects.create(**django_post)
        return to_domain_post_data(created_post)

    def posts_list(
        self, page: int, page_size: int
    ) -> Tuple[List[Any], str | None, str | None]:
        queryset = Post.objects.all().order_by("-created_at")
        total_posts = queryset.count()

        offset = (page - 1) * page_size
        end = offset + page_size

        profiles = [to_domain_post_data(qs) for qs in list(queryset[offset:end])]

        previous_link = None
        if page > 1:
            previous_link = reverse(
                "fetch-posts-list", kwargs={"page": page - 1, "page_size": page_size}
            )

        next_link = None
        if end < total_posts:
            next_link = reverse(
                "fetch-posts-list", kwargs={"page": page + 1, "page_size": page_size}
            )

        return profiles, previous_link, next_link

    def user_posts_list(
        self, user_id: str, page: int, page_size: int
    ) -> Tuple[List[Any], str | None, str | None]:
        """Get posts for a specific user"""
        queryset = Post.objects.filter(sender_id=user_id).order_by("-created_at")
        total_posts = queryset.count()

        offset = (page - 1) * page_size
        end = offset + page_size

        posts = [to_domain_post_data(qs) for qs in list(queryset[offset:end])]

        previous_link = None
        if page > 1:
            previous_link = reverse(
                "fetch-user-posts",
                kwargs={"user_id": user_id, "page": page - 1, "page_size": page_size},
            )

        next_link = None
        if end < total_posts:
            next_link = reverse(
                "fetch-user-posts",
                kwargs={"user_id": user_id, "page": page + 1, "page_size": page_size},
            )

        return posts, previous_link, next_link
