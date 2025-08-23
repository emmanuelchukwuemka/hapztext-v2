from django_eventstream.channelmanager import DefaultChannelManager


class AuthenticatedChannelManager(DefaultChannelManager):
    def can_read_channel(self, user, channel):
        """Check if user can access the specific channel"""
        if channel.startswith("notifications-"):
            # Require authentication
            if not user or user.is_anonymous:
                return False

            # Extract user_id from channel name
            try:
                channel_user_id = channel.replace("notifications-", "")
                # User can only access their own notification channel
                return str(user.id) == channel_user_id
            except (ValueError, AttributeError):
                return False

        return super().can_read_channel(user, channel)

    def get_channels_for_request(self, request, path, **kwargs):
        """Return the appropriate channels for the authenticated user"""
        # If user is authenticated, return their personal channel
        if hasattr(request, "user") and request.user.is_authenticated:
            user_channel = f"notifications-{request.user.id}"
            return [user_channel]

        # For unauthenticated requests, return empty list
        return []
