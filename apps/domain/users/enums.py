from enum import StrEnum
from typing import List, Tuple


class Ethnicity(StrEnum):
    AFRICAN = "african"
    ASIAN = "asian"
    CAUCASIAN = "caucasian"
    HISPANIC = "hispanic"
    MIDDLE_EASTERN = "middle_eastern"
    MIXED = "mixed"
    NATIVE_AMERICAN = "native_american"
    PACIFIC_ISLANDER = "pacific_islander"
    PREFER_NOT_SAY = "prefer_not_say"
    OTHER = "other"

    @classmethod
    def choices(cls) -> List[Tuple[str]]:
        return [(tag.value, tag.name) for tag in cls]

    @classmethod
    def values(cls) -> List[str]:
        return [tag.value for tag in cls]


class RelationshipStatus(StrEnum):
    SINGLE = "single"
    IN_RELATIONSHIP = "in_relationship"
    ENGAGED = "engaged"
    MARRIED = "married"
    DIVORCED = "divorced"
    WIDOWED = "widowed"
    COMPLICATED = "complicated"
    PREFER_NOT_SAY = "prefer_not_say"

    @classmethod
    def choices(cls) -> List[Tuple[str]]:
        return [(tag.value, tag.name) for tag in cls]

    @classmethod
    def values(cls) -> List[str]:
        return [tag.value for tag in cls]


class FollowRequestStatus(StrEnum):
    PENDING = "pending"
    ACCEPTED = "accepted"
    DECLINED = "declined"

    @classmethod
    def choices(cls) -> List[Tuple[str]]:
        return [(tag.value, tag.name) for tag in cls]

    @classmethod
    def values(cls) -> List[str]:
        return [tag.value for tag in cls]
