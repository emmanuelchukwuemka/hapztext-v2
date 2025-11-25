"""
WebRTC Exceptions
"""


class CustomWebRTCBaseError(Exception):
    """
    CustomWebRTCBaseError
    """

    def __init__(self, message: str = "An Exception Occurred") -> None:
        """
        Constructor
        """
        super().__init__(message)


class CustomWebRTCMediaStateError(Exception):
    """
    CustomWebRTCMediaStateError
    """

    def __init__(self, message: str = "media state Error") -> None:
        """
        Constructor
        """
        super().__init__(message)
