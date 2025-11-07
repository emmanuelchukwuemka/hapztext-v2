from abc import ABC, abstractmethod
from typing import Any, Dict, List, Tuple

from apps.domain.posts.entities import Post, PostReaction, PostShare, PostTag


class PostRepositoryInterface(ABC):
    @abstractmethod
    def create(self, post: Post) -> Post:
        pass

    @abstractmethod
    def posts_list(self, page: int, page_size: int) -> Tuple[List[Any], str, str]:
        pass

    @abstractmethod
    def user_posts_list(
        self, user_id: str, page: int, page_size: int
    ) -> Tuple[List[Any], str, str]:
        pass

    @abstractmethod
    def trending_posts_list(
        self, page: int, page_size: int
    ) -> Tuple[List[Any], str, str]:
        pass

    @abstractmethod
    def popular_posts_list(
        self, page: int, page_size: int
    ) -> Tuple[List[Any], str, str]:
        pass

    @abstractmethod
    def get_scheduled_posts(self) -> List[Any]:
        pass

    @abstractmethod
    def publish_post(self, post_id: str) -> Post:
        pass

    @abstractmethod
    def delete(self, post_id: str, user_id: str) -> None:
        pass

    @abstractmethod
    def get_post_replies(
        self, post_id: str, page: int, page_size: int
    ) -> Tuple[List[Any], str | None, str | None]:
        pass

    @abstractmethod
    def find_by_id(self, post_id: str) -> Any:
        pass


class PostReactionRepositoryInterface(ABC):
    @abstractmethod
    def create_or_update(self, reaction: PostReaction) -> PostReaction:
        pass

    @abstractmethod
    def delete(self, user_id: str, post_id: str) -> None:
        pass

    @abstractmethod
    def find_user_reaction(self, user_id: str, post_id: str) -> PostReaction | None:
        pass

    @abstractmethod
    def get_post_reaction_counts(self, post_id: str) -> Dict[str, int]:
        pass

    @abstractmethod
    def get_posts_reaction_counts(
        self, post_ids: List[str]
    ) -> Dict[str, Dict[str, int]]:
        pass

    @abstractmethod
    def get_post_reactions(
        self, post_id: str, page: int, page_size: int
    ) -> Tuple[List[Any], str | None, str | None]:
        pass


class PostShareRepositoryInterface(ABC):
    @abstractmethod
    def create(self, share: PostShare) -> PostShare:
        pass

    @abstractmethod
    def get_post_share_count(self, post_id: str) -> int:
        pass

    @abstractmethod
    def get_posts_share_counts(self, post_ids: List[str]) -> Dict[str, int]:
        pass


class PostTagRepositoryInterface(ABC):
    @abstractmethod
    def create_tags(self, tags: List[PostTag]) -> List[PostTag]:
        pass

    @abstractmethod
    def get_post_tags(self, post_id: str) -> List[PostTag]:
        pass
