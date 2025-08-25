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

from apps.presentation.factory import get_user_followings_rule
from apps.application.users.dtos import (
    FollowRequestDTO,
    FriendsListDTO,
    HandleFollowRequestDTO,
    PendingRequestsDTO,
    UserDetailDTO,
    UserFollowersDTO,
    UserFollowingsDTO,
    UserProfileDetailDTO,
    UserProfileListDTO,
)
from apps.presentation.factory import (
    create_user_profile_rule,
    fetch_user_profile_rule,
    fetch_user_rule,
    get_friends_list_rule,
    get_notify_user_of_follow_acceptance_rule,
    get_notify_user_of_follow_rule,
    get_pending_requests_rule,
    get_user_followers_rule,
    handle_follow_request_rule,
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
    HandleFollowRequestSerializer,
    PaginatedDataRequestSerializer,
    UserDetailSerializer,
    UserFollowersSerializer,
    UserFollowingsSerializer,
    UserProfileDetailSerializer,
    UserProfileListSerializer,
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
            follow_request_id=follow_request_data["id"],
        )
    except Exception as e:
        logger.error(f"Failed to send follow request notification: {e}")

    return StandardResponse.created(
        data=follow_request_data, message="Follow request sent successfully."
    )


@extend_schema(
    request=HandleFollowRequestSerializer,
    responses={
        200: SuccessResponseExampleSerializer,
        400: ErrorResponseExampleSerializer,
        500: ErrorResponseExampleSerializer,
    },
    description="Accept or decline a follow request.",
    tags=["Users"],
)
@api_view(["POST"])
@permission_classes([IsAuthenticated])
@throttle_classes([UserRateThrottle])
def handle_follow_request(request: Request, request_id: str) -> Response:
    serializer = HandleFollowRequestSerializer(
        data={**request.data},
        context={"request_id": request_id, "user_id": request.user.id},
    )
    serializer.is_valid(raise_exception=True)

    handle_request_rule = handle_follow_request_rule()
    updated_request = handle_request_rule(
        HandleFollowRequestDTO(**serializer.validated_data)
    )
    updated_request_data = asdict(updated_request)

    action = serializer.validated_data["action"]
    message = f"Follow request {action}ed successfully."

    if action == "accepted":
        try:
            notify_acceptance_rule = get_notify_user_of_follow_acceptance_rule()
            notify_acceptance_rule(
                requester_id=updated_request_data["requester_id"],
                accepter_id=updated_request_data["target_id"],
                follow_request_id=request_id,
            )
        except Exception as e:
            logger.error(f"Failed to send follow acceptance notification: {e}")

    return StandardResponse.success(data=updated_request_data, message=message)


@extend_schema(
    request=PaginatedDataRequestSerializer,
    responses={
        200: SuccessResponseExampleSerializer,
        400: ErrorResponseExampleSerializer,
        500: ErrorResponseExampleSerializer,
    },
    description="Get pending follow requests (sent and received).",
    tags=["Users"],
)
@api_view(["GET"])
@permission_classes([IsAuthenticated])
@throttle_classes([UserRateThrottle])
def get_pending_requests(request: Request, page: int, page_size: int) -> Response:
    serializer = PaginatedDataRequestSerializer(
        data={"page": page, "page_size": page_size},
        context={"user_id": request.user.id},
    )
    serializer.is_valid(raise_exception=True)

    pending_requests_rule = get_pending_requests_rule()
    requests_data = pending_requests_rule(
        PendingRequestsDTO(**serializer.validated_data)
    )

    return StandardResponse.success(
        data=asdict(requests_data), message="Pending requests fetched successfully."
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
