from dataclasses import dataclass

from .enums import PostFormat as PostFormatEnum
from .enums import ReactionType as ReactionTypeEnum


@dataclass(frozen=True)
class PostFormat:
    value: str

    def __post_init__(self):
        if not self._is_valid():
            raise ValueError(
                f"Invalid PostFormat. Select a value from {PostFormatEnum.values()}"
            )

    def _is_valid(self) -> bool:
        return self.value in PostFormatEnum.values()


@dataclass(frozen=True)
class ReactionType:
    value: str

    def __post_init__(self):
        if not self._is_valid():
            raise ValueError(
                f"Invalid ReactionType. Select a value from {ReactionTypeEnum.values()}"
            )

    def _is_valid(self) -> bool:
        return self.value in ReactionTypeEnum.values()
