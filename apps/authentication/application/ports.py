from abc import ABC, abstractmethod
from typing import Any, Dict

from ..domain.entities import OTPCode
from ..domain.enums import OTPCodePurpose


class PasswordServiceInterface(ABC):
    @abstractmethod
    def hash(self, password: str) -> str:
        pass

    @abstractmethod
    def check(self, raw_password: str, hashed_password: str) -> bool:
        pass

    @abstractmethod
    def validate(self, password: str, password_confirm: str) -> None:
        pass


class OTPCodeRepositoryInterface(ABC):
    @abstractmethod
    def create(self, otp_code: OTPCode) -> OTPCode:
        pass

    @abstractmethod
    def find_by_code(self, code: str) -> OTPCode | None:
        pass

    @abstractmethod
    def has_valid_code(self, user_id: str, purpose: OTPCodePurpose) -> bool:
        pass


class EmailServiceInterface(ABC):
    @abstractmethod
    def send_otp_email(
        self, email: str, otp_code: OTPCode, purpose: OTPCodePurpose
    ) -> None:
        pass


class AuthenticationServiceInterface(ABC):
    @abstractmethod
    def generate_auth_tokens(self, user: Any) -> Dict[str, str]:
        pass

    @abstractmethod
    def verify_auth_token(self, auth_token: str) -> bool:
        pass

    @abstractmethod
    def invalidate_auth_token(self, auth_token: str) -> None:
        pass
