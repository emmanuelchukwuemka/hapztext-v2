from abc import ABC, abstractmethod
from typing import Any, List, Tuple

from ..domain.entities import Post


class PostRepositoryInterface(ABC):
    @abstractmethod
    def create(self, post: Post) -> Post:
        pass

    @abstractmethod
    def posts_list(self, page: int, page_size: int) -> Tuple[List[Any], str, str]:
        pass
