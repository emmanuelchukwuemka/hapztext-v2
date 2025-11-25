"""
Calls View
"""

from drf_spectacular.utils import extend_schema
from rest_framework.decorators import api_view, permission_classes, throttle_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.throttling import UserRateThrottle
from rest_framework.response import Response
from rest_framework.request import Request

from apps.infrastructure.calls.service import CallRecordService
from apps.infrastructure.calls.serializer import CallCreateSerializer
from apps.presentation.serializers.examples import (
    SuccessResponseExampleSerializer,
    ErrorResponseExampleSerializer,
)
from apps.infrastructure.calls.responses import CallCreateRequestExample


@extend_schema(
    request=CallCreateSerializer,
    responses={
        201: SuccessResponseExampleSerializer,
        500: ErrorResponseExampleSerializer,
        400: ErrorResponseExampleSerializer,
        401: ErrorResponseExampleSerializer,
    },
    description="Create a new Call.",
    tags=["Calls"],
    examples=[CallCreateRequestExample],
)
@api_view(["POST"])
@permission_classes([IsAuthenticated])
@throttle_classes([UserRateThrottle])
def create_new_call(request: Request) -> Response:
    """
    Creates new call
    """
    return CallRecordService.create_call(request=request)
