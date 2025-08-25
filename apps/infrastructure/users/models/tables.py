from functools import partial

from django.contrib.auth.models import AbstractUser
from django.db import models
from nanoid import generate

from apps.domain.users.enums import Ethnicity, FollowRequestStatus, RelationshipStatus

from ..managers import UserManager


class User(AbstractUser):
    id = models.CharField(
        max_length=21,
        primary_key=True,
        editable=False,
        default=partial(generate, size=21),
    )
    email = models.EmailField(max_length=50, unique=True, blank=False)
    username = models.CharField(max_length=50, unique=True, blank=False)
    is_email_verified = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    objects = UserManager()

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = []

    class Meta:
        db_table = "user"
        verbose_name = "user"
        verbose_name_plural = "users"
        ordering = ["-created_at"]

    def __str__(self) -> str:
        return str(self.email)


class UserProfile(models.Model):
    id = models.CharField(
        max_length=21,
        primary_key=True,
        editable=False,
        default=partial(generate, size=21),
    )
    first_name = models.CharField(max_length=100, blank=True, null=True)
    last_name = models.CharField(max_length=100, blank=True, null=True)
    bio = models.TextField(max_length=500, blank=True, null=True)
    profile_picture = models.ImageField(
        upload_to="media/profile_images/", blank=True, null=True
    )
    occupation = models.CharField(max_length=100, blank=True, null=True)
    birth_date = models.DateField(blank=False)
    height = models.DecimalField(max_digits=5, decimal_places=2, blank=True, null=True)
    weight = models.DecimalField(max_digits=5, decimal_places=2, blank=True, null=True)
    ethnicity = models.CharField(
        max_length=16, choices=Ethnicity.choices, default=Ethnicity.OTHER
    )
    location = models.CharField(
        max_length=255,
        blank=True,
        null=True,
        help_text="User's location, e.g., 'MorningGrove, Lagos, Nigeria'",
    )
    relationship_status = models.CharField(
        max_length=15,
        choices=RelationshipStatus.choices,
        default=RelationshipStatus.SINGLE,
    )
    following = models.ManyToManyField(
        "self",
        symmetrical=False,
        through="UserFollowing",
        through_fields=("follower", "following"),
        related_name="followers",
    )
    user = models.OneToOneField(
        User, on_delete=models.CASCADE, related_name="user_profile"
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "user_profile"
        verbose_name = "user_profile"
        verbose_name_plural = "user_profiles"
        ordering = ["-created_at"]

    def __str__(self) -> str:
        return f"{self.first_name or ''} {self.last_name or ''}".strip() or str(
            self.user.email
        )


class UserFollowing(models.Model):
    id = models.CharField(
        max_length=21,
        primary_key=True,
        editable=False,
        default=partial(generate, size=21),
    )
    follower = models.ForeignKey(
        "UserProfile", on_delete=models.CASCADE, related_name="following_set"
    )
    following = models.ForeignKey(
        "UserProfile", on_delete=models.CASCADE, related_name="follower_set"
    )
    status = models.CharField(
        max_length=10,
        choices=FollowRequestStatus.choices(),
        default=FollowRequestStatus.PENDING,
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "user_following"
        verbose_name = "user_following"
        verbose_name_plural = "user_followings"
        ordering = ["-created_at"]
        unique_together = ["follower", "following"]

    def __str__(self) -> str:
        return f"{self.follower} -> {self.following} ({self.status})"
