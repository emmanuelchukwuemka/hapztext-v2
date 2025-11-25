from django.apps import AppConfig


class UsersConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.infrastructure.users"
    verbose_name = "users"

    def ready(self) -> None:
        pass


class AuthenticationConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.infrastructure.authentication"
    verbose_name = "authentication"

    def ready(self) -> None:
        pass


class PostsConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.infrastructure.posts"
    verbose_name = "posts"

    def ready(self) -> None:
        pass


class NotificationsConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.infrastructure.notifications"
    verbose_name = "notifications"

    def ready(self) -> None:
        pass


class ChatConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.infrastructure.chat"
    verbose_name = "chat"

    def ready(self) -> None:
        pass


class CallsConfig(AppConfig):
    """
    Calls Config
    """

    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.infrastructure.calls"
    verbose_name = "calls"

    def ready(self) -> None:
        """
        Ready
        """
        pass
