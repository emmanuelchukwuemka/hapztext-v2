from typing import Any, Dict, List, Tuple

from django.db import IntegrityError
from django.urls import reverse

from apps.application.notifications.ports import (
    NotificationPreferencesRepositoryInterface,
    NotificationRepositoryInterface,
)
from apps.core.exceptions import ConflictError
from apps.domain.notifications.entities import Notification as DomainNotification
from apps.domain.notifications.entities import (
    NotificationPreferences as DomainNotificationPreferences,
)

from .models import Notification, NotificationPreferences


def from_domain_notification_data(
    domain_notification: DomainNotification,
) -> Dict[str, Any]:
    return {
        "recipient_id": domain_notification.recipient_id,
        "sender_id": domain_notification.sender_id,
        "notification_type": domain_notification.notification_type,
        "message": domain_notification.message,
        "data": domain_notification.data,
        "is_read": domain_notification.is_read,
    }


def to_domain_notification_data(
    django_notification: Notification,
) -> DomainNotification:
    return DomainNotification(
        id=django_notification.id,
        recipient_id=django_notification.recipient_id,
        sender_id=django_notification.sender_id,
        notification_type=django_notification.notification_type,
        message=django_notification.message,
        data=django_notification.data,
        is_read=django_notification.is_read,
        created_at=django_notification.created_at,
        updated_at=django_notification.updated_at,
    )


def from_domain_preferences_data(
    domain_preferences: DomainNotificationPreferences,
) -> Dict[str, Any]:
    return {
        "user_id": domain_preferences.user_id,
        "post_notifications_enabled": domain_preferences.post_notifications_enabled,
        "follow_notifications_enabled": domain_preferences.follow_notifications_enabled,
        "reply_notifications_enabled": domain_preferences.reply_notifications_enabled,
    }


def to_domain_preferences_data(
    django_preferences: NotificationPreferences,
) -> DomainNotificationPreferences:
    return DomainNotificationPreferences(
        id=django_preferences.id,
        user_id=django_preferences.user_id,
        post_notifications_enabled=django_preferences.post_notifications_enabled,
        follow_notifications_enabled=django_preferences.follow_notifications_enabled,
        reply_notifications_enabled=django_preferences.reply_notifications_enabled,
        created_at=django_preferences.created_at,
        updated_at=django_preferences.updated_at,
    )


class DjangoNotificationRepository(NotificationRepositoryInterface):
    def create(self, notification: DomainNotification) -> DomainNotification:
        django_notification = from_domain_notification_data(notification)

        created_notification = Notification.objects.create(**django_notification)
        return to_domain_notification_data(created_notification)

    def find_by_id(self, notification_id: str) -> DomainNotification | None:
        try:
            django_notification = Notification.objects.get(id=notification_id)
            return to_domain_notification_data(django_notification)
        except Notification.DoesNotExist:
            return None

    def get_user_notifications(
        self, user_id: str, page: int, page_size: int, unread_only: bool = False
    ) -> Tuple[List[Any], str, str]:
        queryset = (
            Notification.objects.filter(recipient_id=user_id)
            .select_related("recipient", "sender")
            .order_by("-created_at")
        )

        if unread_only:
            queryset = queryset.filter(is_read=False)

        total_notifications = queryset.count()
        offset = (page - 1) * page_size
        end = offset + page_size

        notifications = [
            to_domain_notification_data(notification)
            for notification in list(queryset[offset:end])
        ]

        previous_link = None
        if page > 1:
            previous_link = reverse(
                "get-notifications",
                kwargs={"page": page - 1, "page_size": page_size},
            )

        next_link = None
        if end < total_notifications:
            next_link = reverse(
                "get-notifications",
                kwargs={"page": page + 1, "page_size": page_size},
            )

        return notifications, previous_link, next_link

    def mark_as_read(self, notification_ids: List[str], user_id: str) -> None:
        Notification.objects.filter(
            id__in=notification_ids, recipient_id=user_id
        ).update(is_read=True)

    def mark_all_as_read(self, user_id: str) -> None:
        Notification.objects.filter(recipient_id=user_id, is_read=False).update(
            is_read=True
        )

    def get_unread_count(self, user_id: str) -> int:
        return Notification.objects.filter(recipient_id=user_id, is_read=False).count()


class DjangoNotificationPreferencesRepository(
    NotificationPreferencesRepositoryInterface
):
    def create(
        self, preferences: DomainNotificationPreferences
    ) -> DomainNotificationPreferences:
        django_preferences = from_domain_preferences_data(preferences)

        try:
            created_preferences = NotificationPreferences.objects.create(
                **django_preferences
            )
        except IntegrityError:
            raise ConflictError("Notification preferences already exist for this user")

        return to_domain_preferences_data(created_preferences)

    def find_by_user(self, user_id: str) -> DomainNotificationPreferences | None:
        try:
            django_preferences = NotificationPreferences.objects.get(user_id=user_id)
            return to_domain_preferences_data(django_preferences)
        except NotificationPreferences.DoesNotExist:
            return None

    def update(self, preferences: Any, **kwargs) -> DomainNotificationPreferences:
        for key, value in kwargs.items():
            if hasattr(preferences, key):
                setattr(preferences, key, value)

        preferences.save()
        return to_domain_preferences_data(preferences)

    def get_or_create_for_user(self, user_id: str) -> DomainNotificationPreferences:
        try:
            django_preferences = NotificationPreferences.objects.get(user_id=user_id)
            return to_domain_preferences_data(django_preferences)
        except NotificationPreferences.DoesNotExist:
            domain_preferences = DomainNotificationPreferences(user_id=user_id)
            return self.create(domain_preferences)
