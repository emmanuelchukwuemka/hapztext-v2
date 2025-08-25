from functools import partial

from django.db import models
from nanoid import generate

from apps.domain.notifications.enums import NotificationType


class Notification(models.Model):
    id = models.CharField(
        max_length=21,
        primary_key=True,
        editable=False,
        default=partial(generate, size=21),
    )
    recipient = models.ForeignKey(
        "users.User", on_delete=models.CASCADE, related_name="received_notifications"
    )
    sender = models.ForeignKey(
        "users.User", on_delete=models.CASCADE, related_name="sent_notifications"
    )
    notification_type = models.CharField(
        max_length=20,
        choices=NotificationType.choices(),
        default=NotificationType.POST_CREATED,
    )
    message = models.TextField()
    data = models.JSONField(default=dict, blank=True)
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "notification"
        verbose_name = "notification"
        verbose_name_plural = "notifications"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["recipient", "is_read"]),
            models.Index(fields=["recipient", "created_at"]),
        ]

    def __str__(self) -> str:
        return f"{self.notification_type} for {self.recipient.username}"


class NotificationPreferences(models.Model):
    id = models.CharField(
        max_length=21,
        primary_key=True,
        editable=False,
        default=partial(generate, size=21),
    )
    user = models.OneToOneField(
        "users.User", on_delete=models.CASCADE, related_name="notification_preferences"
    )
    post_notifications_enabled = models.BooleanField(default=True)
    follow_notifications_enabled = models.BooleanField(default=True)
    reply_notifications_enabled = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "notification_preferences"
        verbose_name = "notification preferences"
        verbose_name_plural = "notification preferences"

    def __str__(self) -> str:
        return f"Notification preferences for {str(self.user)}"
