from dataclasses import asdict

from django.views.decorators.csrf import csrf_exempt
from django_eventstream.views import events
from drf_spectacular.utils import extend_schema
from rest_framework.decorators import api_view, permission_classes, throttle_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.throttling import UserRateThrottle

from apps.application.notifications.dtos import (
    MarkNotificationsReadDTO,
    NotificationListDTO,
    UpdateNotificationPreferencesDTO,
)
from apps.presentation.factory import (
    get_mark_notifications_read_rule,
    get_notification_preferences_rule,
    get_update_notification_preferences_rule,
    get_user_notifications_rule,
)
from apps.presentation.responses import StandardResponse
from apps.presentation.serializers.examples import (
    ErrorResponseExampleSerializer,
    SuccessResponseExampleSerializer,
)
from apps.presentation.serializers.notifications import (
    MarkNotificationsReadSerializer,
    NotificationListSerializer,
    UpdateNotificationPreferencesSerializer,
)


@extend_schema(
    request=NotificationListSerializer,
    responses={
        200: SuccessResponseExampleSerializer,
        400: ErrorResponseExampleSerializer,
        500: ErrorResponseExampleSerializer,
    },
    description="Get user notifications with pagination.",
    tags=["Notifications"],
)
@api_view(["GET"])
@permission_classes([IsAuthenticated])
@throttle_classes([UserRateThrottle])
def get_notifications(request: Request, page: int, page_size: int) -> Response:
    unread_only = request.query_params.get("unread_only", "false").lower() == "true"

    serializer = NotificationListSerializer(
        data={"page": page, "page_size": page_size, "unread_only": unread_only},
        context={"user_id": request.user.id},
    )
    serializer.is_valid(raise_exception=True)

    notifications_rule = get_user_notifications_rule()
    notifications_data = notifications_rule(
        NotificationListDTO(**serializer.validated_data)
    )

    return StandardResponse.success(
        data=asdict(notifications_data), message="Notifications fetched successfully."
    )


@extend_schema(
    request=MarkNotificationsReadSerializer,
    responses={
        200: SuccessResponseExampleSerializer,
        400: ErrorResponseExampleSerializer,
        500: ErrorResponseExampleSerializer,
    },
    description="Mark notifications as read.",
    tags=["Notifications"],
)
@api_view(["POST"])
@permission_classes([IsAuthenticated])
@throttle_classes([UserRateThrottle])
def mark_notifications_read(request: Request) -> Response:
    serializer = MarkNotificationsReadSerializer(
        data=request.data, context={"user_id": request.user.id}
    )
    serializer.is_valid(raise_exception=True)

    mark_read_rule = get_mark_notifications_read_rule()
    mark_read_rule(MarkNotificationsReadDTO(**serializer.validated_data))

    return StandardResponse.success(
        message="Notifications marked as read successfully."
    )


@extend_schema(
    request=UpdateNotificationPreferencesSerializer,
    responses={
        200: SuccessResponseExampleSerializer,
        400: ErrorResponseExampleSerializer,
        500: ErrorResponseExampleSerializer,
    },
    description="Update notification preferences.",
    tags=["Notifications"],
)
@api_view(["PUT"])
@permission_classes([IsAuthenticated])
@throttle_classes([UserRateThrottle])
def update_notification_preferences(request: Request) -> Response:
    serializer = UpdateNotificationPreferencesSerializer(
        data=request.data, context={"user_id": request.user.id}
    )
    serializer.is_valid(raise_exception=True)

    update_preferences_rule = get_update_notification_preferences_rule()
    preferences = update_preferences_rule(
        UpdateNotificationPreferencesDTO(**serializer.validated_data)
    )

    return StandardResponse.success(
        data=asdict(preferences),
        message="Notification preferences updated successfully.",
    )


@extend_schema(
    responses={
        200: SuccessResponseExampleSerializer,
        400: ErrorResponseExampleSerializer,
        500: ErrorResponseExampleSerializer,
    },
    description="Get user notification preferences.",
    tags=["Notifications"],
)
@api_view(["GET"])
@permission_classes([IsAuthenticated])
@throttle_classes([UserRateThrottle])
def get_notification_preferences(request: Request) -> Response:
    preferences_rule = get_notification_preferences_rule()
    preferences = preferences_rule(request.user.id)

    return StandardResponse.success(
        data=asdict(preferences),
        message="Notification preferences fetched successfully.",
    )


@extend_schema(
    request=None,
    responses=None,
    description="Create an SSE connection.",
    tags=["Notifications"],
)
@csrf_exempt
@api_view(["POST"])
@permission_classes([IsAuthenticated])
@throttle_classes([UserRateThrottle])
def notifications_stream_view(request):
    return events(request)
