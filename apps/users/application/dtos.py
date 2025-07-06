from dataclasses import dataclass
from datetime import date, datetime
from typing import List


@dataclass
class CreateUserDTO:
    email: str
    username: str
    password: str
    password_confirm: str


@dataclass
class UserDetailDTO:
    id: str
    username: str | None = None


@dataclass
class UserResponseDTO(UserDetailDTO):
    email: str = None
    username: str = None
    is_email_verified: bool = None
    created_at: datetime = None
    updated_at: datetime = None


@dataclass
class UserProfileDetailDTO:
    user_id: str
    birth_date: date | None = None
    ethnicity: str | None = None
    relationship_status: str | None = None
    first_name: str | None = None
    last_name: str | None = None
    bio: str | None = None
    occupation: str | None = None
    profile_picture: str | None = None
    height: float | None = None
    weight: float | None = None




@dataclass
class UserProfileResponseDTO(UserProfileDetailDTO):
    id: str = None
    following_ids: List = None
    follower_ids: List = None
    created_at: datetime = None
    updated_at: datetime = None


@dataclass
class UserProfileListDTO:
    page: int
    page_size: int


@dataclass
class PaginatedUserProfileListResponseDTO:
    result: List[UserProfileResponseDTO]
    previous_profiles_data: str | None = None
    next_profiles_data: str | None = None


@dataclass
class FollowUserDTO:
    follower_id: str
    following_id: str


@dataclass
class UserFollowingResponseDTO:
    id: str
    follower_id: str
    following_id: str
    created_at: datetime
