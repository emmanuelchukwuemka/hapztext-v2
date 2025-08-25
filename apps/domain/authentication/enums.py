from enum import StrEnum
from typing import List, Tuple


class OTPCodePurpose(StrEnum):
    EMAIL_VERIFICATION = "email_verification"
    PASSWORD_RESET = "password_reset"

    @classmethod
    def choices(cls) -> List[Tuple[str]]:
        return [(tag.value, tag.name) for tag in cls]

    @classmethod
    def values(cls) -> List[str]:
        return [tag.value for tag in cls]
