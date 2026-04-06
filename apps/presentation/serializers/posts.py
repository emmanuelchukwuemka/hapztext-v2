from datetime import datetime

from rest_framework import serializers

from apps.domain.posts.enums import PostFormat


class PostCreateSerializer(serializers.Serializer):
    post_format = serializers.ChoiceField(choices=PostFormat.choices(), required=True)
    text_content = serializers.CharField(
        required=False, allow_null=True, allow_blank=True
    )
    background_color = serializers.CharField(
        required=False, allow_null=True, allow_blank=True, max_length=7
    )
    image_files = serializers.ListField(
        child=serializers.ImageField(),
        required=False,
        allow_empty=True,
        default=list,
    )
    audio_files = serializers.ListField(
        child=serializers.FileField(),
        required=False,
        allow_empty=True,
        default=list,
    )
    video_files = serializers.ListField(
        child=serializers.FileField(),
        required=False,
        allow_empty=True,
        default=list,
    )
    is_reply = serializers.BooleanField(required=False, default=False)
    previous_post_id = serializers.CharField(
        required=False, allow_null=True, allow_blank=True
    )
    is_published = serializers.BooleanField(required=False, default=True)
    scheduled_at = serializers.DateTimeField(required=False, allow_null=True)
    tagged_user_ids = serializers.CharField(
        required=False, allow_blank=True, default=""
    )

    # def validate_tagged_user_ids(self, value):
    #     if not value:
    #         return []

    #     cleaned_ids = []
    #     for item in value:
    #         if ',' in str(item):
    #             split_ids = [id.strip() for id in str(item).split(',') if id.strip()]
    #             cleaned_ids.extend(split_ids)
    #         else:
    #             cleaned_ids.append(str(item).strip())

    #     seen = set()
    #     unique_ids = []
    #     for user_id in cleaned_ids:
    #         if user_id and user_id not in seen:
    #             seen.add(user_id)
    #             unique_ids.append(user_id)

    #     for user_id in unique_ids:
    #         if len(user_id) > 21:
    #             raise serializers.ValidationError(
    #                 f"User ID '{user_id}' is too long (max 21 characters)"
    #             )
    #         if len(user_id) == 0:
    #             raise serializers.ValidationError("User ID cannot be empty")

    #     return unique_ids

    def validate(self, attrs):
        post_format = attrs.get("post_format")
        text_content = attrs.get("text_content")
        image_files = attrs.get("image_files", [])
        audio_files = attrs.get("audio_files", [])
        video_files = attrs.get("video_files", [])
        scheduled_at = attrs.get("scheduled_at")

        # Validate that content is provided for the post format
        if post_format == PostFormat.TEXT:
            if not text_content:
                raise serializers.ValidationError(
                    f"For post_format '{post_format}', text_content is required."
                )
        elif post_format == PostFormat.IMAGE:
            if not image_files:
                raise serializers.ValidationError(
                    f"For post_format '{post_format}', at least one image file is required."
                )
        elif post_format == PostFormat.AUDIO:
            if not audio_files:
                raise serializers.ValidationError(
                    f"For post_format '{post_format}', at least one audio file is required."
                )
        elif post_format == PostFormat.VIDEO:
            if not video_files:
                raise serializers.ValidationError(
                    f"For post_format '{post_format}', at least one video file is required."
                )

        # Validate audio files
        if audio_files:
            allowed_audio_types = [
                "audio/mpeg",
                "audio/wav",
                "audio/ogg",
                "audio/aac",
                "audio/flac",
                "audio/mp3",
            ]
            for audio_file in audio_files:
                if audio_file.content_type not in allowed_audio_types:
                    raise serializers.ValidationError(
                        f"Unsupported audio file type: {audio_file.content_type}"
                    )

        # Validate video files
        if video_files:
            allowed_video_types = [
                "video/mp4",
                "video/x-msvideo",
                "video/quicktime",
                "video/webm",
            ]
            for video_file in video_files:
                if video_file.content_type not in allowed_video_types:
                    from loguru import logger

                    logger.critical(
                        f"Unsupported video file type: {video_file.content_type}, Allowed types are: {allowed_video_types}"
                    )
                    raise serializers.ValidationError(
                        f"Unsupported video file type: {video_file.content_type}"
                    )

        # Validate background_color format if provided (hex color)
        background_color = attrs.get("background_color")
        if background_color:
            import re

            if not re.match(r"^#[0-9A-Fa-f]{6}$", background_color):
                raise serializers.ValidationError(
                    "background_color must be a valid hex color (e.g., #FF5733)"
                )

        if scheduled_at and scheduled_at <= datetime.now(scheduled_at.tzinfo):
            raise serializers.ValidationError("Scheduled time must be in the future.")

        if scheduled_at and attrs.get("is_published", True):
            attrs["is_published"] = False

        attrs["sender_id"] = self.context.get("sender_id")

        raw_ids = attrs.get("tagged_user_ids", "")
        if raw_ids:
            ids = [i.strip() for i in raw_ids.split(",") if i.strip()]
            attrs["tagged_user_ids"] = list(dict.fromkeys(ids))
        else:
            attrs["tagged_user_ids"] = []

        return attrs


class PostListSerializer(serializers.Serializer):
    page = serializers.IntegerField(required=True)
    page_size = serializers.IntegerField(required=True)
    feed_type = serializers.ChoiceField(
        choices=[
            ("timeline", "Timeline"),
            ("trending", "Trending"),
            ("popular", "Popular"),
        ],
        default="timeline",
    )
    query = serializers.CharField(required=False, allow_blank=True, allow_null=True)


class FetchRepliesSerializer(serializers.Serializer):
    post_id = serializers.CharField(read_only=True)
    page = serializers.IntegerField(required=True, min_value=1)
    page_size = serializers.IntegerField(required=True, min_value=1, max_value=100)

    def validate(self, attrs):
        attrs["post_id"] = self.context.get("post_id")
        return attrs


class UserPostsSerializer(serializers.Serializer):
    user_id = serializers.CharField(read_only=True)
    page = serializers.IntegerField(required=True)
    page_size = serializers.IntegerField(required=True)

    def validate(self, attrs):
        attrs["user_id"] = self.context.get("user_id")
        return attrs


class PostReactionSerializer(serializers.Serializer):
    reaction = serializers.CharField(required=True)
    post_id = serializers.CharField(read_only=True)
    user_id = serializers.CharField(read_only=True)

    def validate(self, attrs):
        attrs["post_id"] = self.context.get("post_id")
        attrs["user_id"] = self.context.get("user_id")
        return attrs


class PostReactorsSerializer(serializers.Serializer):
    post_id = serializers.CharField(read_only=True)
    user_id = serializers.CharField(read_only=True)
    page = serializers.IntegerField(required=True, min_value=1)
    page_size = serializers.IntegerField(required=True, min_value=1, max_value=100)

    def validate(self, attrs):
        attrs["post_id"] = self.context.get("post_id")
        attrs["user_id"] = self.context.get("user_id")
        return attrs


class PostShareSerializer(serializers.Serializer):
    shared_with_message = serializers.CharField(
        required=False, allow_blank=True, max_length=500
    )
    post_id = serializers.CharField(read_only=True)
    user_id = serializers.CharField(read_only=True)

    def validate(self, attrs):
        attrs["post_id"] = self.context.get("post_id")
        attrs["user_id"] = self.context.get("user_id")
        return attrs
