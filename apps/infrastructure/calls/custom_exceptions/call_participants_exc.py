"""
Call Participants Error
"""


class CUstomCallParticipantForeignKeyError(Exception):
    """
    CUstomCallParticipantForeignKeyError
    """

    def __init__(self, message: str = "Call Participant does not exist") -> None:
        """
        Constructor
        """
        super().__init__(message)
