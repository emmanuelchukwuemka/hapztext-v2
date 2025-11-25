"""
Calls DTOs
"""

from typing import List, Optional
from dataclasses import dataclass
from datetime import date, datetime

from rest_framework.exceptions import ValidationError
from rest_framework import status

from apps.infrastructure.calls.models.call_enums import CallStatusEnum, CallTypeEnum


def validate_participant_list(
    participants: List[str] | None = None, name: str = "participant_ids"
):
    """
    Validate participant list
    """
    if participants is not None:
        if not isinstance(participants, list):
            raise ValidationError(
                detail=f"{name} must be of type Array/List",
                code=status.HTTP_400_BAD_REQUEST,
            )
        for element in participants:
            if not isinstance(element, str):
                raise ValidationError(
                    detail=f"{name} must contain strings only",
                    code=status.HTTP_400_BAD_REQUEST,
                )
            if element.strip() == "" or len(element) < 21 or len(element) > 21:
                raise ValidationError(
                    detail=f"each value in {name} must have length 21",
                    code=status.HTTP_400_BAD_REQUEST,
                )


@dataclass
class CallBaseDto:
    """
    CallBaseDto
    """

    id: str
    caller_id: str
    initiator_id: str
    status: CallStatusEnum
    created_at: datetime
    updated_at: datetime
    started_at: datetime | None
    ended_at: datetime | None


#################### create ####################
@dataclass
class NewCallRequestDto:
    """
    NewCallRequestDto
    """

    call_type: str | None = "voice"
    title: str | None = "New Call"
    participant_ids: List[str] | None = None

    def validate(self) -> None:
        """
        Validates all fields
        """

        if self.call_type not in CallTypeEnum.choices():
            raise ValidationError(
                detail=f"call_type must be one of {CallTypeEnum.choices()}",
                code=status.HTTP_400_BAD_REQUEST,
            )
        if self.title and len(self.title.strip()) > 100:
            raise ValidationError(
                detail="title must have length less than 100",
                code=status.HTTP_400_BAD_REQUEST,
            )
        validate_participant_list(participants=self.participant_ids)


#################### join ####################
@dataclass
class JoinCallRequestDto:
    """
    Join Call RequestDto
    """

    call_id: str

    def validate(self) -> None:
        """
        Validates all fields
        """
        if (
            self.call_id.strip() == ""
            or len(self.call_id) < 21
            or len(self.call_id) > 21
        ):
            raise ValidationError(
                detail="call_id must have length 21",
                code=status.HTTP_400_BAD_REQUEST,
            )


#################### end ####################
@dataclass
class EndCallRequestDto:
    """
    End Call RequestDto
    """

    ended_by: str
    call_id: str

    def validate(self) -> None:
        """
        Validates all fields
        """
        if (
            self.call_id.strip() == ""
            or len(self.call_id) < 21
            or len(self.call_id) > 21
        ):
            raise ValidationError(
                detail="call_id must have length 21",
                code=status.HTTP_400_BAD_REQUEST,
            )
        if (
            self.ended_by.strip() == ""
            or len(self.ended_by) < 21
            or len(self.ended_by) > 21
        ):
            raise ValidationError(
                detail="ended_by must have length 21",
                code=status.HTTP_400_BAD_REQUEST,
            )


########################## invite ##################
@dataclass
class InviteCallRequestDto:
    """
    InviteCallRequestDto
    """

    call_id: str
    invitee_ids: List[str]

    def validate(self) -> None:
        """
        Validate fields
        """
        if (
            self.call_id.strip() == ""
            or len(self.call_id) < 21
            or len(self.call_id) > 21
        ):
            raise ValidationError(
                detail="call_id must have length 21",
                code=status.HTTP_400_BAD_REQUEST,
            )
        if self.invitee_ids is None:
            raise ValidationError(
                detail="invitee_ids must be provided",
                code=status.HTTP_400_BAD_REQUEST,
            )
        validate_participant_list(participants=self.invitee_ids, name="invitee_ids")


#################### update ####################
@dataclass
class UpdateCallRequestDto:
    """
    UpdateCallRequestDto
    """

    status: CallStatusEnum
    started_at: date | None = None


#################### fetch all ####################
@dataclass
class FetchCallHistoryQueryDto:
    """
    FetchCallHistory
    """

    page: int | str = 1
    limit: int | str = 20

    def validate(self) -> None:
        """
        Validate all fields
        """
        if isinstance(self.page, int) and self.page < 1:
            raise ValidationError(
                detail="page must be greater than zero(0)",
                code=status.HTTP_400_BAD_REQUEST,
            )
        if isinstance(self.page, str):
            try:
                page = int(self.page)
                if page < 1:
                    raise ValidationError(
                        detail="page must be greater than zero(0)",
                        code=status.HTTP_400_BAD_REQUEST,
                    )
                self.page = page
            except ValueError as exc:
                raise ValidationError(
                    detail="page must be an integer or a digit",
                    code=status.HTTP_400_BAD_REQUEST,
                ) from exc
        if isinstance(self.limit, str):
            try:
                limit = int(self.limit)
                if limit < 1:
                    raise ValidationError(
                        detail="limit must be greater than zero(0)",
                        code=status.HTTP_400_BAD_REQUEST,
                    )
                self.limit = limit
            except ValueError as exc:
                raise ValidationError(
                    detail="limit must be an integer or a digit",
                    code=status.HTTP_400_BAD_REQUEST,
                ) from exc
        else:
            if 1 > self.limit or self.limit > 20:
                self.limit = 20


@dataclass
class FetchCallHistoryResponseDto:
    """
    FetchCallHistory
    """

    call_history = List[CallBaseDto]


@dataclass
class GetCallHistoryRequestDto:
    """
    GetCallHistoryRequestDto
    """

    page: int = 1
    limit: int = 20
    call_type: Optional[str] = None
    status: Optional[str] = None
    date_from: Optional[str] = None
    date_to: Optional[str] = None

    def validate(self):
        """
        Validate
        """

        if self.page < 0:
            self.page = 1
        if self.limit < 0 or self.limit > 20:
            self.limit = 20
        if self.call_type and self.call_type not in ["voice", "video"]:
            raise ValidationError(
                detail="call_type must be one of voice or video",
                code=status.HTTP_400_BAD_REQUEST,
            )


@dataclass
class UpdateCallTitleRequestDto:
    """
    UpdateCallTitleRequestDto
    """

    new_title: str

    def validate(self) -> None:
        """
        Validate fields
        """
        if (
            self.new_title.strip() == ""
            or len(self.new_title) > 100
            or len(self.new_title) < 3
        ):
            raise ValidationError(
                detail="new_title must have length greater than 3 and less than 100"
            )
