from ...users.application.rules import (
    CreateUserProfileRule,
    FetchUserProfileRule,
    FetchUserRule,
    GetFriendsListRule,
    GetPendingRequestsRule,
    HandleFollowRequestRule,
    SendFollowRequestRule,
    UpdateUserRule,
    UserProfileListRule,
)
from ...users.infrastructure.repositories import (
    DjangoUserFollowingRepository,
    DjangoUserProfileRepository,
    DjangoUserRepository,
)


def get_user_repository() -> DjangoUserRepository:
    return DjangoUserRepository()


def get_user_profile_repository() -> DjangoUserProfileRepository:
    return DjangoUserProfileRepository()


def get_user_following_repository() -> DjangoUserFollowingRepository:
    return DjangoUserFollowingRepository()


def fetch_user_rule() -> FetchUserRule:
    return FetchUserRule(user_repository=get_user_repository())


def create_user_profile_rule() -> CreateUserProfileRule:
    return CreateUserProfileRule(user_profile_repository=get_user_profile_repository())


def fetch_user_profile_rule() -> FetchUserProfileRule:
    return FetchUserProfileRule(user_profile_repository=get_user_profile_repository())


def user_profile_list_rule() -> UserProfileListRule:
    return UserProfileListRule(user_profile_repository=get_user_profile_repository())


def update_user_rule() -> UpdateUserRule:
    return UpdateUserRule(user_repository=get_user_repository())


def send_follow_request_rule() -> SendFollowRequestRule:
    return SendFollowRequestRule(
        user_following_repository=get_user_following_repository(),
        user_profile_repository=get_user_profile_repository(),
    )


def handle_follow_request_rule() -> HandleFollowRequestRule:
    return HandleFollowRequestRule(
        user_following_repository=get_user_following_repository(),
    )


def get_pending_requests_rule() -> GetPendingRequestsRule:
    return GetPendingRequestsRule(
        user_following_repository=get_user_following_repository(),
    )


def get_friends_list_rule() -> GetFriendsListRule:
    return GetFriendsListRule(
        user_following_repository=get_user_following_repository(),
        user_profile_repository=get_user_profile_repository(),
    )
