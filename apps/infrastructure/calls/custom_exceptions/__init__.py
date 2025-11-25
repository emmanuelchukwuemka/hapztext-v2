"""
Call Participani init
"""

import apps.domain.notifications.enums


from apps.infrastructure.calls.custom_exceptions.call_participants_exc import (
    CUstomCallParticipantForeignKeyError,
)
from apps.infrastructure.calls.custom_exceptions.webrct_exceptions import (
    CustomWebRTCBaseError,
    CustomWebRTCMediaStateError,
)
