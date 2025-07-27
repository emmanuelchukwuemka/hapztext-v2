from typing import Any, Dict, List, Tuple

from django.urls import reverse

from ..application.ports import PostRepositoryInterface
from ..domain.entities import Post as DomainPost
from ..infrastructure.models import Post


class DjangoPostRepository(PostRepositoryInterface):
    def create(self, post: DomainPost) -> DomainPost:
        django_post = self._to_django_post_data(post)

        created_post = Post.objects.create(**django_post)
        return self._to_domain_post_data(created_post)

    def posts_list(self, page: int, page_size: int) -> Tuple[List[Any], str, str]:
        queryset = Post.objects.all().order_by("-created_at")
        total_posts = queryset.count()

        offset = (page - 1) * page_size
        end = offset + page_size

        profiles = [self._to_domain_post_data(qs) for qs in list(queryset[offset:end])]

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

    def _to_django_post_data(self, domain_post: DomainPost) -> Dict[str, Any]:
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

    def _to_domain_post_data(self, django_post: Post) -> DomainPost:
        return DomainPost(
            sender_id=django_post.sender.id,
            post_format=django_post.post_format,
            text_content=django_post.text_content,
            image_content=django_post.image_content.name
            if django_post.image_content
            else None,
            audio_content=django_post.audio_content.name
            if django_post.audio_content
            else None,
            video_content=django_post.video_content.name
            if django_post.video_content
            else None,
            is_reply=django_post.is_reply,
            previous_post_id=django_post.previous_post_id,
            sender_username=django_post.sender.username,
            id=django_post.id,
            created_at=django_post.created_at,
            updated_at=django_post.updated_at,
        )
