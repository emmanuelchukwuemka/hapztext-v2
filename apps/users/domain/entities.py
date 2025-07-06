from dataclasses import dataclass, field
from datetime import UTC, date, datetime
from typing import List

import nanoid

from .value_objects import Ethnicity, RelationshipStatus


@dataclass
class User:
    email: str
    username: str
    hashed_password: str = field(repr=False)
    is_email_verified: bool = False
    is_active: bool = True
    id: str = field(default_factory=lambda: nanoid.generate())
    created_at: datetime = field(default_factory=lambda: datetime.now(tz=UTC))
    updated_at: datetime = field(default_factory=lambda: datetime.now(tz=UTC))


@dataclass
class UserProfile:
    user_id: str
    birth_date: date
    ethnicity: Ethnicity
    relationship_status: RelationshipStatus
    first_name: str = ""
    last_name: str = ""
    bio: str = ""
    occupation: str = ""
    profile_picture: str | None = None
    height: float = 0.00
    weight: float = 0.00
    id: str = field(default_factory=lambda: nanoid.generate())
    following_ids: List = field(default_factory=list)
    follower_ids: List = field(default_factory=list)
    created_at: datetime = field(default_factory=lambda: datetime.now(tz=UTC))
    updated_at: datetime = field(default_factory=lambda: datetime.now(tz=UTC))


@dataclass
class UserFollowing:
    follower_id: str
    following_id: str
    id: str = field(default_factory=lambda: nanoid.generate())
    created_at: datetime = field(default_factory=lambda: datetime.now(tz=UTC))
