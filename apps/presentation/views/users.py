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

from apps.application.users.dtos import (
    FollowRequestDTO,
    FriendSearchDTO,
    FriendsListDTO,
    UserDetailDTO,
    UserFollowersDTO,
    UserFollowingsDTO,
    UserProfileDetailDTO,
    UserProfileListDTO,
    UserSearchDTO,
)
from apps.presentation.factory import (
    create_user_profile_rule,
    fetch_user_profile_rule,
    fetch_user_rule,
    search_users_rule,
    get_friends_list_rule,
    get_notify_user_of_follow_rule,
    get_user_followers_rule,
    get_user_followings_rule,
    search_friends_rule,
    send_follow_request_rule,
    update_user_rule,
    user_profile_list_rule,
)
from apps.presentation.responses import StandardResponse
from apps.presentation.serializers.examples import (
    ErrorResponseExampleSerializer,
    SuccessResponseExampleSerializer,
)
from apps.presentation.serializers.users import (
    FollowRequestSerializer,
    FriendSearchSerializer,
    PaginatedDataRequestSerializer,
    UserDetailSerializer,
    UserFollowersSerializer,
    UserFollowingsSerializer,
    UserProfileDetailSerializer,
    UserProfileListSerializer,
    UserSearchSerializer,
)


@extend_schema(
    request=None,
    responses={
        200: SuccessResponseExampleSerializer,
        400: ErrorResponseExampleSerializer,
        500: ErrorResponseExampleSerializer,
    },
    description="Fetch a user.",
    tags=["Users"],
)
@api_view(["GET"])
@permission_classes([IsAuthenticated])
@throttle_classes([UserRateThrottle])
def fetch_user(request: Request) -> Response:
    user_rule = fetch_user_rule()
    user_id = request.query_params.get("id") or request.user.id
    user = user_rule(UserDetailDTO(id=user_id))

    return StandardResponse.success(
        data=asdict(user), message="User fetched successfully."
    )


@extend_schema(
    request=UserDetailSerializer,
    responses={
        200: SuccessResponseExampleSerializer,
        400: ErrorResponseExampleSerializer,
        500: ErrorResponseExampleSerializer,
    },
    description="Update a user.",
    tags=["Users"],
)
@api_view(["PUT"])
@permission_classes([IsAuthenticated])
@throttle_classes([UserRateThrottle])
def update_user(request: Request) -> Response:
    serializer = UserDetailSerializer(
        data=request.data, context={"id": request.user.id}
    )
    serializer.is_valid(raise_exception=True)

    update_rule = update_user_rule()
    user = update_rule(UserDetailDTO(**serializer.validated_data))

    return StandardResponse.updated(
        data=asdict(user), message="User update successful."
    )


@extend_schema(
    request=UserProfileDetailSerializer,
    responses={
        200: SuccessResponseExampleSerializer,
        400: ErrorResponseExampleSerializer,
        500: ErrorResponseExampleSerializer,
    },
    description="Create a user profile.",
    tags=["Users"],
)
@api_view(["POST"])
@permission_classes([IsAuthenticated])
@throttle_classes([UserRateThrottle])
@parser_classes([MultiPartParser, JSONParser])
def create_user_profile(request: Request) -> Response:
    serializer = UserProfileDetailSerializer(
        data=request.data, context={"user_id": request.user.id}
    )
    serializer.is_valid(raise_exception=True)

    create_profile_rule = create_user_profile_rule()
    user_profile = create_profile_rule(
        UserProfileDetailDTO(**serializer.validated_data)
    )

    return StandardResponse.created(
        data=asdict(user_profile), message="User profile creation successful."
    )


@extend_schema(
    request=UserProfileDetailSerializer,
    responses={
        200: SuccessResponseExampleSerializer,
        400: ErrorResponseExampleSerializer,
        500: ErrorResponseExampleSerializer,
    },
    description="Fetch a user profile.",
    tags=["Users"],
)
@api_view(["GET"])
@permission_classes([IsAuthenticated])
@throttle_classes([UserRateThrottle])
def fetch_user_profile(request: Request, user_id: str) -> Response:
    serializer = UserProfileDetailSerializer(data={"user_id": user_id})
    serializer.is_valid(raise_exception=True)

    fetch_profile_rule = fetch_user_profile_rule()
    user_profile = fetch_profile_rule(UserProfileDetailDTO(**serializer.validated_data))

    return StandardResponse.success(
        data=asdict(user_profile), message="User profile fetched successfully."
    )


@extend_schema(
    request=UserProfileListSerializer,
    responses={
        200: SuccessResponseExampleSerializer,
        400: ErrorResponseExampleSerializer,
        500: ErrorResponseExampleSerializer,
    },
    description="Fetch existing user profiles.",
    tags=["Users"],
)
@api_view(["GET"])
@permission_classes([IsAuthenticated])
@throttle_classes([UserRateThrottle])
def fetch_profiles_list(request: Request, page: int, page_size: int) -> Response:
    serializer = UserProfileListSerializer(data={"page": page, "page_size": page_size})
    serializer.is_valid(raise_exception=True)

    fetch_profiles_rule = user_profile_list_rule()
    profiles_data = fetch_profiles_rule(UserProfileListDTO(**serializer.validated_data))

    return StandardResponse.success(
        data=asdict(profiles_data), message="User profiles fetched successfully."
    )


@extend_schema(
    request=FollowRequestSerializer,
    responses={
        201: SuccessResponseExampleSerializer,
        400: ErrorResponseExampleSerializer,
        500: ErrorResponseExampleSerializer,
    },
    description="Send a follow request to another user.",
    tags=["Users"],
)
@api_view(["POST"])
@permission_classes([IsAuthenticated])
@throttle_classes([UserRateThrottle])
def send_follow_request(request: Request, user_id: str) -> Response:
    serializer = FollowRequestSerializer(
        data={}, context={"target_id": user_id, "requester_id": request.user.id}
    )
    serializer.is_valid(raise_exception=True)

    send_request_rule = send_follow_request_rule()
    follow_request = send_request_rule(FollowRequestDTO(**serializer.validated_data))
    follow_request_data = asdict(follow_request)

    try:
        notify_follow_rule = get_notify_user_of_follow_rule()
        notify_follow_rule(
            target_user_id=user_id,
            follower_id=request.user.id,
        )
    except Exception as e:
        logger.error(f"Failed to send user follow notification: {e}")

    return StandardResponse.created(
        data=follow_request_data, message="User followed successfully."
    )


@extend_schema(
    responses={
        200: SuccessResponseExampleSerializer,
        400: ErrorResponseExampleSerializer,
        500: ErrorResponseExampleSerializer,
    },
    description="Get friends list (mutual followers).",
    tags=["Users"],
)
@api_view(["GET"])
@permission_classes([IsAuthenticated])
@throttle_classes([UserRateThrottle])
def get_friends_list(request: Request, page: int, page_size: int) -> Response:
    serializer = PaginatedDataRequestSerializer(
        data={"page": page, "page_size": page_size},
        context={"user_id": request.user.id},
    )
    serializer.is_valid(raise_exception=True)

    friends_rule = get_friends_list_rule()
    friends_data = friends_rule(FriendsListDTO(**serializer.validated_data))

    return StandardResponse.success(
        data=asdict(friends_data), message="Friends list fetched successfully."
    )


@extend_schema(
    request=UserFollowersSerializer,
    responses={
        200: SuccessResponseExampleSerializer,
        400: ErrorResponseExampleSerializer,
        500: ErrorResponseExampleSerializer,
    },
    description="Get followers for a specific user.",
    tags=["Users"],
)
@api_view(["GET"])
@permission_classes([IsAuthenticated])
@throttle_classes([UserRateThrottle])
def get_user_followers(
    request: Request, user_id: str, page: int, page_size: int
) -> Response:
    serializer = UserFollowersSerializer(
        data={"page": page, "page_size": page_size, "user_id": user_id},
        context={"user_id": user_id},
    )
    serializer.is_valid(raise_exception=True)

    followers_rule = get_user_followers_rule()
    followers_data = followers_rule(UserFollowersDTO(**serializer.validated_data))

    return StandardResponse.success(
        data=asdict(followers_data), message="User followers fetched successfully."
    )


@extend_schema(
    request=UserFollowingsSerializer,
    responses={
        200: SuccessResponseExampleSerializer,
        400: ErrorResponseExampleSerializer,
        500: ErrorResponseExampleSerializer,
    },
    description="Get followings for a specific user.",
    tags=["Users"],
)
@api_view(["GET"])
@permission_classes([IsAuthenticated])
@throttle_classes([UserRateThrottle])
def get_user_followings(
    request: Request, user_id: str, page: int, page_size: int
) -> Response:
    serializer = UserFollowingsSerializer(
        data={"page": page, "page_size": page_size, "user_id": user_id},
        context={"user_id": user_id},
    )
    serializer.is_valid(raise_exception=True)

    followings_rule = get_user_followings_rule()
    followings_data = followings_rule(UserFollowingsDTO(**serializer.validated_data))

    return StandardResponse.success(
        data=asdict(followings_data), message="User followings fetched successfully."
    )


@extend_schema(
    request=UserSearchSerializer,
    responses={
        200: SuccessResponseExampleSerializer,
        400: ErrorResponseExampleSerializer,
        500: ErrorResponseExampleSerializer,
    },
    description="Search users (e.g., type '@jo' to find '@john').",
    tags=["Users"],
)
@api_view(["GET"])
@permission_classes([IsAuthenticated])
@throttle_classes([UserRateThrottle])
def search_users(request: Request) -> Response:
    query = request.query_params.get("query", "").strip()
    offset = int(request.query_params.get("offset", 1))
    limit = int(request.query_params.get("limit", 10))
    serializer = UserSearchSerializer(
        data={"query": query, "offset": offset, "limit": limit}
    )
    serializer.is_valid(raise_exception=True)

    search_rule = search_users_rule()
    users_data = search_rule(UserSearchDTO(**serializer.validated_data))

    return StandardResponse.success(
        data=asdict(users_data), message="Users search completed successfully."
    )


@extend_schema(
    request=FriendSearchSerializer,
    responses={
        200: SuccessResponseExampleSerializer,
        400: ErrorResponseExampleSerializer,
        500: ErrorResponseExampleSerializer,
    },
    description="Search friends especially for tagging autocompletion (e.g., type '@jo' to find '@john').",
    tags=["Users"],
)
@api_view(["GET"])
@permission_classes([IsAuthenticated])
@throttle_classes([UserRateThrottle])
def search_friends(request: Request) -> Response:
    query = request.query_params.get("query", "").strip()
    offset = int(request.query_params.get("offset", 1))
    limit = int(request.query_params.get("limit", 10))
    serializer = FriendSearchSerializer(
        data={"query": query, "offset": offset, "limit": limit},
        context={"user_id": request.user.id},
    )
    serializer.is_valid(raise_exception=True)

    search_rule = search_friends_rule()
    friends_data = search_rule(FriendSearchDTO(**serializer.validated_data))

    return StandardResponse.success(
        data=asdict(friends_data), message="Friends search completed successfully."
    )
