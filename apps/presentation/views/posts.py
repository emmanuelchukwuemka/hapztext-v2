from dataclasses import asdict

from drf_spectacular.utils import extend_schema
from loguru import logger
from rest_framework.decorators import (
    api_view,
    parser_classes,
    permission_classes,
    throttle_classes,
)
from rest_framework.parsers import JSONParser, MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.throttling import UserRateThrottle

from apps.application.posts.dtos import (
    PostDetailDTO,
    PostListDTO,
    PostReactionDTO,
    PostShareDTO,
    UserPostsDTO,
)
from apps.infrastructure.posts.models import Post
from apps.infrastructure.posts.repositories import to_domain_post_data
from apps.presentation.factory import (
    create_post_rule,
    get_notify_followers_of_post_rule,
    get_notify_post_creator_of_reply_rule,
    posts_list_rule,
    react_to_post_rule,
    remove_reaction_rule,
    share_post_rule,
    user_posts_rule,
)
from apps.presentation.responses import StandardResponse
from apps.presentation.serializers.examples import (
    ErrorResponseExampleSerializer,
    SuccessResponseExampleSerializer,
)
from apps.presentation.serializers.posts import (
    PostCreateSerializer,
    PostListSerializer,
    PostReactionSerializer,
    PostShareSerializer,
    UserPostsSerializer,
)


@extend_schema(
    request=PostCreateSerializer,
    responses={
        201: SuccessResponseExampleSerializer,
        400: ErrorResponseExampleSerializer,
        500: ErrorResponseExampleSerializer,
    },
    description="Create a new post.",
    tags=["Posts"],
)
@api_view(["POST"])
@permission_classes([IsAuthenticated])
@throttle_classes([UserRateThrottle])
@parser_classes([MultiPartParser, JSONParser])
def create_post(request: Request) -> Response:
    serializer = PostCreateSerializer(
        data=request.data, context={"sender_id": request.user.id}
    )
    serializer.is_valid(raise_exception=True)

    post_creation_rule = create_post_rule()
    post = post_creation_rule(PostDetailDTO(**serializer.validated_data))
    post_data = asdict(post)

    try:
        if post_data["is_reply"] and post_data["previous_post_id"]:
            original_post = to_domain_post_data(
                Post.objects.get(id=post_data["previous_post_id"])
            )

            notify_reply_rule = get_notify_post_creator_of_reply_rule()
            notify_reply_rule(
                post_creator_id=original_post.sender_id,
                replier_id=post_data["sender_id"],
                original_post_id=post_data["previous_post_id"],
                reply_id=post_data["id"],
            )
        else:
            notify_followers_rule = get_notify_followers_of_post_rule()
            notify_followers_rule(
                post_creator_id=post_data["sender_id"],
                post_id=post_data["id"],
                post_content=post_data["text_content"] or "New media post",
            )
    except Exception as e:
        logger.error(f"Failed to send post notifications: {e}")

    return StandardResponse.created(
        data=asdict(post), message="Post created successfully."
    )


@extend_schema(
    request=PostListSerializer,
    responses={
        200: SuccessResponseExampleSerializer,
        400: ErrorResponseExampleSerializer,
        500: ErrorResponseExampleSerializer,
    },
    description="Fetch existing posts.",
    tags=["Posts"],
)
@api_view(["GET"])
@permission_classes([IsAuthenticated])
@throttle_classes([UserRateThrottle])
def fetch_posts_list(request: Request, page: int, page_size: int) -> Response:
    serializer = PostListSerializer(
        data={
            "page": page,
            "page_size": page_size,
            "feed_type": request.query_params.get("feed_type", "timeline"),
        }
    )
    serializer.is_valid(raise_exception=True)

    posts_list_retrieval_rule = posts_list_rule()
    posts_data = posts_list_retrieval_rule(
        PostListDTO(**serializer.validated_data), current_user_id=request.user.id
    )

    return StandardResponse.success(
        data=asdict(posts_data), message="Posts fetched successfully."
    )


@extend_schema(
    request=UserPostsSerializer,
    responses={
        200: SuccessResponseExampleSerializer,
        400: ErrorResponseExampleSerializer,
        500: ErrorResponseExampleSerializer,
    },
    description="Fetch posts for a specific user.",
    tags=["Posts"],
)
@api_view(["GET"])
@permission_classes([IsAuthenticated])
@throttle_classes([UserRateThrottle])
def fetch_user_posts(
    request: Request, user_id: str, page: int, page_size: int
) -> Response:
    serializer = UserPostsSerializer(
        data={"page": page, "page_size": page_size, "user_id": user_id},
        context={"user_id": user_id},
    )
    serializer.is_valid(raise_exception=True)

    user_posts_retrieval_rule = user_posts_rule()
    posts_data = user_posts_retrieval_rule(
        UserPostsDTO(**serializer.validated_data), current_user_id=request.user.id
    )

    return StandardResponse.success(
        data=asdict(posts_data), message="User posts fetched successfully."
    )


@extend_schema(
    request=PostReactionSerializer,
    responses={
        201: SuccessResponseExampleSerializer,
        400: ErrorResponseExampleSerializer,
        500: ErrorResponseExampleSerializer,
    },
    description="React to a post with an emoji (like, love, haha, wow, sad, angry).",
    tags=["Posts"],
)
@api_view(["POST"])
@permission_classes([IsAuthenticated])
@throttle_classes([UserRateThrottle])
def react_to_post(request: Request, post_id: str) -> Response:
    serializer = PostReactionSerializer(
        data=request.data, context={"post_id": post_id, "user_id": request.user.id}
    )
    serializer.is_valid(raise_exception=True)
    reaction_rule = react_to_post_rule()
    reaction = reaction_rule(PostReactionDTO(**serializer.validated_data))

    return StandardResponse.created(
        data=asdict(reaction), message="Reaction added successfully."
    )


@extend_schema(
    responses={
        204: SuccessResponseExampleSerializer,
        400: ErrorResponseExampleSerializer,
        500: ErrorResponseExampleSerializer,
    },
    description="Remove reaction from a post.",
    tags=["Posts"],
)
@api_view(["DELETE"])
@permission_classes([IsAuthenticated])
@throttle_classes([UserRateThrottle])
def remove_post_reaction(request: Request, post_id: str) -> Response:
    remove_reaction_rule_instance = remove_reaction_rule()
    remove_reaction_rule_instance(request.user.id, post_id)
    return StandardResponse.deleted(message="Reaction removed successfully.")


@extend_schema(
    request=PostShareSerializer,
    responses={
        201: SuccessResponseExampleSerializer,
        400: ErrorResponseExampleSerializer,
        500: ErrorResponseExampleSerializer,
    },
    description="Share a post with an optional message.",
    tags=["Posts"],
)
@api_view(["POST"])
@permission_classes([IsAuthenticated])
@throttle_classes([UserRateThrottle])
def share_post(request: Request, post_id: str) -> Response:
    serializer = PostShareSerializer(
        data=request.data, context={"post_id": post_id, "user_id": request.user.id}
    )
    serializer.is_valid(raise_exception=True)
    share_rule = share_post_rule()
    share = share_rule(PostShareDTO(**serializer.validated_data))

    return StandardResponse.created(
        data=asdict(share), message="Post shared successfully."
    )
