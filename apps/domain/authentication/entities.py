from dataclasses import dataclass
from datetime import UTC, datetime

from .value_objects import Purpose


@dataclass
class OTPCode:
    user_id: str
    purpose: str
    code: str | None = None
    id: str | None = None
    created_at: datetime | None = None
    expires_at: datetime | None = None

    def __post_init__(self) -> None:
        self.purpose = Purpose(self.purpose).value

    def is_expired(self) -> bool:
        return self.expires_at < datetime.now(tz=UTC)
