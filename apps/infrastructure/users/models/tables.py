from functools import partial

from django.contrib.auth.models import AbstractUser
from django.db import models
from apps.core.utils import generate_nanoid

from apps.domain.users.enums import Ethnicity, FollowRequestStatus, RelationshipStatus, Gender

from ..managers import UserManager


class User(AbstractUser):
    id = models.CharField(
        max_length=21,
        primary_key=True,
        editable=False,
        default=generate_nanoid,
    )
    email = models.EmailField(max_length=50, unique=True, blank=False, db_index=True)
    username = models.CharField(max_length=50, unique=True, blank=False)
    is_email_verified = models.BooleanField(default=False, db_index=True)
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
        default=generate_nanoid,
    )
    first_name = models.CharField(max_length=100, blank=True, null=True)
    last_name = models.CharField(max_length=100, blank=True, null=True)
    bio = models.TextField(max_length=500, blank=True, null=True)
    profile_picture = models.ImageField(
        upload_to="profile_images/", blank=True, null=True, db_index=True
    )
    cover_picture = models.ImageField(
        upload_to="cover_pictures/", blank=True, null=True, db_index=True
    )
    occupation = models.CharField(max_length=100, blank=True, null=True)
    birth_date = models.DateField(blank=True, null=True)
    height = models.DecimalField(max_digits=5, decimal_places=2, blank=True, null=True)
    weight = models.DecimalField(max_digits=5, decimal_places=2, blank=True, null=True)
    ethnicity = models.CharField(
        max_length=16, choices=Ethnicity.choices, default=Ethnicity.OTHER
    )
    gender = models.CharField(
        max_length=16, choices=Gender.choices, default=Gender.PREFER_NOT_SAY
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
        indexes = [models.Index(fields=["first_name", "last_name"])]

    def __str__(self) -> str:
        return f"{self.first_name or ''} {self.last_name or ''}".strip() or str(
            self.user.email
        )


class UserFollowing(models.Model):
    id = models.CharField(
        max_length=21,
        primary_key=True,
        editable=False,
        default=generate_nanoid,
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
        db_index=True,
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "user_following"
        verbose_name = "user_following"
        verbose_name_plural = "user_followings"
        ordering = ["-created_at"]
        unique_together = ["follower", "following"]
        indexes = [models.Index(fields=["follower", "following"])]

    def __str__(self) -> str:
        return f"{self.follower} -> {self.following}"


class UserMentionCount(models.Model):
    user = models.OneToOneField(
        "User",
        on_delete=models.CASCADE,
        related_name="mention_count_obj",
        primary_key=True,
    )
    count = models.PositiveIntegerField(default=0, db_index=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "user_mention_count"
        verbose_name = "user mention count"
        verbose_name_plural = "user mention counts"

    def __str__(self) -> str:
        return f"{self.user.username}: {self.count} mentions"

    @classmethod
    def increment_count(cls, user_id: str, amount: int = 1):
        obj, created = cls.objects.get_or_create(user_id=user_id, defaults={"count": 0})
        obj.count = models.F("count") + amount
        obj.save(update_fields=["count", "updated_at"])
        obj.refresh_from_db()
        return obj.count

    @classmethod
    def get_count(cls, user_id: str) -> int:
        try:
            return cls.objects.get(user_id=user_id).count
        except cls.DoesNotExist:
            return 0
