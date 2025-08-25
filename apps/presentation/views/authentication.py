from dataclasses import asdict

from django.db import transaction
from drf_spectacular.utils import extend_schema
from rest_framework.decorators import api_view, permission_classes, throttle_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.request import Request
from rest_framework.throttling import AnonRateThrottle, UserRateThrottle

from apps.application.authentication.dtos import (
    EmailOTPRequestDTO,
    LoginDTO,
    LogoutDTO,
    ResetPasswordDTO,
    VerifyEmailDTO,
)
from apps.application.users.dtos import CreateUserDTO
from apps.presentation.factory import (
    get_email_otp_request_rule,
    get_login_rule,
    get_logout_rule,
    get_register_rule,
    get_reset_password_rule,
    get_verify_email_rule,
)
from apps.presentation.responses import StandardResponse
from apps.presentation.serializers.authentication import (
    CreateUserSerializer,
    EmailVerificationRequestSerializer,
    LoginSerializer,
    LogoutSerializer,
    PasswordResetConfirmSerializer,
    PasswordResetRequestSerializer,
    VerifyEmailSerializer,
)
from apps.presentation.serializers.examples import (
    ErrorResponseExampleSerializer,
    SuccessResponseExampleSerializer,
)


@extend_schema(
    request=CreateUserSerializer,
    responses={
        201: SuccessResponseExampleSerializer,
        400: ErrorResponseExampleSerializer,
        500: ErrorResponseExampleSerializer,
    },
    description="Register a new user.",
    tags=["Authentication"],
)
@api_view(["POST"])
@permission_classes([AllowAny])
@throttle_classes([AnonRateThrottle])
@transaction.atomic
def register_user(request: Request) -> StandardResponse:
    serializer = CreateUserSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    register_rule = get_register_rule()
    user = register_rule(CreateUserDTO(**serializer.validated_data))

    verification_request_rule = get_email_otp_request_rule()
    verification_request_rule(
        EmailOTPRequestDTO(user.email, "email_verification", user)
    )

    return StandardResponse.created(
        data=asdict(user),
        message="Registration successful. An OTP code has been sent to your email for verification.",
    )


@extend_schema(
    request=EmailVerificationRequestSerializer,
    responses={
        200: SuccessResponseExampleSerializer,
        400: ErrorResponseExampleSerializer,
        500: ErrorResponseExampleSerializer,
    },
    description="Request email verification for an unverified user.",
    tags=["Authentication"],
)
@api_view(["POST"])
@permission_classes([AllowAny])
@throttle_classes([AnonRateThrottle])
def request_email_verification(request: Request):
    serializer = EmailVerificationRequestSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    verification_request_rule = get_email_otp_request_rule()
    verification_request_rule(EmailOTPRequestDTO(**serializer.validated_data))
    return StandardResponse.success(
        message="Email verification OTP code sent successfully."
    )


@extend_schema(
    request=VerifyEmailSerializer,
    responses={
        200: SuccessResponseExampleSerializer,
        400: ErrorResponseExampleSerializer,
        500: ErrorResponseExampleSerializer,
    },
    description="Verify a new user's email.",
    tags=["Authentication"],
)
@api_view(["POST"])
@permission_classes([AllowAny])
@throttle_classes([AnonRateThrottle])
def verify_email(request: Request):
    serializer = VerifyEmailSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    verify_email_rule = get_verify_email_rule()
    verify_email_rule(VerifyEmailDTO(**serializer.validated_data))

    return StandardResponse.success(message="Email verification successful.")


@extend_schema(
    request=LoginSerializer,
    responses={
        200: SuccessResponseExampleSerializer,
        400: ErrorResponseExampleSerializer,
        500: ErrorResponseExampleSerializer,
    },
    description="Login a verified user.",
    tags=["Authentication"],
)
@api_view(["POST"])
@permission_classes([AllowAny])
@throttle_classes([AnonRateThrottle])
def login_user(request: Request):
    serializer = LoginSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    login_rule = get_login_rule()
    login_data = login_rule(LoginDTO(**serializer.validated_data))

    return StandardResponse.success(
        data=asdict(login_data), message="Login successful."
    )


@extend_schema(
    request=LogoutSerializer,
    responses={
        204: SuccessResponseExampleSerializer,
        400: ErrorResponseExampleSerializer,
        500: ErrorResponseExampleSerializer,
    },
    description="Logout an authenticated user.",
    tags=["Authentication"],
)
@api_view(["POST"])
@permission_classes([IsAuthenticated])
@throttle_classes([UserRateThrottle])
def logout_user(request: Request):
    serializer = LogoutSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    logout_rule = get_logout_rule()
    logout_rule(LogoutDTO(request=request, **serializer.validated_data))

    return StandardResponse.deleted(message="Logout successful.")


@extend_schema(
    request=PasswordResetRequestSerializer,
    responses={
        200: SuccessResponseExampleSerializer,
        400: ErrorResponseExampleSerializer,
        500: ErrorResponseExampleSerializer,
    },
    description="Request password reset for a verified user.",
    tags=["Authentication"],
)
@api_view(["POST"])
@permission_classes([AllowAny])
@throttle_classes([AnonRateThrottle])
def request_password_reset(request: Request):
    serializer = PasswordResetRequestSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    reset_request_rule = get_email_otp_request_rule()
    reset_request_rule(EmailOTPRequestDTO(**serializer.validated_data))

    return StandardResponse.success(
        message="Password reset OTP code sent successfully."
    )


@extend_schema(
    request=PasswordResetConfirmSerializer,
    responses={
        200: SuccessResponseExampleSerializer,
        400: ErrorResponseExampleSerializer,
        500: ErrorResponseExampleSerializer,
    },
    description="Request password for a verified user.",
    tags=["Authentication"],
)
@api_view(["POST"])
@permission_classes([AllowAny])
@throttle_classes([AnonRateThrottle])
def reset_password(request: Request):
    serializer = PasswordResetConfirmSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    reset_rule = get_reset_password_rule()
    reset_rule(ResetPasswordDTO(**serializer.validated_data))

    return StandardResponse.success(message="Password reset successful.")
