from django_eventstream.channelmanager import DefaultChannelManager


class AuthenticatedChannelManager(DefaultChannelManager):
    def can_read_channel(self, user, channel):
        if channel.startswith("notifications-"):
            if not user or user.is_anonymous:
                return False

            try:
                channel_user_id = channel.replace("notifications-", "")
                return str(user.id) == channel_user_id
            except (ValueError, AttributeError):
                return False

        return super().can_read_channel(user, channel)

    def get_channels_for_request(self, request, path, **kwargs):
        if hasattr(request, "user") and request.user.is_authenticated:
            user_channel = f"notifications-{request.user.id}"
            return [user_channel]

        return []
