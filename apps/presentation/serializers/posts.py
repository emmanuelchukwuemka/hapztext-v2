from rest_framework import serializers

from apps.domain.posts.enums import PostFormat


class PostCreateSerializer(serializers.Serializer):
    post_format = serializers.ChoiceField(choices=PostFormat.choices(), required=True)
    text_content = serializers.CharField(
        required=False, allow_null=True, allow_blank=True
    )
    image_content = serializers.ImageField(required=False, allow_null=True)
    audio_content = serializers.FileField(required=False, allow_null=True)
    video_content = serializers.FileField(required=False, allow_null=True)
    is_reply = serializers.BooleanField(required=False, default=False)
    previous_post_id = serializers.CharField(
        required=False, allow_null=True, allow_blank=True
    )

    def validate(self, attrs):
        post_format = attrs.get("post_format")
        text_content = attrs.get("text_content")
        image_content = attrs.get("image_content")
        audio_content = attrs.get("audio_content")
        video_content = attrs.get("video_content")

        content_fields = {
            PostFormat.TEXT: text_content,
            PostFormat.IMAGE: image_content,
            PostFormat.AUDIO: audio_content,
            PostFormat.VIDEO: video_content,
        }

        if not content_fields.get(post_format):
            raise serializers.ValidationError(
                f"For post_format '{post_format}', corresponding content is required."
            )

        for format, content in content_fields.items():
            if format != post_format and content not in [None, "", text_content]:
                raise serializers.ValidationError(
                    f"Only content for '{post_format}' should be provided. Found content for '{format}'."
                )

        if post_format == PostFormat.AUDIO and audio_content:
            allowed_audio_types = [
                "audio/mpeg",
                "audio/wav",
                "audio/ogg",
                "audio/aac",
                "audio/flac",
                "audio/mp3",
            ]
            if audio_content.content_type not in allowed_audio_types:
                raise serializers.ValidationError("Unsupported audio file type.")

        if post_format == PostFormat.VIDEO and video_content:
            allowed_video_types = [
                "video/mp4",
                "video/x-msvideo",
                "video/quicktime",
                "video/webm",
            ]
            if video_content.content_type not in allowed_video_types:
                from loguru import logger

                logger.critical(
                    f"Unsupported video file type: {video_content.content_type}, Allowed types are: {allowed_video_types}"
                )
                raise serializers.ValidationError("Unsupported video file type.")

        attrs["sender_id"] = self.context.get("sender_id")

        return attrs


class PostListSerializer(serializers.Serializer):
    page = serializers.IntegerField(required=True)
    page_size = serializers.IntegerField(required=True)


class UserPostsSerializer(serializers.Serializer):
    user_id = serializers.CharField(read_only=True)
    page = serializers.IntegerField(required=True)
    page_size = serializers.IntegerField(required=True)

    def validate(self, attrs):
        attrs["user_id"] = self.context.get("user_id")
        return attrs
