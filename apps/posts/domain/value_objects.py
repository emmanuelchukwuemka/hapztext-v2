from dataclasses import dataclass

from .enums import PostFormat as PostFormatEnum


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
