from abc import ABC, abstractmethod
from typing import Any, List, Tuple

from apps.domain.posts.entities import Post


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
