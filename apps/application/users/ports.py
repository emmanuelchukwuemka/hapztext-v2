from typing import Any, List, Protocol, Tuple

from apps.domain.users.entities import User, UserFollowing, UserProfile


class UserRepositoryInterface(Protocol):
    def create(self, user: User) -> User: ...

    def update(self, user: User, **kwargs) -> User: ...

    def find_by_email(self, email: str, raw: bool = False) -> User: ...

    def find_by_id(self, id: str, raw: bool = False) -> User: ...


class UserProfileRepositoryInterface(Protocol):
    def create(self, user_profile: UserProfile) -> UserProfile: ...

    def update(self, user_profile: UserProfile, **kwargs) -> UserProfile: ...

    def find_by_user(self, user_id: str, raw: bool = False) -> UserProfile: ...

    def profiles_list(
        self, page: int, page_size: int
    ) -> Tuple[List[Any], str, str]: ...

    def get_followers(
        self, user_id: str, page: int, page_size: int
    ) -> Tuple[List[Any], str, str]: ...

    def get_followings(
        self, user_id: str, page: int, page_size: int
    ) -> Tuple[List[Any], str, str]: ...


class UserFollowingRepositoryInterface(Protocol):
    def create(self, user_following: UserFollowing) -> UserFollowing: ...

    def find_by_id(self, request_id: str) -> UserFollowing | None: ...

    def find_existing_request(
        self, follower_id: str, following_id: str
    ) -> UserFollowing | None: ...

    def update_status(self, request_id: str, status: str) -> UserFollowing: ...

    def get_received_requests(
        self, user_id: str, page: int, page_size: int, status: str | None = None
    ) -> Tuple[List[UserFollowing], str, str]: ...

    def get_sent_requests(
        self, user_id: str, page: int, page_size: int, status: str | None = None
    ) -> Tuple[List[UserFollowing], str, str]: ...

    def get_mutual_followers(
        self, user_id: str, page: int, page_size: int
    ) -> Tuple[List[Any], str, str]: ...
