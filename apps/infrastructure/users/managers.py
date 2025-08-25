from typing import Any

from django.contrib.auth.models import BaseUserManager
from django.db import IntegrityError
from loguru import logger

from apps.core.exceptions import BaseAPIException, ConflictError


class UserManager(BaseUserManager):
    def _create_user(self, email: str, password: str, **extra) -> Any:
        normalized_email = self.normalize_email(email)

        user = self.model(email=normalized_email, **extra)

        if bool(extra.get("is_superuser", False)):
            user.set_password(password)
        else:
            user.password = password

        if not password:
            user.set_unusable_password()

        try:
            user.save(using=self._db)
        except IntegrityError as e:
            if "email" in str(e):
                raise ConflictError(
                    f"User with email '{normalized_email}' already exists."
                )
            elif "username" in str(e):
                raise ConflictError(
                    f"User with username '{extra['username']}' already exists."
                )

            logger.exception(
                f"Unhandled database constraint error while creating user: {e}."
            )
            raise ConflictError(
                "User creation failed. Conflicting resource exists."
            ) from e

        except Exception as e:
            logger.exception(f"Unhandled database error while creating user: {e}.")
            raise BaseAPIException("User creation failed. Try again later.") from e

        return user

    def create_user(self, **extra) -> Any:
        return self._create_user(**extra)

    def create_superuser(self, **extra) -> Any:
        extra.setdefault("is_email_verified", True)
        extra.setdefault("is_superuser", True)
        extra.setdefault("is_staff", True)

        return self._create_user(**extra)

    def get_by_natural_key(self, username: str) -> Any:
        return self.get(email__iexact=username)
