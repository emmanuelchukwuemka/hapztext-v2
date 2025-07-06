from dataclasses import asdict

from drf_spectacular.utils import extend_schema
from rest_framework.decorators import (
    api_view,
    parser_classes,
    permission_classes,
    throttle_classes,
)
from rest_framework.parsers import JSONParser, MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.request import Request
from rest_framework.throttling import UserRateThrottle

from core.presentation.responses import StandardResponse
from core.presentation.serializers import (
    ErrorResponseExampleSerializer,
    SuccessResponseExampleSerializer,
)

from ...users.application.dtos import (
    UserDetailDTO,
    UserProfileDetailDTO,
    UserProfileListDTO,
    FollowUserDTO
)
from ...users.application.rules import (
    CreateUserProfileRule,
    FetchUserProfileRule,
    FetchUserRule,
    UpdateUserRule,
    UserProfileListRule,
    FollowUserRule
)
from ...users.infrastructure.repositories import (
    DjangoUserProfileRepository,
    DjangoUserRepository,
    DjangoUserFollowingRepository
)
from ...users.presentation.serializers import (
    UserDetailSerializer,
    UserProfileDetailSerializer,
    UserProfileListSerializer,
    FollowUserSerializer
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
def fetch_user(request: Request) -> StandardResponse:
    user_repository = DjangoUserRepository()
    fetch_user_rule = FetchUserRule(user_repository=user_repository)

    user = fetch_user_rule.execute(UserDetailDTO(id=request.user.id))

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
def update_user(request: Request) -> StandardResponse:
    user_repository = DjangoUserRepository()
    update_user_rule = UpdateUserRule(user_repository=user_repository)

    serializer = UserDetailSerializer(data=request.data, context={"id": request.user.id})
    serializer.is_valid(raise_exception=True)

    user = update_user_rule.execute(UserDetailDTO(**serializer.validated_data))

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
def create_user_profile(request: Request) -> StandardResponse:
    user_profile_repository = DjangoUserProfileRepository()
    create_user_profile_rule = CreateUserProfileRule(
        user_profile_repository=user_profile_repository
    )

    serializer = UserProfileDetailSerializer(data=request.data, context={"user_id": request.user.id})
    serializer.is_valid(raise_exception=True)

    user_profile = create_user_profile_rule.execute(
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
def fetch_user_profile(request: Request, user_id: str) -> StandardResponse:
    user_profile_repository = DjangoUserProfileRepository()
    fetch_user_profile_rule = FetchUserProfileRule(
        user_profile_repository=user_profile_repository
    )

    serializer = UserProfileDetailSerializer(data={"user_id": user_id})
    serializer.is_valid(raise_exception=True)

    user_profile = fetch_user_profile_rule.execute(
        UserProfileDetailDTO(**serializer.validated_data)
    )

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
def fetch_profiles_list(request: Request, page: int, page_size: int) -> StandardResponse:
    user_profile_repository = DjangoUserProfileRepository()
    fetch_profiles_rule = UserProfileListRule(
        user_profile_repository=user_profile_repository
    )

    serializer = UserProfileListSerializer(data={"page": page, "page_size": page_size})
    serializer.is_valid(raise_exception=True)
    
    profiles_data = fetch_profiles_rule.execute(UserProfileListDTO(**serializer.validated_data))
    
    return StandardResponse.success(
        data=asdict(profiles_data), message="User profiles fetched successfully."
    )
    
    
@extend_schema(
    request=FollowUserSerializer,
    responses={
        200: SuccessResponseExampleSerializer,
        400: ErrorResponseExampleSerializer,
        500: ErrorResponseExampleSerializer,
    },
    description="Follow another existing user.",
    tags=["Users"],
)
@api_view(["POST"])
@permission_classes([IsAuthenticated])
@throttle_classes([UserRateThrottle])
def follow_user(request: Request, user_id: str) -> StandardResponse:
    user_profile_repository = DjangoUserProfileRepository()
    user_following_repository = DjangoUserFollowingRepository()
    follow_user_rule = FollowUserRule(
        user_profile_repository=user_profile_repository,
        user_following_repository=user_following_repository
    )

    serializer = FollowUserSerializer(data={"following_id": user_id}, context={"follower_id": request.user.id})
    serializer.is_valid(raise_exception=True)
    
    follow_data = follow_user_rule.execute(FollowUserDTO(**serializer.validated_data))
    
    return StandardResponse.success(
        data=asdict(follow_data), message="User followed successfully."
    )