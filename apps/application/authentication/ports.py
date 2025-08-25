from abc import ABC, abstractmethod
from typing import Any, Dict

from apps.domain.authentication.entities import OTPCode
from apps.domain.authentication.enums import OTPCodePurpose


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

    @abstractmethod
    def delete_by_code(self, code: str) -> None:
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
