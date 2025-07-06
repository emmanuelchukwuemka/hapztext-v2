from dataclasses import dataclass, field
from datetime import UTC, datetime

import nanoid
import pyotp

from .value_objects import Purpose


@dataclass
class OTPCode:
    user_id: str
    purpose: Purpose
    code: str = field(
        default_factory=lambda: pyotp.TOTP(pyotp.random_base32(), digits=6).now()
    )
    id: str = field(default_factory=lambda: nanoid.generate())
    created_at: datetime = field(default_factory=lambda: datetime.now(tz=UTC))
    expires_at: datetime = field(default_factory=lambda: datetime.now(tz=UTC))

    def is_expired(self) -> bool:
        return self.expires_at < datetime.now(tz=UTC)
