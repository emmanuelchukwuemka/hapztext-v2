from abc import ABC, abstractmethod
from typing import Any, List, Tuple

from ..domain.entities import User, UserFollowing, UserProfile


class UserRepositoryInterface(ABC):
    @abstractmethod
    def create(self, user: User) -> User:
        pass

    @abstractmethod
    def update(self, user: Any, **kwargs) -> Any:
        pass

    @abstractmethod
    def find_by_email(self, email: str, raw: bool = False) -> Any:
        pass

    @abstractmethod
    def find_by_id(self, id: str, raw: bool = False) -> Any:
        pass


class UserProfileRepositoryInterface(ABC):
    @abstractmethod
    def create(self, user_profile: UserProfile) -> UserProfile:
        pass

    @abstractmethod
    def update(self, user_profile: Any, **kwargs) -> Any:
        pass

    @abstractmethod
    def find_by_user(self, user_id: str, raw: bool = False) -> Any:
        pass

    @abstractmethod
    def profiles_list(self, page: int, page_size: int) -> Tuple[List[Any], str, str]:
        pass


class UserFollowingRepositoryInterface(ABC):
    @abstractmethod
    def create(self, user_following: UserFollowing) -> UserFollowing:
        pass
