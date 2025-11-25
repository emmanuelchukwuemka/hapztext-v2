from functools import partial

from django.db import models
from nanoid import generate

from apps.domain.posts.enums import PostFormat


class Post(models.Model):
    id = models.CharField(
        max_length=21,
        primary_key=True,
        editable=False,
        default=partial(generate, size=21),
    )
    post_format = models.CharField(
        max_length=5, choices=PostFormat.choices, default=PostFormat.TEXT
    )
    text_content = models.TextField(blank=True, null=True)
    image_content = models.ImageField(upload_to="posts/images/", blank=True, null=True)
    audio_content = models.FileField(upload_to="posts/audios/", blank=True, null=True)
    video_content = models.FileField(upload_to="posts/videos/", blank=True, null=True)
    is_reply = models.BooleanField(default=False)
    previous_post_id = models.CharField(max_length=21, blank=True, null=True)
    sender = models.ForeignKey(
        "users.User", related_name="posts", on_delete=models.CASCADE
    )
    is_published = models.BooleanField(default=True)
    scheduled_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "post"
        verbose_name = "post"
        verbose_name_plural = "posts"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["created_at"]),
            models.Index(fields=["sender", "-created_at"]),
            models.Index(fields=["is_published", "scheduled_at"]),
            models.Index(fields=["is_reply", "previous_post_id"]),
        ]

    def __str__(self):
        return f"{str(self.get_post_format_display())} post from {str(self.sender)}"


class PostReaction(models.Model):
    id = models.CharField(
        max_length=21,
        primary_key=True,
        editable=False,
        default=partial(generate, size=21),
    )
    user = models.ForeignKey(
        "users.User", on_delete=models.CASCADE, related_name="post_reactions"
    )
    post = models.ForeignKey(Post, on_delete=models.CASCADE, related_name="reactions")
    reaction = models.CharField(max_length=36, blank=False, null=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "post_reaction"
        verbose_name = "post reaction"
        verbose_name_plural = "post reactions"
        unique_together = ["user", "post"]
        indexes = [
            models.Index(fields=["post", "reaction"]),
        ]

    def __str__(self):
        return f"{self.user.username} {self.reaction} {self.post.id}"


class PostShare(models.Model):
    id = models.CharField(
        max_length=21,
        primary_key=True,
        editable=False,
        default=partial(generate, size=21),
    )
    user = models.ForeignKey(
        "users.User", on_delete=models.CASCADE, related_name="post_shares"
    )
    post = models.ForeignKey(Post, on_delete=models.CASCADE, related_name="shares")
    shared_with_message = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "post_share"
        verbose_name = "post share"
        verbose_name_plural = "post shares"
        unique_together = ["user", "post"]
        indexes = [
            models.Index(fields=["post", "created_at"]),
        ]

    def __str__(self):
        return f"{self.user.username} shared {self.post.id}"


class PostTag(models.Model):
    id = models.CharField(
        max_length=21,
        primary_key=True,
        editable=False,
        default=partial(generate, size=21),
    )
    post = models.ForeignKey(Post, on_delete=models.CASCADE, related_name="tags")
    tagged_user = models.ForeignKey(
        "users.User", on_delete=models.CASCADE, related_name="post_tags"
    )
    tagged_by_user = models.ForeignKey(
        "users.User", on_delete=models.CASCADE, related_name="created_post_tags"
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "post_tag"
        verbose_name = "post tag"
        verbose_name_plural = "post tags"
        unique_together = ["post", "tagged_user"]
        indexes = [
            models.Index(fields=["tagged_user", "created_at"]),
        ]

    def __str__(self):
        return f"{self.tagged_by_user.username} tagged {self.tagged_user.username} in {self.post.id}"
