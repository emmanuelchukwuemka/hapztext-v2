from dataclasses import dataclass, field
from datetime import date, datetime

from .value_objects import Ethnicity, FollowRequestStatus, RelationshipStatus, Gender


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
    username: str = ""
    birth_date: date = field(default_factory=lambda: date(1900, 1, 1))
    ethnicity: str = "prefer_not_say"
    relationship_status: str = "prefer_not_say"
    gender: str = "prefer_not_say"
    id: str | None = None
    first_name: str = ""
    last_name: str = ""
    bio: str = ""
    occupation: str = ""
    profile_picture: str | None = None
    cover_picture: str | None = None
    location: str | None = None
    height: float = 0.00
    weight: float = 0.00
    created_at: datetime | None = None
    updated_at: datetime | None = None

    def __post_init__(self) -> None:
        self.ethnicity = Ethnicity(self.ethnicity).value
        self.relationship_status = RelationshipStatus(self.relationship_status).value
        self.gender = Gender(self.gender).value


@dataclass
class UserFollowing:
    follower_id: str
    following_id: str
    id: str | None = None
    status: str = "pending"
    created_at: datetime | None = None
    updated_at: datetime | None = None


@dataclass
class UserSearchResult:
    id: str | None
    email: str
    username: str
    is_email_verified: bool = False
    is_active: bool = True
    follower_count: int = 0
    following_count: int = 0
    mention_count: int = 0
    profile_picture: str | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None
