from rest_framework import serializers


class NotificationListSerializer(serializers.Serializer):
    page = serializers.IntegerField(required=True)
    page_size = serializers.IntegerField(required=True)
    unread_only = serializers.BooleanField(required=False, default=False)

    def validate(self, attrs):
        attrs["user_id"] = self.context.get("user_id")
        return attrs


class MarkNotificationsReadSerializer(serializers.Serializer):
    notification_ids = serializers.ListField(
        child=serializers.CharField(), required=False, allow_empty=True
    )

    def validate(self, attrs):
        attrs["user_id"] = self.context.get("user_id")
        return attrs


class UpdateNotificationPreferencesSerializer(serializers.Serializer):
    post_notifications_enabled = serializers.BooleanField(required=False)
    follow_notifications_enabled = serializers.BooleanField(required=False)
    reply_notifications_enabled = serializers.BooleanField(required=False)

    def validate(self, attrs):
        attrs["user_id"] = self.context.get("user_id")
        return attrs
