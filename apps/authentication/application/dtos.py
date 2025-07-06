from dataclasses import dataclass
from typing import Any, Dict


@dataclass
class EmailOTPRequestDTO:
    email: str
    purpose: str
    user: Any = None


@dataclass
class VerifyEmailDTO:
    email: str
    otp_code: str


@dataclass
class LoginDTO:
    email: str
    password: str


@dataclass
class LoginResponseDTO:
    id: str
    email: str
    username: str
    tokens: Dict[str, str]


@dataclass
class LogoutDTO:
    auth_token: str
    request: Any = None


@dataclass
class ResetPasswordDTO:
    new_password: str
    new_password_confirm: str
    otp_code: str
