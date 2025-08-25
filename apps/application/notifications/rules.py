from dataclasses import asdict
from typing import List

from apps.application.users.ports import (
    UserProfileRepositoryInterface,
    UserRepositoryInterface,
)
from apps.domain.notifications.entities import Notification, NotificationPreferences

from .dtos import (
    CreateNotificationDTO,
    MarkNotificationsReadDTO,
    NotificationListDTO,
    NotificationPreferencesResponseDTO,
    NotificationResponseDTO,
    PaginatedNotificationsResponseDTO,
    UpdateNotificationPreferencesDTO,
)
from .ports import (
    NotificationDispatcherInterface,
    NotificationPreferencesRepositoryInterface,
    NotificationRepositoryInterface,
)


class CreateNotificationRule:
    def __init__(
        self,
        notification_repository: NotificationRepositoryInterface,
        preferences_repository: NotificationPreferencesRepositoryInterface,
        dispatcher: NotificationDispatcherInterface,
    ) -> None:
        self.notification_repository = notification_repository
        self.preferences_repository = preferences_repository
        self.dispatcher = dispatcher

    def __call__(self, dto: CreateNotificationDTO) -> NotificationResponseDTO:
        preferences = self.preferences_repository.get_or_create_for_user(
            dto.recipient_id
        )

        if not self._should_send_notification(preferences, dto.notification_type):
            raise ValueError("User has disabled this type of notification")

        notification = Notification(
            recipient_id=dto.recipient_id,
            sender_id=dto.sender_id,
            notification_type=dto.notification_type,
            message=dto.message,
            data=dto.data,
        )

        created_notification = self.notification_repository.create(notification)

        self.dispatcher.dispatch_notification(created_notification)

        return NotificationResponseDTO(
            **{
                key: value
                for key, value in asdict(created_notification).items()
                if key in NotificationResponseDTO.__dataclass_fields__
            }
        )

    def _should_send_notification(
        self, preferences: NotificationPreferences, notification_type: str
    ) -> bool:
        type_mapping = {
            "post_created": preferences.post_notifications_enabled,
            "post_reply": preferences.reply_notifications_enabled,
            "follow_request": preferences.follow_notifications_enabled,
            "follow_accepted": preferences.follow_notifications_enabled,
        }
        return type_mapping.get(notification_type, True)


class NotifyFollowersOfPostRule:
    def __init__(
        self,
        user_repository: UserRepositoryInterface,
        user_profile_repository: UserProfileRepositoryInterface,
        create_notification_rule: CreateNotificationRule,
    ) -> None:
        self.user_repository = user_repository
        self.user_profile_repository = user_profile_repository
        self.create_notification_rule = create_notification_rule

    def __call__(
        self, post_creator_id: str, post_id: str, post_content: str
    ) -> List[NotificationResponseDTO]:
        user = self.user_repository.find_by_id(post_creator_id)
        # Get all followers of the post creator
        followers, _, _ = self.user_profile_repository.get_followers(
            user_id=post_creator_id,
            page=1,
            page_size=10000000000,  # Large number to get all followers
        )

        notifications = []
        for follow_relationship in followers:
            try:
                notification_dto = CreateNotificationDTO(
                    recipient_id=follow_relationship.user_id,
                    sender_id=post_creator_id,
                    notification_type="post_created",
                    message=f"New post from {user.username}",
                    data={
                        "post_id": post_id,
                        "post_preview": (
                            post_content[:100] + "..."
                            if len(post_content) > 100
                            else post_content
                        ),
                    },
                )
                notification = self.create_notification_rule(notification_dto)
                notifications.append(notification)
            except ValueError:
                # User has disabled notifications - skip
                continue

        return notifications


class NotifyPostCreatorOfReplyRule:
    def __init__(
        self,
        user_repository: UserRepositoryInterface,
        create_notification_rule: CreateNotificationRule,
    ) -> None:
        self.user_repository = user_repository
        self.create_notification_rule = create_notification_rule

    def __call__(
        self,
        post_creator_id: str,
        replier_id: str,
        original_post_id: str,
        reply_id: str,
    ) -> NotificationResponseDTO | None:
        # Don't notify if user is replying to their own post
        if post_creator_id == replier_id:
            return None

        replier = self.user_repository.find_by_id(post_creator_id)

        try:
            notification_dto = CreateNotificationDTO(
                recipient_id=post_creator_id,
                sender_id=replier_id,
                notification_type="post_reply",
                message=f"{replier.username} replied to your post",
                data={"original_post_id": original_post_id, "reply_id": reply_id},
            )
            return self.create_notification_rule(notification_dto)
        except ValueError:
            # User has disabled notifications
            return None


class NotifyUserOfFollowRule:
    def __init__(
        self,
        user_repository: UserRepositoryInterface,
        create_notification_rule: CreateNotificationRule,
    ) -> None:
        self.user_repository = user_repository
        self.create_notification_rule = create_notification_rule

    def __call__(
        self, target_user_id: str, follower_id: str, follow_request_id: str
    ) -> NotificationResponseDTO | None:
        follower = self.user_repository.find_by_id(follower_id)
        try:
            notification_dto = CreateNotificationDTO(
                recipient_id=target_user_id,
                sender_id=follower_id,
                notification_type="follow_request",
                message=f"{follower.username} sent you a follow request",
                data={"follow_request_id": follow_request_id},
            )
            return self.create_notification_rule(notification_dto)
        except ValueError:
            return None


class NotifyUserOfFollowAcceptanceRule:
    def __init__(
        self,
        user_repository: UserRepositoryInterface,
        create_notification_rule: CreateNotificationRule,
    ) -> None:
        self.user_repository = user_repository
        self.create_notification_rule = create_notification_rule

    def __call__(
        self, requester_id: str, accepter_id: str, follow_request_id: str
    ) -> NotificationResponseDTO | None:
        accepter = self.user_repository.find_by_id(accepter_id)

        try:
            notification_dto = CreateNotificationDTO(
                recipient_id=requester_id,
                sender_id=accepter_id,
                notification_type="follow_accepted",
                message=f"{accepter.username} accepted your follow request",
                data={"follow_request_id": follow_request_id},
            )
            return self.create_notification_rule(notification_dto)
        except ValueError:
            return None


class GetUserNotificationsRule:
    def __init__(
        self,
        notification_repository: NotificationRepositoryInterface,
    ) -> None:
        self.notification_repository = notification_repository

    def __call__(self, dto: NotificationListDTO) -> PaginatedNotificationsResponseDTO:
        notifications, previous_link, next_link = (
            self.notification_repository.get_user_notifications(
                user_id=dto.user_id,
                page=dto.page,
                page_size=dto.page_size,
                unread_only=dto.unread_only,
            )
        )

        unread_count = self.notification_repository.get_unread_count(dto.user_id)

        notifications_data = [
            NotificationResponseDTO(
                **{
                    key: value
                    for key, value in asdict(notification).items()
                    if key in NotificationResponseDTO.__dataclass_fields__
                }
            )
            for notification in notifications
        ]

        return PaginatedNotificationsResponseDTO(
            result=notifications_data,
            previous_notifications_data=previous_link,
            next_notifications_data=next_link,
            unread_count=unread_count,
        )


class MarkNotificationsAsReadRule:
    def __init__(
        self,
        notification_repository: NotificationRepositoryInterface,
    ) -> None:
        self.notification_repository = notification_repository

    def __call__(self, dto: MarkNotificationsReadDTO) -> None:
        if dto.notification_ids:
            self.notification_repository.mark_as_read(dto.notification_ids, dto.user_id)
        else:
            self.notification_repository.mark_all_as_read(dto.user_id)


class UpdateNotificationPreferencesRule:
    def __init__(
        self,
        preferences_repository: NotificationPreferencesRepositoryInterface,
    ) -> None:
        self.preferences_repository = preferences_repository

    def __call__(
        self, dto: UpdateNotificationPreferencesDTO
    ) -> NotificationPreferencesResponseDTO:
        preferences = self.preferences_repository.get_or_create_for_user(dto.user_id)

        update_fields = {}
        if dto.post_notifications_enabled:
            update_fields["post_notifications_enabled"] = dto.post_notifications_enabled
        if dto.follow_notifications_enabled:
            update_fields["follow_notifications_enabled"] = (
                dto.follow_notifications_enabled
            )
        if dto.reply_notifications_enabled:
            update_fields["reply_notifications_enabled"] = (
                dto.reply_notifications_enabled
            )

        updated_preferences = self.preferences_repository.update(
            preferences, **update_fields
        )

        return NotificationPreferencesResponseDTO(
            **{
                key: value
                for key, value in asdict(updated_preferences).items()
                if key in NotificationPreferencesResponseDTO.__dataclass_fields__
            }
        )


class GetNotificationPreferencesRule:
    def __init__(
        self,
        preferences_repository: NotificationPreferencesRepositoryInterface,
    ) -> None:
        self.preferences_repository = preferences_repository

    def __call__(self, user_id: str) -> NotificationPreferencesResponseDTO:
        preferences = self.preferences_repository.get_or_create_for_user(user_id)

        return NotificationPreferencesResponseDTO(
            **{
                key: value
                for key, value in asdict(preferences).items()
                if key in NotificationPreferencesResponseDTO.__dataclass_fields__
            }
        )
