from functools import partial

from django.db import models
from apps.core.utils import generate_nanoid

from apps.domain.chat.enums import ConversationType, MessageStatus, MessageType


class Conversation(models.Model):
    id = models.CharField(
        max_length=21,
        primary_key=True,
        editable=False,
        default=generate_nanoid,
    )
    conversation_type = models.CharField(
        max_length=20,
        choices=ConversationType.choices(),
        default=ConversationType.PRIVATE,
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    last_message_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = "chat_conversation"
        verbose_name = "conversation"
        verbose_name_plural = "conversations"
        ordering = ["-last_message_at", "-created_at"]
        indexes = [
            models.Index(fields=["-last_message_at"]),
            models.Index(fields=["conversation_type"]),
        ]

    def __str__(self) -> str:
        return f"{self.conversation_type} conversation {self.id}"


class ConversationParticipant(models.Model):
    id = models.CharField(
        max_length=21,
        primary_key=True,
        editable=False,
        default=generate_nanoid,
    )
    conversation = models.ForeignKey(
        Conversation, on_delete=models.CASCADE, related_name="participants"
    )
    user = models.ForeignKey(
        "users.User", on_delete=models.CASCADE, related_name="chat_participants"
    )
    joined_at = models.DateTimeField(auto_now_add=True)
    last_read_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = "chat_conversation_participant"
        verbose_name = "conversation participant"
        verbose_name_plural = "conversation participants"
        unique_together = ["conversation", "user"]
        indexes = [
            models.Index(fields=["user", "-joined_at"]),
            models.Index(fields=["conversation", "user"]),
        ]

    def __str__(self) -> str:
        return f"{self.user.username} in {self.conversation.id}"


class Message(models.Model):
    id = models.CharField(
        max_length=21,
        primary_key=True,
        editable=False,
        default=generate_nanoid,
    )
    conversation = models.ForeignKey(
        Conversation, on_delete=models.CASCADE, related_name="messages"
    )
    sender = models.ForeignKey(
        "users.User", on_delete=models.CASCADE, related_name="sent_messages"
    )
    message_type = models.CharField(
        max_length=10, choices=MessageType.choices(), default=MessageType.TEXT
    )
    text_content = models.TextField(blank=True, null=True)
    media_url = models.URLField(max_length=500, blank=True, null=True)
    status = models.CharField(
        max_length=20, choices=MessageStatus.choices(), default=MessageStatus.SENT
    )
    is_reply = models.BooleanField(default=False)
    previous_message_id = models.CharField(max_length=21, blank=True, null=True)
    previous_message_content = models.TextField(blank=True, null=True)
    previous_message_sender_id = models.CharField(max_length=21, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    read_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = "chat_message"
        verbose_name = "message"
        verbose_name_plural = "messages"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["conversation", "-created_at"]),
            models.Index(fields=["sender", "-created_at"]),
            models.Index(fields=["conversation", "status"]),
            models.Index(
                fields=[
                    "is_reply",
                    "previous_message_id",
                    "previous_message_content",
                    # "previous_message_sender_id",
                ]
            ),
        ]

    def __str__(self) -> str:
        return f"Message from {self.sender.username} in {self.conversation.id}"
