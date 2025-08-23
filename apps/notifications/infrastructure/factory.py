from apps.notifications.application.rules import (
    CreateNotificationRule,
    GetNotificationPreferencesRule,
    GetUserNotificationsRule,
    MarkNotificationsAsReadRule,
    NotifyFollowersOfPostRule,
    NotifyPostCreatorOfReplyRule,
    NotifyUserOfFollowAcceptanceRule,
    NotifyUserOfFollowRule,
    UpdateNotificationPreferencesRule,
)
from apps.users.infrastructure.factory import (
    get_user_profile_repository,
    get_user_repository,
)

from .repositories import (
    DjangoNotificationPreferencesRepository,
    DjangoNotificationRepository,
)
from .services import NotificationDispatcher, SSENotificationService


def get_notification_repository() -> DjangoNotificationRepository:
    return DjangoNotificationRepository()


def get_notification_preferences_repository() -> (
    DjangoNotificationPreferencesRepository
):
    return DjangoNotificationPreferencesRepository()


def get_notification_service() -> SSENotificationService:
    return SSENotificationService()


def get_notification_dispatcher() -> NotificationDispatcher:
    return NotificationDispatcher(get_notification_service())


def get_create_notification_rule() -> CreateNotificationRule:
    return CreateNotificationRule(
        notification_repository=get_notification_repository(),
        preferences_repository=get_notification_preferences_repository(),
        dispatcher=get_notification_dispatcher(),
    )


def get_user_notifications_rule() -> GetUserNotificationsRule:
    return GetUserNotificationsRule(
        notification_repository=get_notification_repository(),
    )


def get_mark_notifications_read_rule() -> MarkNotificationsAsReadRule:
    return MarkNotificationsAsReadRule(
        notification_repository=get_notification_repository(),
    )


def get_update_notification_preferences_rule() -> UpdateNotificationPreferencesRule:
    return UpdateNotificationPreferencesRule(
        preferences_repository=get_notification_preferences_repository(),
    )


def get_notification_preferences_rule() -> GetNotificationPreferencesRule:
    return GetNotificationPreferencesRule(
        preferences_repository=get_notification_preferences_repository(),
    )


def get_notify_followers_of_post_rule() -> NotifyFollowersOfPostRule:
    return NotifyFollowersOfPostRule(
        user_repository=get_user_repository(),
        user_profile_repository=get_user_profile_repository(),
        create_notification_rule=get_create_notification_rule(),
    )


def get_notify_post_creator_of_reply_rule() -> NotifyPostCreatorOfReplyRule:
    return NotifyPostCreatorOfReplyRule(
        user_repository=get_user_repository(),
        create_notification_rule=get_create_notification_rule(),
    )


def get_notify_user_of_follow_rule() -> NotifyUserOfFollowRule:
    return NotifyUserOfFollowRule(
        user_repository=get_user_repository(),
        create_notification_rule=get_create_notification_rule(),
    )


def get_notify_user_of_follow_acceptance_rule() -> NotifyUserOfFollowAcceptanceRule:
    return NotifyUserOfFollowAcceptanceRule(
        user_repository=get_user_repository(),
        create_notification_rule=get_create_notification_rule(),
    )
