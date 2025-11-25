"""
Calls Enums
"""

from typing import List
from enum import Enum


class CallStatusEnum(str, Enum):
    """
    CallStatusEnum
    """

    ENDED = "ended"
    RINGING = "ringing"

    @classmethod
    def choices(cls) -> List[str]:
        """
        Returns a list of all values
        """
        return [c.value for c in cls]


class CallTypeEnum(str, Enum):
    """
    CallTypeEnum
    """

    VOICE = "voice"
    VIDEO = "video"

    @classmethod
    def choices(cls) -> List[str]:
        """
        Returns a list of all values
        """
        return [c.value for c in cls]
