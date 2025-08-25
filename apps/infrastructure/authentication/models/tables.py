from datetime import UTC, datetime, timedelta
from functools import partial

import pyotp
from django.conf import settings
from django.db import models
from nanoid import generate

from apps.domain.authentication.enums import OTPCodePurpose


class OTPCode(models.Model):
    @staticmethod
    def generate_otp_code():
        return pyotp.TOTP(pyotp.random_base32(), digits=6).now()

    @staticmethod
    def get_otp_expiry():
        return datetime.now(tz=UTC) + timedelta(
            minutes=getattr(settings, "OTP_EXPIRY_MINUTES", 10)
        )

    id = models.CharField(
        max_length=21,
        primary_key=True,
        editable=False,
        default=partial(generate, size=21),
    )
    user = models.OneToOneField(
        "users.User", on_delete=models.CASCADE, related_name="otp_code"
    )
    code = models.CharField(max_length=6, editable=False)
    purpose = models.CharField(
        max_length=20,
        choices=OTPCodePurpose.choices,
        default=OTPCodePurpose.EMAIL_VERIFICATION,
    )
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField(editable=False)

    class Meta:
        db_table = "otp_code"
        verbose_name = "otp code"
        verbose_name_plural = "otp codes"
        unique_together = ("user", "code", "purpose")

    def __str__(self) -> str:
        return f"OTP for {str(self.user)} - {str(self.purpose)}"

    def save(self, *args, **kwargs):
        if not self.code:
            self.code = OTPCode.generate_otp_code()

        if self._state.adding:
            self.expires_at = OTPCode.get_otp_expiry()

        super().save(*args, **kwargs)

    def is_valid(self) -> bool:
        return self.expires_at > datetime.now(tz=UTC)
