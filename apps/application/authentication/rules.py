from typing import Any, Callable

from apps.application.users.dtos import CreateUserDTO, UserResponseDTO
from apps.application.users.ports import UserRepositoryInterface
from apps.domain.authentication.entities import OTPCode
from apps.domain.authentication.value_objects import Purpose
from apps.domain.users.entities import User

from .dtos import (
    EmailOTPRequestDTO,
    LoginDTO,
    LoginResponseDTO,
    LogoutDTO,
    ResetPasswordDTO,
    VerifyEmailDTO,
)
from .ports import (
    AuthenticationServiceInterface,
    EmailServiceInterface,
    OTPCodeRepositoryInterface,
)


class RegisterRule:
    def __init__(
        self,
        user_repository: UserRepositoryInterface,
        validate_password: Callable[[Any], str],
        hash_password: Callable[[Any], str],
    ) -> None:
        self.user_repository = user_repository
        self.validate_password = validate_password
        self.hash_password = hash_password

    def __call__(self, dto: CreateUserDTO) -> UserResponseDTO:
        self.validate_password(dto.password, dto.password_confirm)
        hashed_password = self.hash_password(dto.password)

        user = User(
            email=dto.email, username=dto.username, hashed_password=hashed_password
        )

        created_user = self.user_repository.create(user)
        return UserResponseDTO(
            id=created_user.id,
            email=created_user.email,
            username=created_user.username,
            is_email_verified=created_user.is_email_verified,
            created_at=created_user.created_at,
            updated_at=created_user.updated_at,
        )


class EmailOTPRequestRule:
    def __init__(
        self,
        user_repository: UserRepositoryInterface,
        otp_code_repository: OTPCodeRepositoryInterface,
        email_service: EmailServiceInterface,
    ) -> None:
        self.user_repository = user_repository
        self.otp_code_repository = otp_code_repository
        self.email_service = email_service

    def __call__(self, dto: EmailOTPRequestDTO) -> None:
        user = (
            self.user_repository.find_by_email(dto.email) if not dto.user else dto.user
        )
        if not user:
            raise ValueError(f"User with email '{dto.email}' does not exist.")
        elif dto.purpose == "email_verification" and user.is_email_verified:
            raise ValueError(f"User with email '{dto.email}' is already verified.")
        elif dto.purpose == "password_reset" and not user.is_email_verified:
            raise ValueError(f"User with email {dto.email} is not verified.")

        Purpose(dto.purpose)

        if self.otp_code_repository.has_valid_code(user.id, dto.purpose):
            raise ValueError(
                "Valid OTPCode for this user already exists. Check your email or try again in 10 minutes"
            )

        otp_code = OTPCode(user_id=user.id, purpose=dto.purpose)

        otp_code = self.otp_code_repository.create(otp_code)

        self.email_service.send_otp_email(user.email, otp_code, dto.purpose)


class VerifyEmailRule:
    def __init__(
        self,
        user_repository: UserRepositoryInterface,
        otp_code_repository: OTPCodeRepositoryInterface,
    ) -> None:
        self.user_repository = user_repository
        self.otp_code_repository = otp_code_repository

    def __call__(self, dto: VerifyEmailDTO) -> UserResponseDTO:
        user = self.user_repository.find_by_email(dto.email, raw=True)
        if not user:
            raise ValueError(f"User with email '{dto.email}' does not exist.")
        elif user.is_email_verified:
            raise ValueError(f"User with email '{dto.email}' is already verified.")

        otp_code = self.otp_code_repository.find_by_code(dto.otp_code)
        if not otp_code or otp_code.is_expired():
            raise ValueError("OTP code is invalid or expired.")

        updated_user = self.user_repository.update(user, is_email_verified=True)

        self.otp_code_repository.delete_by_code(dto.otp_code)

        return UserResponseDTO(
            id=updated_user.id,
            email=updated_user.email,
            username=updated_user.username,
            is_email_verified=updated_user.is_email_verified,
            created_at=updated_user.created_at,
            updated_at=updated_user.updated_at,
        )


class LoginRule:
    def __init__(
        self,
        user_repository: UserRepositoryInterface,
        check_password: Callable[[Any], str],
        authentication_service: AuthenticationServiceInterface,
    ) -> None:
        self.user_repository = user_repository
        self.check_password = check_password
        self.authentication_service = authentication_service

    def __call__(self, dto: LoginDTO) -> LoginResponseDTO:
        user = self.user_repository.find_by_email(dto.email, raw=True)
        if not user or not self.check_password(dto.password, user.password):
            raise ValueError("Login credentials are invalid.")
        elif not user.is_email_verified:
            raise ValueError(f"User with email '{dto.email}' is not verified.")

        auth_tokens = self.authentication_service.generate_auth_tokens(user)
        return LoginResponseDTO(
            id=user.id, email=user.email, username=user.username, tokens=auth_tokens
        )


class LogoutRule:
    def __init__(
        self,
        authentication_service: AuthenticationServiceInterface,
    ) -> None:
        self.authentication_service = authentication_service

    def __call__(self, dto: LogoutDTO) -> None:
        if not self.authentication_service.verify_auth_token(dto.auth_token):
            raise ValueError("Authentication token is invalid.")

        self.authentication_service.invalidate_auth_token(dto.auth_token, dto.request)


class ResetPasswordRule:
    def __init__(
        self,
        otp_code_repository: OTPCodeRepositoryInterface,
        user_repository: UserRepositoryInterface,
        validate_password: Callable[[Any], str],
        hash_password: Callable[[Any], str],
    ) -> None:
        self.otp_code_repository = otp_code_repository
        self.user_repository = user_repository
        self.validate_password = validate_password
        self.hash_password = hash_password

    def __call__(self, dto: ResetPasswordDTO) -> None:
        otp_code = self.otp_code_repository.find_by_code(dto.otp_code)
        if not otp_code or otp_code.is_expired():
            raise ValueError("OTP code is invalid or expired.")

        user = self.user_repository.find_by_id(id=otp_code.user_id, raw=True)
        if not user:
            raise ValueError("OTP code does not have any associated user.")

        if not user.is_email_verified:
            raise ValueError(f"User with email '{user.email}' is not verified.")

        self.validate_password(dto.new_password, dto.new_password_confirm)
        hashed_password = self.hash_password(dto.new_password)

        self.otp_code_repository.delete_by_code(dto.otp_code)

        self.user_repository.update(user, password=hashed_password)
