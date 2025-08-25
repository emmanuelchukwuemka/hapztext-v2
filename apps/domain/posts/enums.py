from enum import StrEnum
from typing import List, Tuple


class PostFormat(StrEnum):
    TEXT = "text"
    IMAGE = "image"
    AUDIO = "audio"
    VIDEO = "video"

    @classmethod
    def choices(cls) -> List[Tuple[str]]:
        return [(tag.value, tag.name) for tag in cls]

    @classmethod
    def values(cls) -> List[str]:
        return [tag.value for tag in cls]
