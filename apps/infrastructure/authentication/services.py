from typing import Any, Dict, List

from django.conf import settings
from django.contrib.auth import signals
from django.contrib.auth.hashers import check_password, make_password
from django.core.mail import EmailMultiAlternatives
from django.db import transaction
from django.template.loader import render_to_string
from django.utils.html import strip_tags
from knox import crypto
from knox.models import AuthToken
from loguru import logger

from apps.application.authentication.ports import (
    AuthenticationServiceInterface,
    EmailServiceInterface,
)
from apps.core.exceptions import BaseAPIException
from apps.domain.authentication.entities import OTPCode
from apps.domain.authentication.enums import OTPCodePurpose
from apps.domain.authentication.value_objects import Purpose


class DjangoEmailServiceAdapter(EmailServiceInterface):
    def send_otp_email(
        self, email: str, otp_code: OTPCode, purpose: OTPCodePurpose
    ) -> int:
        Purpose(purpose)

        context = {
            "email": email,
            "otp_code": otp_code.code,
            "expiry_minutes": getattr(settings, "OTP_EXPIRY_MINUTES", 10),
        }

        if purpose == "email_verification":
            subject = "Verify your email address"
            template_name = "verify_email"
        elif purpose == "password_reset":
            subject = "Reset your password"
            template_name = "reset_password"

        try:
            self._send_template_email(
                subject=subject,
                template_name=template_name,
                context=context,
                recipient_list=[email],
            )
        except Exception as e:
            logger.exception(f"OTP email failed to send: {e}.")
            raise BaseAPIException("OTP email failed to send. Try again later.") from e

    def _send_template_email(
        self,
        subject: str,
        template_name: str,
        context: Dict[str, str | int],
        recipient_list: List[str],
        from_email: str | None = None,
    ) -> int:
        if not from_email:
            from_email = settings.DEFAULT_FROM_EMAIL

        html_content = render_to_string(f"{template_name}.html", context)
        text_content = strip_tags(html_content)

        email = EmailMultiAlternatives(
            subject=subject,
            body=text_content,
            from_email=from_email,
            to=recipient_list,
        )
        email.attach_alternative(html_content, "text/html")

        return email.send()


class KnoxAuthenticationServiceAdapter(AuthenticationServiceInterface):
    def generate_auth_tokens(self, user: Any) -> Dict[str, str]:
        token_limit = settings.REST_KNOX.get("TOKEN_LIMIT_PER_USER", 3)

        try:
            with transaction.atomic():
                tokens = AuthToken.objects.filter(user=user).order_by("-created")
                if tokens.count() >= token_limit:
                    tokens.first().delete()

                _, token = AuthToken.objects.create(user=user)
        except Exception as e:
            logger.exception(f"Auth token generation failed: {e}.")
            raise BaseAPIException(
                "Auth token generation failed. Try again later."
            ) from e

        return {"auth": token}

    def verify_auth_token(self, auth_token: str) -> bool:
        digest = crypto.hash_token(auth_token)
        return AuthToken.objects.filter(digest=digest).exists()

    def invalidate_auth_token(
        self, auth_token: str, request: Any = None, batch: bool = False
    ) -> None:
        if not request:
            raise ValueError("Request parameter is missing from logout data.")

        try:
            if batch:
                request.user.auth_token_set.all().delete()
            else:
                request._auth.delete()

            signals.user_logged_out.send(
                sender=request.user.__class__, request=request, user=request.user
            )
        except Exception as e:
            logger.exception(f"Auth token invalidation failed: {e}.")
            raise BaseAPIException(
                "Auth token invalidation failed. Try again later."
            ) from e
