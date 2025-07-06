from dataclasses import asdict

from django.db import transaction
from drf_spectacular.utils import extend_schema
from rest_framework.decorators import api_view, permission_classes, throttle_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.request import Request
from rest_framework.throttling import AnonRateThrottle, UserRateThrottle

from core.presentation.responses import StandardResponse
from core.presentation.serializers import (
    ErrorResponseExampleSerializer,
    SuccessResponseExampleSerializer,
)

from ...users.application.dtos import CreateUserDTO
from ...users.infrastructure.repositories import DjangoUserRepository
from ..application.dtos import (
    EmailOTPRequestDTO,
    LoginDTO,
    LogoutDTO,
    ResetPasswordDTO,
    VerifyEmailDTO,
)
from ..application.rules import (
    EmailOTPRequestRule,
    LoginRule,
    LogoutRule,
    RegisterRule,
    ResetPasswordRule,
    VerifyEmailRule,
)
from ..infrastructure.repositories import DjangoOTPCodeRepository
from ..infrastructure.services import (
    DjangoEmailServiceAdapter,
    DjangoPasswordServiceAdapter,
    KnoxAuthenticationServiceAdapter,
)
from .serializers import (
    CreateUserSerializer,
    LoginSerializer,
    LogoutSerializer,
    PasswordResetConfirmSerializer,
    PasswordResetRequestSerializer,
    VerifyEmailSerializer,
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
    user_repository = DjangoUserRepository()
    password_service = DjangoPasswordServiceAdapter()
    register_rule = RegisterRule(
        user_repository=user_repository, password_service=password_service
    )

    serializer = CreateUserSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    user = register_rule.execute(CreateUserDTO(**serializer.validated_data))

    otp_code_repository = DjangoOTPCodeRepository()
    email_service = DjangoEmailServiceAdapter()
    verification_request_rule = EmailOTPRequestRule(
        user_repository=user_repository,
        otp_code_repository=otp_code_repository,
        email_service=email_service,
    )
    verification_request_rule.execute(
        EmailOTPRequestDTO(user.email, "email_verification", user)
    )

    return StandardResponse.created(
        data=asdict(user),
        message="Registration successful. An OTP code has been sent to your email for verification.",
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
    user_repository = DjangoUserRepository()
    otp_code_repository = DjangoOTPCodeRepository()
    verify_email_rule = VerifyEmailRule(
        user_repository=user_repository, otp_code_repository=otp_code_repository
    )

    serializer = VerifyEmailSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    verify_email_rule.execute(VerifyEmailDTO(**serializer.validated_data))

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
    user_repository = DjangoUserRepository()
    password_service = DjangoPasswordServiceAdapter()
    authentication_service = KnoxAuthenticationServiceAdapter()
    login_rule = LoginRule(
        user_repository=user_repository,
        password_service=password_service,
        authentication_service=authentication_service,
    )

    serializer = LoginSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    login_data = login_rule.execute(LoginDTO(**serializer.validated_data))

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
    authentication_service = KnoxAuthenticationServiceAdapter()
    logout_rule = LogoutRule(authentication_service=authentication_service)

    serializer = LogoutSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    logout_rule.execute(LogoutDTO(request=request, **serializer.validated_data))

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
    user_repository = DjangoUserRepository()
    otp_code_repository = DjangoOTPCodeRepository()
    email_service = DjangoEmailServiceAdapter()
    reset_request_rule = EmailOTPRequestRule(
        user_repository=user_repository,
        otp_code_repository=otp_code_repository,
        email_service=email_service,
    )

    serializer = PasswordResetRequestSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    reset_request_rule.execute(EmailOTPRequestDTO(**serializer.validated_data))

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
    otp_code_repository = DjangoOTPCodeRepository()
    user_repository = DjangoUserRepository()
    password_service = DjangoPasswordServiceAdapter()
    reset_rule = ResetPasswordRule(
        user_repository=user_repository,
        otp_code_repository=otp_code_repository,
        password_service=password_service,
    )

    serializer = PasswordResetConfirmSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    reset_rule.execute(ResetPasswordDTO(**serializer.validated_data))

    return StandardResponse.success(message="Password reset successful.")
