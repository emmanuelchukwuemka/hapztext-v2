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
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "post"
        verbose_name = "post"
        verbose_name_plural = "posts"
        ordering = ["-created_at"]

    def __str__(self):
        return f"{str(self.get_post_format_display())} post from {str(self.sender)}"
