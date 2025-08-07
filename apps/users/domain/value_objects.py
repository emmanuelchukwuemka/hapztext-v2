from dataclasses import dataclass

from .enums import Ethnicity as EthnicityEnum
from .enums import FollowRequestStatus as FollowRequestStatusEnum
from .enums import RelationshipStatus as RelationshipStatusEnum


@dataclass(frozen=True)
class Ethnicity:
    value: str

    def __post_init__(self):
        if not self._is_valid():
            raise ValueError(
                f"Invalid Ethnicity. Select a value from {EthnicityEnum.values()}."
            )

    def _is_valid(self) -> bool:
        return self.value in EthnicityEnum.values()


@dataclass(frozen=True)
class RelationshipStatus:
    value: str

    def __post_init__(self):
        if not self._is_valid():
            raise ValueError(
                f"Invalid RelationshipStatus. Select a value from {RelationshipStatusEnum.values()}."
            )

    def _is_valid(self) -> bool:
        return self.value in RelationshipStatusEnum.values()


@dataclass(frozen=True)
class FollowRequestStatus:
    value: str

    def __post_init__(self):
        if not self._is_valid():
            raise ValueError(
                f"Invalid FollowRequestStatus. Select a value from {FollowRequestStatusEnum.values()}."
            )

    def _is_valid(self) -> bool:
        return self.value in FollowRequestStatusEnum.values()
