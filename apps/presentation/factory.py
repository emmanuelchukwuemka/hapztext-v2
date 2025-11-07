from apps.application.authentication.rules import (
    EmailOTPRequestRule,
    LoginRule,
    LogoutRule,
    RegisterRule,
    ResetPasswordRule,
    VerifyEmailRule,
)
from apps.application.notifications.rules import (
    CreateNotificationRule,
    GetNotificationPreferencesRule,
    GetUserNotificationsRule,
    MarkNotificationsAsReadRule,
    NotifyFollowersOfPostRule,
    NotifyPostCreatorOfReplyRule,
    NotifyUserOfFollowRule,
    UpdateNotificationPreferencesRule,
)
from apps.application.posts.rules import (
    CreatePostRule,
    DeletePostRule,
    FetchRepliesRule,
    GetPostReactorsRule,
    PostListRule,
    PublishScheduledPostsRule,
    ReactToPostRule,
    RemoveReactionRule,
    SharePostRule,
    UserPostsRule,
)
from apps.application.users.rules import (
    CreateUserProfileRule,
    FetchUserProfileRule,
    FetchUserRule,
    GetFriendsListRule,
    GetUserFollowersRule,
    GetUserFollowingsRule,
    SearchFriendsRule,
    FollowUserRule,
    UpdateUserRule,
    UserProfileListRule,
    SearchUserRule,
)
from apps.infrastructure.authentication.repositories import DjangoOTPCodeRepository
from apps.infrastructure.authentication.services import (
    DjangoEmailServiceAdapter,
    KnoxAuthenticationServiceAdapter,
)
from apps.infrastructure.notifications.repositories import (
    DjangoNotificationPreferencesRepository,
    DjangoNotificationRepository,
)
from apps.infrastructure.notifications.services import (
    NotificationDispatcher,
    SSENotificationService,
)
from apps.infrastructure.password_service import (
    hash_password,
    password_check,
    validate_password,
)
from apps.infrastructure.posts.repositories import (
    DjangoPostReactionRepository,
    DjangoPostRepository,
    DjangoPostShareRepository,
    DjangoPostTagRepository,
)
from apps.infrastructure.users.repositories import (
    DjangoUserFollowingRepository,
    DjangoUserProfileRepository,
    DjangoUserRepository,
)
from apps.application.chat.rules import (
    CreateConversationRule,
    SendMessageRule,
    GetConversationMessagesRule,
    GetUserConversationsRule,
    MarkMessagesAsReadRule,
)
from apps.infrastructure.chat.repositories import (
    DjangoConversationRepository,
    DjangoMessageRepository,
    DjangoConversationParticipantRepository,
)
from apps.infrastructure.chat.services import ChannelsChatService

from apps.infrastructure.users.models import UserMentionCount


def get_user_repository() -> DjangoUserRepository:
    return DjangoUserRepository()


def get_user_profile_repository() -> DjangoUserProfileRepository:
    return DjangoUserProfileRepository()


def get_user_following_repository() -> DjangoUserFollowingRepository:
    return DjangoUserFollowingRepository()


def fetch_user_rule() -> FetchUserRule:
    return FetchUserRule(user_repository=get_user_repository())


def search_users_rule() -> SearchUserRule:
    return SearchUserRule(user_repository=get_user_repository())


def create_user_profile_rule() -> CreateUserProfileRule:
    return CreateUserProfileRule(user_profile_repository=get_user_profile_repository())


def fetch_user_profile_rule() -> FetchUserProfileRule:
    return FetchUserProfileRule(user_profile_repository=get_user_profile_repository())


def user_profile_list_rule() -> UserProfileListRule:
    return UserProfileListRule(user_profile_repository=get_user_profile_repository())


def update_user_rule() -> UpdateUserRule:
    return UpdateUserRule(user_repository=get_user_repository())


def send_follow_request_rule() -> FollowUserRule:
    return FollowUserRule(
        user_following_repository=get_user_following_repository(),
        user_profile_repository=get_user_profile_repository(),
    )


def get_friends_list_rule() -> GetFriendsListRule:
    return GetFriendsListRule(
        user_following_repository=get_user_following_repository(),
        user_profile_repository=get_user_profile_repository(),
    )


def get_user_followers_rule() -> GetUserFollowersRule:
    return GetUserFollowersRule(
        user_profile_repository=get_user_profile_repository(),
    )


def get_user_followings_rule() -> GetUserFollowingsRule:
    return GetUserFollowingsRule(
        user_profile_repository=get_user_profile_repository(),
    )


def get_email_service() -> DjangoEmailServiceAdapter:
    return DjangoEmailServiceAdapter()


def get_otp_code_repository() -> DjangoOTPCodeRepository:
    return DjangoOTPCodeRepository()


def get_authentication_service() -> KnoxAuthenticationServiceAdapter:
    return KnoxAuthenticationServiceAdapter()


def get_register_rule() -> RegisterRule:
    return RegisterRule(
        user_repository=get_user_repository(),
        validate_password=validate_password,
        hash_password=hash_password,
    )


def get_email_otp_request_rule() -> EmailOTPRequestRule:
    return EmailOTPRequestRule(
        user_repository=get_user_repository(),
        otp_code_repository=get_otp_code_repository(),
        email_service=get_email_service(),
    )


def get_login_rule() -> LoginRule:
    return LoginRule(
        user_repository=get_user_repository(),
        check_password=password_check,
        authentication_service=get_authentication_service(),
    )


def get_logout_rule() -> LogoutRule:
    return LogoutRule(
        authentication_service=get_authentication_service(),
    )


def get_reset_password_rule() -> ResetPasswordRule:
    return ResetPasswordRule(
        otp_code_repository=get_otp_code_repository(),
        user_repository=get_user_repository(),
        validate_password=validate_password,
        hash_password=hash_password,
    )


def get_verify_email_rule() -> VerifyEmailRule:
    return VerifyEmailRule(
        user_repository=get_user_repository(),
        otp_code_repository=get_otp_code_repository(),
    )


def get_post_repository() -> DjangoPostRepository:
    return DjangoPostRepository()


def get_post_reaction_repository() -> DjangoPostReactionRepository:
    return DjangoPostReactionRepository()


def get_post_share_repository() -> DjangoPostShareRepository:
    return DjangoPostShareRepository()


def get_post_tag_repository() -> DjangoPostTagRepository:
    return DjangoPostTagRepository()


def create_post_rule() -> CreatePostRule:
    return CreatePostRule(
        post_repository=get_post_repository(),
        post_tag_repository=get_post_tag_repository(),
        user_mention_count_model=UserMentionCount,
    )


def delete_post_rule() -> DeletePostRule:
    return DeletePostRule(
        post_repository=get_post_repository(),
    )


def fetch_replies_rule() -> FetchRepliesRule:
    return FetchRepliesRule(
        post_repository=get_post_repository(),
        post_reaction_repository=get_post_reaction_repository(),
        post_share_repository=get_post_share_repository(),
    )


def posts_list_rule() -> PostListRule:
    return PostListRule(
        post_repository=get_post_repository(),
        post_reaction_repository=get_post_reaction_repository(),
        post_share_repository=get_post_share_repository(),
    )


def user_posts_rule() -> UserPostsRule:
    return UserPostsRule(
        post_repository=get_post_repository(),
        post_reaction_repository=get_post_reaction_repository(),
        post_share_repository=get_post_share_repository(),
    )


def react_to_post_rule() -> ReactToPostRule:
    return ReactToPostRule(
        post_reaction_repository=get_post_reaction_repository(),
    )


def remove_reaction_rule() -> RemoveReactionRule:
    return RemoveReactionRule(
        post_reaction_repository=get_post_reaction_repository(),
    )


def get_post_friend_reactors_rule() -> GetPostReactorsRule:
    return GetPostReactorsRule(
        post_reaction_repository=get_post_reaction_repository(),
        user_following_repository=get_user_following_repository(),
    )


def share_post_rule() -> SharePostRule:
    return SharePostRule(
        post_share_repository=get_post_share_repository(),
    )


def search_friends_rule() -> SearchFriendsRule:
    return SearchFriendsRule(
        user_following_repository=get_user_following_repository(),
    )


def publish_scheduled_posts_rule() -> PublishScheduledPostsRule:
    return PublishScheduledPostsRule(
        post_repository=get_post_repository(),
    )


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


def get_conversation_repository() -> DjangoConversationRepository:
    return DjangoConversationRepository()


def get_message_repository() -> DjangoMessageRepository:
    return DjangoMessageRepository()


def get_conversation_participant_repository() -> (
    DjangoConversationParticipantRepository
):
    return DjangoConversationParticipantRepository()


def get_chat_service() -> ChannelsChatService:
    return ChannelsChatService()


def get_create_conversation_rule() -> CreateConversationRule:
    return CreateConversationRule(
        conversation_repository=get_conversation_repository(),
        participant_repository=get_conversation_participant_repository(),
    )


def get_send_message_rule() -> SendMessageRule:
    return SendMessageRule(
        message_repository=get_message_repository(),
        conversation_repository=get_conversation_repository(),
        participant_repository=get_conversation_participant_repository(),
        chat_service=get_chat_service(),
    )


def get_conversation_messages_rule() -> GetConversationMessagesRule:
    return GetConversationMessagesRule(
        message_repository=get_message_repository(),
        participant_repository=get_conversation_participant_repository(),
    )


def get_user_conversations_rule() -> GetUserConversationsRule:
    return GetUserConversationsRule(
        conversation_repository=get_conversation_repository(),
        message_repository=get_message_repository(),
    )


def get_mark_messages_read_rule() -> MarkMessagesAsReadRule:
    return MarkMessagesAsReadRule(
        message_repository=get_message_repository(),
        participant_repository=get_conversation_participant_repository(),
    )
