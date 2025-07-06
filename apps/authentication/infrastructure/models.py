from datetime import UTC, datetime, timedelta
from functools import partial

from django.conf import settings
from django.db import models
from nanoid import generate

from ..domain.enums import OTPCodePurpose


class OTPCode(models.Model):
    id = models.CharField(
        max_length=21,
        primary_key=True,
        editable=False,
        default=partial(generate, size=21),
    )
    user = models.OneToOneField(
        "users.User", on_delete=models.CASCADE, related_name="otp_code"
    )
    code = models.CharField(max_length=6, unique=True, editable=False)
    purpose = models.CharField(
        max_length=20,
        choices=OTPCodePurpose.choices,
        default=OTPCodePurpose.EMAIL_VERIFICATION,
    )
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField(
        default=datetime.now(tz=UTC)
        + timedelta(minutes=getattr(settings, "OTP_EXPIRY_MINUTES", 10)),
        editable=False,
    )

    class Meta:
        db_table = "otp_code"
        verbose_name = "otp code"
        verbose_name_plural = "otp codes"

    def __str__(self) -> str:
        return f"OTP for {str(self.user)} - {str(self.purpose)}"

    def is_valid(self) -> bool:
        return self.expires_at > datetime.now(tz=UTC)
