"""
Call Record Model
"""

from functools import partial
from typing import Any, Dict

from django.db import models
from django.conf import settings
from nanoid import generate

USER = settings.AUTH_USER_MODEL

CUSTOM_ALPHABET = (
    "0123456789" "ABCDEFGHIJKLMNOPQRSTUVWXYZ" "abcdefghijklmnopqrstuvwxyz" "_"
)


class CallRecordModel(models.Model):
    """
    Stores the call record and outcome of voice/video calls (one-on-one or group).
    """

    class CallStatus(models.TextChoices):
        """
        CallStatus
        """

        COMPLETED = "CMP", "Completed"
        MISSED = "MSD", "Missed"
        DECLINED = "DCL", "Declined"
        CANCELED = "CCL", "Canceled"  # Caller canceled before connect
        FAILED = "FLD", "Failed"

    class CallType(models.TextChoices):
        """
        CallType
        """

        VIDEO = "VID", "Video Call"
        VOICE = "VOI", "Voice Call"

    id = models.CharField(
        max_length=21,
        primary_key=True,
        editable=False,
        default=partial(generate, size=21, alphabet=CUSTOM_ALPHABET),
    )

    initiator = models.ForeignKey(
        USER,
        on_delete=models.CASCADE,
        related_name="initiated_group_calls",
        help_text="The user who started the call.",
    )

    participants = models.ManyToManyField(
        USER,
        through="CallParticipantModel",
        related_name="call_participations",
        help_text="All users who were invited or joined the call.",
    )

    call_type = models.CharField(
        max_length=3,
        choices=CallType.choices,
        default=CallType.VOICE,
    )

    title = models.CharField(
        max_length=150,
        blank=False,
    )

    start_time = models.DateTimeField(auto_now_add=True)
    end_time = models.DateTimeField(
        null=True,
        blank=True,
        help_text="Time call ended or was missed/rejected.",
    )
    duration = models.DurationField(
        null=True,
        blank=True,
        help_text="The connected call duration (NULL for missed/rejected).",
    )
    status = models.CharField(
        max_length=3,
        choices=CallStatus.choices,
        default=CallStatus.CANCELED,
    )
    is_recording = models.BooleanField(default=False, blank=False)

    class Meta:
        """
        Meta
        """

        verbose_name = "Call Record"
        verbose_name_plural = "Call Record"
        ordering = ("-start_time",)

    def __str__(self):
        """
        str
        """
        caller = getattr(self.initiator, "username", "")
        call_type = getattr(self.call_type, "call_type", "")
        status = getattr(self.status, "status", "")
        return f"{call_type} by {caller} ({status})"

    def model_dump(self, omit: set | None = None) -> Dict[str, Any]:
        """
        Converts model to dict.

        Args:
            omit (set): A set of fields to omit.
        Returns:
            Dict[str, Any]
        """
        dict_copy = self.__dict__.copy()

        if omit:
            for key in dict_copy:
                if key in omit:
                    dict_copy.pop(key, None)
        dict_copy.pop("_state", None)
        status_ = dict_copy.get("status")
        if status_:
            for choice in self.CallStatus.choices:
                if status_ == choice[0]:
                    dict_copy["status"] = choice[1]
        initiator = dict_copy.get("initiator")
        if initiator:
            user_copy = initiator.__dict__.copy()
            user_copy.pop("_state")
            user_copy.pop("password")
            dict_copy["initiator"] = user_copy

        return dict_copy


class CallParticipantModel(models.Model):
    """
    Intermediate table to track per-user call status, join time, and leave time.
    """

    class ParticipantStatus(models.TextChoices):
        """
        ParticipantStatus
        """

        JOINED = "JND", "Joined"
        MISSED = "MSD", "Missed"
        DECLINED = "DCL", "Declined"
        LEFT = "LFT", "Left"
        CONNECTING = "CON", "Connecting"
        BUSY = "BSY", "Busy"

    id = models.CharField(
        max_length=21,
        primary_key=True,
        editable=False,
        default=partial(generate, size=21),
    )
    call = models.ForeignKey(
        "CallRecordModel",
        on_delete=models.CASCADE,
        related_name="participant_links",
    )
    video_enabled = models.BooleanField(default=True, blank=False)
    audio_enabled = models.BooleanField(default=True, blank=False)
    user = models.ForeignKey(
        USER,
        on_delete=models.CASCADE,
        related_name="call_participant_links",
    )
    status = models.CharField(
        max_length=3,
        choices=ParticipantStatus.choices,
        default=ParticipantStatus.CONNECTING,
    )
    join_time = models.DateTimeField(null=True, blank=True)
    leave_time = models.DateTimeField(null=True, blank=True)

    class Meta:
        """
        Meta
        """

        unique_together = ("call", "user")
        verbose_name = "Call Participant"
        verbose_name_plural = "Call Participants"

    def __str__(self):
        """
        str
        """
        return f"{self.user} ({self.status}) in {self.id}"

    def model_dump(self, omit: set | None = None) -> Dict[str, Any]:
        """
        Converts model to dict.

        Args:
            omit (set): A set of fields to omit.
        Returns:
            Dict[str, Any]
        """
        dict_copy = self.__dict__.copy()

        if omit:
            for key in dict_copy:
                if key in omit:
                    dict_copy.pop(key, None)
        user = dict_copy.get("user")
        if user:
            user_copy = user.__dict__.copy()
            user_copy.pop("_state")
            user_copy.pop("password")
            dict_copy["user"] = user_copy
        dict_copy.pop("_state", None)

        return dict_copy
