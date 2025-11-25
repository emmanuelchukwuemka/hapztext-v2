from dataclasses import asdict
from datetime import UTC, datetime
from typing import Any, List

from apps.application.users.ports import UserFollowingRepositoryInterface
from apps.domain.posts.entities import Post, PostReaction, PostShare, PostTag

from .dtos import (
    FetchRepliesDTO,
    PaginatedPostReactorsResponseDTO,
    PaginatedPostsResponseDTO,
    PaginatedRepliesResponseDTO,
    PaginatedUserPostsResponseDTO,
    PostDetailDTO,
    PostListDTO,
    PostReactionDTO,
    PostReactionResponseDTO,
    PostReactorResponseDTO,
    PostReactorsDTO,
    PostResponseDTO,
    PostShareDTO,
    PostShareResponseDTO,
    UserPostsDTO,
)
from .ports import (
    PostReactionRepositoryInterface,
    PostRepositoryInterface,
    PostShareRepositoryInterface,
    PostTagRepositoryInterface,
)


class PostListRule:
    def __init__(
        self,
        post_repository: PostRepositoryInterface,
        post_reaction_repository: PostReactionRepositoryInterface,
        post_share_repository: PostShareRepositoryInterface,
    ) -> None:
        self.post_repository = post_repository
        self.post_reaction_repository = post_reaction_repository
        self.post_share_repository = post_share_repository

    def __call__(
        self, dto: PostListDTO, current_user_id: str = None
    ) -> PaginatedPostsResponseDTO:
        if dto.feed_type == "trending":
            posts, previous_link, next_link = self.post_repository.trending_posts_list(
                page=dto.page, page_size=dto.page_size
            )
        elif dto.feed_type == "popular":
            posts, previous_link, next_link = self.post_repository.popular_posts_list(
                page=dto.page, page_size=dto.page_size
            )
        else:
            posts, previous_link, next_link = self.post_repository.posts_list(
                page=dto.page, page_size=dto.page_size
            )

        post_ids = [post.id for post in posts]

        reaction_counts = self.post_reaction_repository.get_posts_reaction_counts(
            post_ids
        )
        share_counts = self.post_share_repository.get_posts_share_counts(post_ids)

        user_reactions = {}

        if current_user_id:
            for post_id in post_ids:
                reaction = self.post_reaction_repository.find_user_reaction(
                    current_user_id, post_id
                )
                if reaction:
                    user_reactions[post_id] = reaction.reaction

        posts_data = []

        for post in posts:
            post_dict = asdict(post)
            post_dict["reaction_counts"] = reaction_counts.get(post.id, {})
            post_dict["share_count"] = share_counts.get(post.id, 0)
            post_dict["current_user_reaction"] = user_reactions.get(post.id)

            posts_data.append(
                PostResponseDTO(
                    **{
                        key: value
                        for key, value in post_dict.items()
                        if key in PostResponseDTO.__dataclass_fields__
                    }
                )
            )

        return PaginatedPostsResponseDTO(
            result=posts_data,
            previous_posts_data=previous_link,
            next_posts_data=next_link,
        )


class CreatePostRule:
    def __init__(
        self,
        post_repository: PostRepositoryInterface,
        post_tag_repository: PostTagRepositoryInterface,
        user_mention_count_model: Any,
    ) -> None:
        self.post_repository = post_repository
        self.post_tag_repository = post_tag_repository
        self.user_mention_count_model = user_mention_count_model

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
            is_published=dto.is_published,
            scheduled_at=dto.scheduled_at,
        )

        created_post = self.post_repository.create(post)

        if dto.tagged_user_ids:
            tags = [
                PostTag(
                    post_id=created_post.id,
                    tagged_user_id=tagged_user_id,
                    tagged_by_user_id=dto.sender_id,
                )
                for tagged_user_id in dto.tagged_user_ids
            ]
            self.post_tag_repository.create_tags(tags)

            try:
                for tagged_user_id in dto.tagged_user_ids:
                    self.user_mention_count_model.increment_count(tagged_user_id)
            except Exception as e:
                from loguru import logger

                logger.error(f"Failed to increment mention count: {e}")

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
        post_reaction_repository: PostReactionRepositoryInterface,
        post_share_repository: PostShareRepositoryInterface,
    ) -> None:
        self.post_repository = post_repository
        self.post_reaction_repository = post_reaction_repository
        self.post_share_repository = post_share_repository

    def __call__(
        self, dto: UserPostsDTO, current_user_id: str = None
    ) -> PaginatedUserPostsResponseDTO:
        posts, previous_link, next_link = self.post_repository.user_posts_list(
            user_id=dto.user_id, page=dto.page, page_size=dto.page_size
        )

        post_ids = [post.id for post in posts]

        reaction_counts = self.post_reaction_repository.get_posts_reaction_counts(
            post_ids
        )
        share_counts = self.post_share_repository.get_posts_share_counts(post_ids)

        user_reactions = {}

        if current_user_id:
            for post_id in post_ids:
                reaction = self.post_reaction_repository.find_user_reaction(
                    current_user_id, post_id
                )
                if reaction:
                    user_reactions[post_id] = reaction.reaction

        posts_data = []
        for post in posts:
            post_dict = asdict(post)
            post_dict["reaction_counts"] = reaction_counts.get(post.id, {})
            post_dict["share_count"] = share_counts.get(post.id, 0)
            post_dict["current_user_reaction"] = user_reactions.get(post.id)

            posts_data.append(
                PostResponseDTO(
                    **{
                        key: value
                        for key, value in post_dict.items()
                        if key in PostResponseDTO.__dataclass_fields__
                    }
                )
            )

        return PaginatedUserPostsResponseDTO(
            result=posts_data,
            previous_posts_data=previous_link,
            next_posts_data=next_link,
        )


class DeletePostRule:
    def __init__(
        self,
        post_repository: PostRepositoryInterface,
    ) -> None:
        self.post_repository = post_repository

    def __call__(self, post_id: str, user_id: str) -> None:
        post = self.post_repository.find_by_id(post_id)
        if not post:
            raise ValueError("Post not found")

        if post.sender_id != user_id:
            raise ValueError("You can only delete your own posts")

        self.post_repository.delete(post_id, user_id)


class FetchRepliesRule:
    def __init__(
        self,
        post_repository: PostRepositoryInterface,
        post_reaction_repository: PostReactionRepositoryInterface,
        post_share_repository: PostShareRepositoryInterface,
    ) -> None:
        self.post_repository = post_repository
        self.post_reaction_repository = post_reaction_repository
        self.post_share_repository = post_share_repository

    def __call__(
        self, dto: FetchRepliesDTO, current_user_id: str = None
    ) -> PaginatedRepliesResponseDTO:
        replies, previous_link, next_link = self.post_repository.get_post_replies(
            post_id=dto.post_id, page=dto.page, page_size=dto.page_size
        )

        reply_ids = [reply.id for reply in replies]

        reaction_counts = self.post_reaction_repository.get_posts_reaction_counts(
            reply_ids
        )
        share_counts = self.post_share_repository.get_posts_share_counts(reply_ids)

        user_reactions = {}
        if current_user_id:
            for reply_id in reply_ids:
                reaction = self.post_reaction_repository.find_user_reaction(
                    current_user_id, reply_id
                )
                if reaction:
                    user_reactions[reply_id] = reaction.reaction

        replies_data = []
        for reply in replies:
            reply_dict = asdict(reply)
            reply_dict["reaction_counts"] = reaction_counts.get(reply.id, {})
            reply_dict["share_count"] = share_counts.get(reply.id, 0)
            reply_dict["current_user_reaction"] = user_reactions.get(reply.id)

            replies_data.append(
                PostResponseDTO(
                    **{
                        key: value
                        for key, value in reply_dict.items()
                        if key in PostResponseDTO.__dataclass_fields__
                    }
                )
            )

        return PaginatedRepliesResponseDTO(
            result=replies_data,
            previous_replies_data=previous_link,
            next_replies_data=next_link,
        )


class ReactToPostRule:
    def __init__(
        self,
        post_reaction_repository: PostReactionRepositoryInterface,
    ) -> None:
        self.post_reaction_repository = post_reaction_repository

    def __call__(self, dto: PostReactionDTO) -> PostReactionResponseDTO:
        reaction = PostReaction(
            user_id=dto.user_id,
            post_id=dto.post_id,
            reaction=dto.reaction,
        )

        created_reaction = self.post_reaction_repository.create_or_update(reaction)

        return PostReactionResponseDTO(
            **{
                key: value
                for key, value in asdict(created_reaction).items()
                if key in PostReactionResponseDTO.__dataclass_fields__
            }
        )


class RemoveReactionRule:
    def __init__(
        self,
        post_reaction_repository: PostReactionRepositoryInterface,
    ) -> None:
        self.post_reaction_repository = post_reaction_repository

    def __call__(self, user_id: str, post_id: str) -> None:
        self.post_reaction_repository.delete(user_id, post_id)


class GetPostReactorsRule:
    def __init__(
        self,
        post_reaction_repository: PostReactionRepositoryInterface,
        user_following_repository: UserFollowingRepositoryInterface,
    ) -> None:
        self.post_reaction_repository = post_reaction_repository
        self.user_following_repository = user_following_repository

    def __call__(self, dto: PostReactorsDTO) -> PaginatedPostReactorsResponseDTO:
        reactions, previous_link, next_link = (
            self.post_reaction_repository.get_post_reactions(
                dto.post_id, dto.page, dto.page_size
            )
        )

        reactors_result = []
        for reaction in reactions:
            profile = getattr(reaction.user, "user_profile", None)

            reactors_result.append(
                PostReactorResponseDTO(
                    user_id=reaction.user_id,
                    username=getattr(reaction.user, "username", None),
                    first_name=getattr(profile, "first_name", None),
                    last_name=getattr(profile, "last_name", None),
                    profile_picture=(
                        profile.profile_picture.url
                        if getattr(profile, "profile_picture", None)
                        and profile.profile_picture.name
                        else None
                    ),
                    reaction=reaction.reaction,
                    reacted_at=reaction.created_at,
                )
            )

        return PaginatedPostReactorsResponseDTO(
            result=reactors_result,
            previous_reactors_data=previous_link,
            next_reactors_data=next_link,
        )


class SharePostRule:
    def __init__(
        self,
        post_share_repository: PostShareRepositoryInterface,
    ) -> None:
        self.post_share_repository = post_share_repository

    def __call__(self, dto: PostShareDTO) -> PostShareResponseDTO:
        share = PostShare(
            user_id=dto.user_id,
            post_id=dto.post_id,
            shared_with_message=dto.shared_with_message,
        )

        created_share = self.post_share_repository.create(share)

        return PostShareResponseDTO(
            **{
                key: value
                for key, value in asdict(created_share).items()
                if key in PostShareResponseDTO.__dataclass_fields__
            }
        )


class PublishScheduledPostsRule:
    def __init__(
        self,
        post_repository: PostRepositoryInterface,
    ) -> None:
        self.post_repository = post_repository

    def __call__(self) -> List[Post]:
        scheduled_posts = self.post_repository.get_scheduled_posts()
        published_posts = []

        for post in scheduled_posts:
            if post.scheduled_at and post.scheduled_at <= datetime.now(
                post.scheduled_at.tzinfo or UTC
            ):
                published_post = self.post_repository.publish_post(post.id)
                published_posts.append(published_post)

        return published_posts
