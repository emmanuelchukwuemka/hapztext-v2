from dataclasses import dataclass, field
from datetime import date, datetime

from .value_objects import Ethnicity, FollowRequestStatus, RelationshipStatus


@dataclass
class User:
    email: str
    username: str
    hashed_password: str = field(repr=False)
    id: str | None = None
    is_email_verified: bool = False
    is_active: bool = True
    created_at: datetime | None = None
    updated_at: datetime | None = None


@dataclass
class UserProfile:
    user_id: str
    birth_date: date
    ethnicity: str
    relationship_status: str
    id: str | None = None
    first_name: str = ""
    last_name: str = ""
    bio: str = ""
    occupation: str = ""
    profile_picture: str | None = None
    location: str | None = None
    height: float = 0.00
    weight: float = 0.00
    created_at: datetime | None = None
    updated_at: datetime | None = None

    def __post_init__(self) -> None:
        self.ethnicity = Ethnicity(self.ethnicity).value
        self.relationship_status = RelationshipStatus(self.relationship_status).value


@dataclass
class UserFollowing:
    follower_id: str
    following_id: str
    status: str = "pending"
    id: str | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None

    def __post_init__(self) -> None:
        self.status = FollowRequestStatus(self.status).value

    def is_pending(self) -> bool:
        return self.status == "pending"

    def is_accepted(self) -> bool:
        return self.status == "accepted"

    def is_declined(self) -> bool:
        return self.status == "declined"
