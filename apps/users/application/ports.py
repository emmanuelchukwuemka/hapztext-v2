from abc import ABC, abstractmethod
from typing import Any, List, Tuple

from ..domain.entities import User as DomainUser
from ..domain.entities import UserFollowing as DomainUserFollowing
from ..domain.entities import UserProfile as DomainUserProfile


class UserRepositoryInterface(ABC):
    @abstractmethod
    def create(self, user: DomainUser) -> DomainUser:
        pass

    @abstractmethod
    def update(self, user: DomainUser, **kwargs) -> DomainUser:
        pass

    @abstractmethod
    def find_by_email(self, email: str, raw: bool = False) -> DomainUser:
        pass

    @abstractmethod
    def find_by_id(self, id: str, raw: bool = False) -> DomainUser:
        pass


class UserProfileRepositoryInterface(ABC):
    @abstractmethod
    def create(self, user_profile: DomainUserProfile) -> DomainUserProfile:
        pass

    @abstractmethod
    def update(self, user_profile: DomainUserProfile, **kwargs) -> DomainUserProfile:
        pass

    @abstractmethod
    def find_by_user(self, user_id: str, raw: bool = False) -> DomainUserProfile:
        pass

    @abstractmethod
    def profiles_list(self, page: int, page_size: int) -> Tuple[List[Any], str, str]:
        pass


class UserFollowingRepositoryInterface(ABC):
    @abstractmethod
    def create(self, user_following: DomainUserFollowing) -> DomainUserFollowing:
        pass

    @abstractmethod
    def find_by_id(self, request_id: str) -> DomainUserFollowing | None:
        pass

    @abstractmethod
    def find_existing_request(
        self, follower_id: str, following_id: str
    ) -> DomainUserFollowing | None:
        pass

    @abstractmethod
    def update_status(self, request_id: str, status: str) -> DomainUserFollowing:
        pass

    @abstractmethod
    def get_received_requests(
        self, user_id: str, page: int, page_size: int, status: str = None
    ) -> Tuple[List[DomainUserFollowing], str, str]:
        pass

    @abstractmethod
    def get_sent_requests(
        self, user_id: str, page: int, page_size: int, status: str = None
    ) -> Tuple[List[DomainUserFollowing], str, str]:
        pass

    @abstractmethod
    def get_mutual_followers(
        self, user_id: str, page: int, page_size: int
    ) -> Tuple[List[Any], str, str]:
        pass
