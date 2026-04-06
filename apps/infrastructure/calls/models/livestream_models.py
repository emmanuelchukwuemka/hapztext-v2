"""
LiveStream Models
"""

from typing import Any, Dict

from django.db import models
from django.conf import settings
from apps.core.utils import generate_nanoid

USER = settings.AUTH_USER_MODEL

CUSTOM_ALPHABET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_"

def generate_stream_id():
    return generate_nanoid(size=21, alphabet=CUSTOM_ALPHABET)


class LiveStreamModel(models.Model):
    """
    Stores a live stream session.
    """

    class StreamStatus(models.TextChoices):
        """
        StreamStatus
        """

        LIVE = "LIV", "Live"
        ENDED = "END", "Ended"
        PAUSED = "PSD", "Paused"

    id = models.CharField(
        max_length=21,
        primary_key=True,
        editable=False,
        default=generate_stream_id,
    )

    streamer = models.ForeignKey(
        USER,
        on_delete=models.CASCADE,
        related_name="live_streams",
        help_text="The user who started the stream.",
    )

    title = models.CharField(
        max_length=200,
        blank=True,
        default="",
    )

    status = models.CharField(
        max_length=3,
        choices=StreamStatus.choices,
        default=StreamStatus.LIVE,
    )

    viewer_count = models.PositiveIntegerField(default=0)

    start_time = models.DateTimeField(auto_now_add=True)
    end_time = models.DateTimeField(
        null=True,
        blank=True,
        help_text="Time the stream ended.",
    )

    class Meta:
        """
        Meta
        """

        verbose_name = "Live Stream"
        verbose_name_plural = "Live Streams"
        ordering = ("-start_time",)

    def __str__(self):
        """
        str
        """
        streamer = getattr(self.streamer, "username", "")
        return f"Stream by {streamer} ({self.get_status_display()})"

    def model_dump(self, omit: set | None = None) -> Dict[str, Any]:
        """
        Converts model to dict.
        """
        dict_copy = self.__dict__.copy()
        dict_copy.pop("_state", None)

        if omit:
            for key in list(dict_copy.keys()):
                if key in omit:
                    dict_copy.pop(key, None)

        status_ = dict_copy.get("status")
        if status_:
            for choice in self.StreamStatus.choices:
                if status_ == choice[0]:
                    dict_copy["status"] = choice[1]

        return dict_copy


class LiveStreamViewerModel(models.Model):
    """
    Tracks viewers of a live stream.
    """

    id = models.CharField(
        max_length=21,
        primary_key=True,
        editable=False,
        default=generate_stream_id,
    )

    stream = models.ForeignKey(
        "LiveStreamModel",
        on_delete=models.CASCADE,
        related_name="viewers",
    )

    user = models.ForeignKey(
        USER,
        on_delete=models.CASCADE,
        related_name="viewed_streams",
    )

    joined_at = models.DateTimeField(auto_now_add=True)
    left_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        """
        Meta
        """

        unique_together = ("stream", "user")
        verbose_name = "Live Stream Viewer"
        verbose_name_plural = "Live Stream Viewers"

    def __str__(self):
        """
        str
        """
        return f"{self.user} viewing {self.stream_id}"

    def model_dump(self, omit: set | None = None) -> Dict[str, Any]:
        """
        Converts model to dict.
        """
        dict_copy = self.__dict__.copy()
        dict_copy.pop("_state", None)

        if omit:
            for key in list(dict_copy.keys()):
                if key in omit:
                    dict_copy.pop(key, None)

        return dict_copy
