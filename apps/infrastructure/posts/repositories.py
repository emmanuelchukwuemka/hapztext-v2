from datetime import datetime, timedelta
from typing import Any, Dict, List, Tuple
from urllib.parse import urlparse

from django.conf import settings
from django.db import models
from django.urls import reverse
from django.utils import timezone

from apps.application.posts.ports import (
    PostReactionRepositoryInterface,
    PostRepositoryInterface,
    PostShareRepositoryInterface,
    PostTagRepositoryInterface,
)
from apps.domain.posts.entities import Post as DomainPost
from apps.domain.posts.entities import PostReaction as DomainPostReaction
from apps.domain.posts.entities import PostShare as DomainPostShare
from apps.domain.posts.entities import PostTag as DomainPostTag
from apps.infrastructure.posts.models import Post, PostReaction, PostShare, PostTag


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
        "is_published": domain_post.is_published,
        "scheduled_at": domain_post.scheduled_at,
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
        is_published=django_post.is_published,
        scheduled_at=django_post.scheduled_at,
        id=django_post.id,
        created_at=django_post.created_at,
        updated_at=django_post.updated_at,
    )


def to_domain_post_reaction_data(django_reaction: PostReaction) -> DomainPostReaction:
    return DomainPostReaction(
        user_id=django_reaction.user_id,
        post_id=django_reaction.post_id,
        reaction=django_reaction.reaction,
        id=django_reaction.id,
        created_at=django_reaction.created_at,
        updated_at=django_reaction.updated_at,
    )


def to_domain_post_share_data(django_share: PostShare) -> DomainPostShare:
    return DomainPostShare(
        user_id=django_share.user_id,
        post_id=django_share.post_id,
        shared_with_message=django_share.shared_with_message,
        id=django_share.id,
        created_at=django_share.created_at,
        updated_at=django_share.updated_at,
    )


def to_domain_post_tag_data(django_tag: PostTag) -> DomainPostTag:
    return DomainPostTag(
        post_id=django_tag.post_id,
        tagged_user_id=django_tag.tagged_user_id,
        tagged_by_user_id=django_tag.tagged_by_user_id,
        id=django_tag.id,
        created_at=django_tag.created_at,
        updated_at=django_tag.updated_at,
    )


class DjangoPostRepository(PostRepositoryInterface):
    def create(self, post: DomainPost) -> DomainPost:
        django_post = from_domain_post_data(post)

        created_post = Post.objects.create(**django_post)
        return to_domain_post_data(created_post)

    def delete(self, post_id: str, user_id: str) -> None:
        post = Post.objects.get(id=post_id, sender_id=user_id)
        post.delete()

    def get_post_replies(
        self, post_id: str, page: int, page_size: int
    ) -> Tuple[List[Any], str | None, str | None]:
        queryset = (
            Post.objects.filter(
                is_reply=True, previous_post_id=post_id, is_published=True
            )
            .select_related("sender")
            .order_by("-created_at")
        )

        total_replies = queryset.count()
        offset = (page - 1) * page_size
        end = offset + page_size

        replies = [to_domain_post_data(qs) for qs in list(queryset[offset:end])]

        previous_link = None
        if page > 1:
            previous_link = reverse(
                "fetch-post-replies",
                kwargs={"post_id": post_id, "page": page - 1, "page_size": page_size},
            )

        next_link = None
        if end < total_replies:
            next_link = reverse(
                "fetch-post-replies",
                kwargs={"post_id": post_id, "page": page + 1, "page_size": page_size},
            )

        return replies, previous_link, next_link

    def find_by_id(self, post_id: str) -> DomainPost | None:
        try:
            post = Post.objects.select_related("sender").get(id=post_id)
            return to_domain_post_data(post)
        except Post.DoesNotExist:
            return None

    def posts_list(
        self, page: int, page_size: int
    ) -> Tuple[List[Any], str | None, str | None]:
        queryset = (
            Post.objects.filter(is_published=True)
            .select_related("sender")
            .prefetch_related("reactions", "shares")
            .order_by("-created_at")
        )
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
        queryset = Post.objects.filter(sender_id=user_id, is_published=True).order_by(
            "-created_at"
        )
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

    def trending_posts_list(
        self, page: int, page_size: int
    ) -> Tuple[List[Any], str | None, str | None]:
        yesterday = timezone.now() - timedelta(days=1)

        queryset = (
            Post.objects.filter(is_published=True)
            .annotate(
                recent_reaction_count=models.Count(
                    "reactions", filter=models.Q(reactions__created_at__gte=yesterday)
                )
            )
            .order_by("-recent_reaction_count", "-created_at")
        )

        total_posts = queryset.count()
        offset = (page - 1) * page_size
        end = offset + page_size

        posts = [to_domain_post_data(qs) for qs in list(queryset[offset:end])]

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

        return posts, previous_link, next_link

    def popular_posts_list(
        self, page: int, page_size: int
    ) -> Tuple[List[Any], str | None, str | None]:
        queryset = (
            Post.objects.filter(is_published=True)
            .annotate(
                total_reactions=models.Count("reactions"),
                total_shares=models.Count("shares"),
                popularity_score=models.F("total_reactions") + models.F("total_shares"),
            )
            .order_by("-popularity_score", "-created_at")
        )

        total_posts = queryset.count()
        offset = (page - 1) * page_size
        end = offset + page_size

        posts = [to_domain_post_data(qs) for qs in list(queryset[offset:end])]

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

        return posts, previous_link, next_link

    def get_scheduled_posts(self) -> List[Any]:
        now = datetime.now(timezone.utc)
        queryset = Post.objects.filter(
            is_published=False, scheduled_at__isnull=False, scheduled_at__lte=now
        )
        return [to_domain_post_data(post) for post in queryset]

    def publish_post(self, post_id: str) -> DomainPost:
        post = Post.objects.get(id=post_id)
        post.is_published = True
        post.save()
        return to_domain_post_data(post)


class DjangoPostReactionRepository(PostReactionRepositoryInterface):
    def create_or_update(self, reaction: DomainPostReaction) -> DomainPostReaction:
        django_reaction, created = PostReaction.objects.update_or_create(
            user_id=reaction.user_id,
            post_id=reaction.post_id,
            defaults={"reaction": reaction.reaction},
        )
        return to_domain_post_reaction_data(django_reaction)

    def delete(self, user_id: str, post_id: str) -> None:
        PostReaction.objects.filter(user_id=user_id, post_id=post_id).delete()

    def find_user_reaction(
        self, user_id: str, post_id: str
    ) -> DomainPostReaction | None:
        try:
            reaction = PostReaction.objects.get(user_id=user_id, post_id=post_id)
            return to_domain_post_reaction_data(reaction)
        except PostReaction.DoesNotExist:
            return None

    def get_post_reaction_counts(self, post_id: str) -> Dict[str, int]:
        reactions = (
            PostReaction.objects.filter(post_id=post_id)
            .values("reaction")
            .annotate(count=models.Count("id"))
        )
        return {reaction["reaction"]: reaction["count"] for reaction in reactions}

    def get_posts_reaction_counts(
        self, post_ids: List[str]
    ) -> Dict[str, Dict[str, int]]:
        reactions = (
            PostReaction.objects.filter(post_id__in=post_ids)
            .values("post_id", "reaction")
            .annotate(count=models.Count("id"))
        )

        result = {}
        for reaction in reactions:
            post_id = reaction["post_id"]
            if post_id not in result:
                result[post_id] = {}
            result[post_id][reaction["reaction"]] = reaction["count"]

        return result

    def get_post_reactions(
        self, post_id: str, page: int, page_size: int
    ) -> Tuple[List[Any], str | None, str | None]:
        queryset = (
            PostReaction.objects.filter(post_id=post_id)
            .select_related("user", "user__user_profile")
            .order_by("-created_at")
        )

        total_reactions = queryset.count()
        offset = (page - 1) * page_size
        end = offset + page_size

        reactions = list(queryset[offset:end])

        previous_link = None
        if page > 1:
            previous_link = reverse(
                "fetch-post-reactors",
                kwargs={"post_id": post_id, "page": page - 1, "page_size": page_size},
            )

        next_link = None
        if end < total_reactions:
            next_link = reverse(
                "fetch-post-reactors",
                kwargs={"post_id": post_id, "page": page + 1, "page_size": page_size},
            )

        return reactions, previous_link, next_link


class DjangoPostShareRepository(PostShareRepositoryInterface):
    def create(self, share: DomainPostShare) -> DomainPostShare:
        django_share = PostShare.objects.create(
            user_id=share.user_id,
            post_id=share.post_id,
            shared_with_message=share.shared_with_message,
        )
        return to_domain_post_share_data(django_share)

    def get_post_share_count(self, post_id: str) -> int:
        return PostShare.objects.filter(post_id=post_id).count()

    def get_posts_share_counts(self, post_ids: List[str]) -> Dict[str, int]:
        shares = (
            PostShare.objects.filter(post_id__in=post_ids)
            .values("post_id")
            .annotate(count=models.Count("id"))
        )
        return {share["post_id"]: share["count"] for share in shares}


class DjangoPostTagRepository(PostTagRepositoryInterface):
    def create_tags(self, tags: List[DomainPostTag]) -> List[DomainPostTag]:
        django_tags = [
            PostTag(
                post_id=tag.post_id,
                tagged_user_id=tag.tagged_user_id,
                tagged_by_user_id=tag.tagged_by_user_id,
            )
            for tag in tags
        ]
        created_tags = PostTag.objects.bulk_create(django_tags)
        return [to_domain_post_tag_data(tag) for tag in created_tags]

    def get_post_tags(self, post_id: str) -> List[DomainPostTag]:
        tags = PostTag.objects.filter(post_id=post_id)
        return [to_domain_post_tag_data(tag) for tag in tags]
