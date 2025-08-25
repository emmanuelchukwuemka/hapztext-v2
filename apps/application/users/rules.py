from dataclasses import asdict
from typing import Any, Callable

from loguru import logger

from apps.domain.users.entities import UserFollowing, UserProfile

from .dtos import (
    FollowRequestDTO,
    FollowRequestResponseDTO,
    FriendsListDTO,
    HandleFollowRequestDTO,
    PaginatedFollowersResponseDTO,
    PaginatedFollowingsResponseDTO,
    PaginatedFriendsListResponseDTO,
    PaginatedPendingRequestsResponseDTO,
    PaginatedUserProfileListResponseDTO,
    PendingRequestsDTO,
    UserDetailDTO,
    UserFollowersDTO,
    UserFollowingsDTO,
    UserProfileDetailDTO,
    UserProfileListDTO,
    UserProfileResponseDTO,
    UserResponseDTO,
)
from .ports import (
    UserFollowingRepositoryInterface,
    UserProfileRepositoryInterface,
    UserRepositoryInterface,
)


class FetchUserRule:
    def __init__(
        self,
        user_repository: UserRepositoryInterface,
    ) -> None:
        self.user_repository = user_repository

    def __call__(self, dto: UserDetailDTO) -> UserResponseDTO:
        user = self.user_repository.find_by_id(dto.id)
        if not user:
            raise ValueError(f"User with id '{dto.id}' does not exist.")

        return UserResponseDTO(
            **{
                key: value
                for key, value in asdict(user).items()
                if key in UserResponseDTO.__dataclass_fields__
            }
        )


class UpdateUserRule:
    def __init__(
        self,
        user_repository: UserRepositoryInterface,
    ) -> None:
        self.user_repository = user_repository

    def __call__(self, dto: UserDetailDTO) -> UserResponseDTO:
        user = self.user_repository.find_by_id(dto.id, raw=True)
        if not user:
            raise ValueError(f"User with id '{dto.id}' does not exist.")

        update_fields = {
            key: value
            for key, value in asdict(dto).items()
            if key != "id" and value is not None
        }

        updated_user = self.user_repository.update(user, **update_fields)

        return UserResponseDTO(
            **{
                key: value
                for key, value in asdict(updated_user).items()
                if key in UserResponseDTO.__dataclass_fields__
            }
        )


class CreateUserProfileRule:
    def __init__(self, user_profile_repository: UserProfileRepositoryInterface) -> None:
        self.user_profile_repository = user_profile_repository

    def __call__(self, dto: UserProfileDetailDTO) -> UserProfileResponseDTO:
        if self.user_profile_repository.find_by_user(dto.user_id):
            raise ValueError(
                f"Profile for user with id '{dto.user_id}' already exists."
            )

        user_profile = UserProfile(**asdict(dto))

        created_profile = self.user_profile_repository.create(user_profile)

        return UserProfileResponseDTO(
            **{
                key: value
                for key, value in asdict(created_profile).items()
                if key in UserProfileResponseDTO.__dataclass_fields__
            }
        )


class FetchUserProfileRule:
    def __init__(
        self,
        user_profile_repository: UserProfileRepositoryInterface,
    ) -> None:
        self.user_profile_repository = user_profile_repository

    def __call__(self, dto: UserProfileDetailDTO) -> UserProfileResponseDTO:
        user_profile = self.user_profile_repository.find_by_user(dto.user_id)
        if not user_profile:
            raise ValueError(
                f"Profile for user with id '{dto.user_id}' does not exist."
            )

        return UserProfileResponseDTO(
            **{
                key: value
                for key, value in asdict(user_profile).items()
                if key in UserProfileResponseDTO.__dataclass_fields__
            }
        )


class UpdateUserProfileRule:
    def __init__(self, user_profile_repository: UserProfileRepositoryInterface) -> None:
        self.user_profile_repository = user_profile_repository

    def __call__(self, dto: UserProfileDetailDTO) -> UserProfileResponseDTO:
        user_profile = self.user_profile_repository.find_by_user(dto.user_id)
        if not user_profile:
            raise ValueError(
                f"Profile for user with id '{dto.user_id}' does not exist."
            )

        update_fields = {
            key: value
            for key, value in asdict(dto).items()
            if key != "user_id" and value is not None
        }

        updated_profile = self.user_profile_repository.update(
            user_profile, **update_fields
        )

        return UserProfileResponseDTO(
            **{
                key: value
                for key, value in asdict(updated_profile).items()
                if key in UserProfileResponseDTO.__dataclass_fields__
            }
        )


class UserProfileListRule:
    def __init__(self, user_profile_repository: UserProfileRepositoryInterface) -> None:
        self.user_profile_repository = user_profile_repository

    def __call__(self, dto: UserProfileListDTO) -> PaginatedUserProfileListResponseDTO:
        profiles, previous_link, next_link = self.user_profile_repository.profiles_list(
            page=dto.page, page_size=dto.page_size
        )

        profiles_data = [
            UserProfileResponseDTO(
                **{
                    key: value
                    for key, value in asdict(profile).items()
                    if key in UserProfileResponseDTO.__dataclass_fields__
                }
            )
            for profile in profiles
        ]

        return PaginatedUserProfileListResponseDTO(
            result=profiles_data,
            previous_profiles_data=previous_link,
            next_profiles_data=next_link,
        )


class SendFollowRequestRule:
    def __init__(
        self,
        user_following_repository: UserFollowingRepositoryInterface,
        user_profile_repository: UserProfileRepositoryInterface,
    ):
        self.user_following_repository = user_following_repository
        self.user_profile_repository = user_profile_repository

    def __call__(self, dto: FollowRequestDTO) -> FollowRequestResponseDTO:
        if dto.requester_id == dto.target_id:
            raise ValueError("Users cannot send follow requests to themselves.")

        requester_profile = self.user_profile_repository.find_by_user(dto.requester_id)
        target_profile = self.user_profile_repository.find_by_user(dto.target_id)

        if not requester_profile or not target_profile:
            raise ValueError(
                "Both users must have profiles to send/receive follow requests."
            )

        existing_request = self.user_following_repository.find_existing_request(
            dto.requester_id, dto.target_id
        )

        if existing_request:
            if existing_request.status == "pending":
                raise ValueError("A follow request is already pending.")
            elif existing_request.status == "accepted":
                raise ValueError("You are already following this user.")

        user_following = UserFollowing(
            follower_id=dto.requester_id, following_id=dto.target_id, status="pending"
        )

        created_request = self.user_following_repository.create(user_following)

        return FollowRequestResponseDTO(
            requester_id=created_request.follower_id,
            target_id=created_request.following_id,
            **{
                key: value
                for key, value in asdict(created_request).items()
                if key in FollowRequestResponseDTO.__dataclass_fields__
            },
        )


class HandleFollowRequestRule:
    def __init__(
        self,
        user_following_repository: UserFollowingRepositoryInterface,
    ):
        self.user_following_repository = user_following_repository

    def __call__(self, dto: HandleFollowRequestDTO) -> FollowRequestResponseDTO:
        follow_request = self.user_following_repository.find_by_id(dto.request_id)

        if not follow_request:
            raise ValueError("Follow request not found.")

        if follow_request.following_id != dto.user_id:
            raise ValueError("You can only handle requests sent to you.")

        if follow_request.status != "pending":
            raise ValueError("This request has already been handled.")

        updated_request = self.user_following_repository.update_status(
            dto.request_id, dto.action
        )

        return FollowRequestResponseDTO(
            requester_id=updated_request.follower_id,
            target_id=updated_request.following_id,
            **{
                key: value
                for key, value in asdict(updated_request).items()
                if key in FollowRequestResponseDTO.__dataclass_fields__
            },
        )


class GetPendingRequestsRule:
    def __init__(
        self,
        user_following_repository: UserFollowingRepositoryInterface,
    ):
        self.user_following_repository = user_following_repository

    def __call__(self, dto: PendingRequestsDTO) -> PaginatedPendingRequestsResponseDTO:
        received_requests, received_previous, received_next = (
            self.user_following_repository.get_received_requests(
                dto.user_id, dto.page, dto.page_size, status="pending"
            )
        )
        sent_requests, sent_previous, sent_next = (
            self.user_following_repository.get_sent_requests(
                dto.user_id, dto.page, dto.page_size, status="pending"
            )
        )

        return PaginatedPendingRequestsResponseDTO(
            received_requests=[
                FollowRequestResponseDTO(
                    requester_id=req.follower_id,
                    target_id=req.following_id,
                    **{
                        key: value
                        for key, value in asdict(req).items()
                        if key in FollowRequestResponseDTO.__dataclass_fields__
                    },
                )
                for req in received_requests
            ],
            sent_requests=[
                FollowRequestResponseDTO(
                    requester_id=req.follower_id,
                    target_id=req.following_id,
                    **{
                        key: value
                        for key, value in asdict(req).items()
                        if key in FollowRequestResponseDTO.__dataclass_fields__
                    },
                )
                for req in sent_requests
            ],
            previous_requests_data=received_previous or sent_previous,
            next_requests_data=received_next or sent_next,
        )


class GetFriendsListRule:
    def __init__(
        self,
        user_following_repository: UserFollowingRepositoryInterface,
        user_profile_repository: UserProfileRepositoryInterface,
    ):
        self.user_following_repository = user_following_repository
        self.user_profile_repository = user_profile_repository

    def __call__(self, dto: FriendsListDTO) -> PaginatedFriendsListResponseDTO:
        friends, previous_friends, next_friends = (
            self.user_following_repository.get_mutual_followers(
                dto.user_id, dto.page, dto.page_size
            )
        )

        friends_profiles = []
        for friend in friends:
            profile = self.user_profile_repository.find_by_user(friend.follower_id)
            if profile:
                friends_profiles.append(
                    UserProfileResponseDTO(
                        **{
                            key: value
                            for key, value in asdict(profile).items()
                            if key in UserProfileResponseDTO.__dataclass_fields__
                        }
                    )
                )

        return PaginatedFriendsListResponseDTO(
            friends=friends_profiles,
            previous_friends_data=previous_friends,
            next_friends_data=next_friends,
        )


class GetUserFollowersRule:
    def __init__(
        self,
        user_profile_repository: UserProfileRepositoryInterface,
    ):
        self.user_profile_repository = user_profile_repository

    def __call__(self, dto: UserFollowersDTO) -> PaginatedFollowersResponseDTO:
        followers, previous_link, next_link = (
            self.user_profile_repository.get_followers(
                dto.user_id, dto.page, dto.page_size
            )
        )

        followers_data = [
            UserProfileResponseDTO(
                **{
                    key: value
                    for key, value in asdict(follower).items()
                    if key in UserProfileResponseDTO.__dataclass_fields__
                }
            )
            for follower in followers
        ]

        return PaginatedFollowersResponseDTO(
            followers=followers_data,
            previous_followers_data=previous_link,
            next_followers_data=next_link,
        )


class GetUserFollowingsRule:
    def __init__(
        self,
        user_profile_repository: UserProfileRepositoryInterface,
    ):
        self.user_profile_repository = user_profile_repository

    def __call__(self, dto: UserFollowingsDTO) -> PaginatedFollowingsResponseDTO:
        followings, previous_link, next_link = (
            self.user_profile_repository.get_followings(
                dto.user_id, dto.page, dto.page_size
            )
        )

        followings_data = [
            UserProfileResponseDTO(
                **{
                    key: value
                    for key, value in asdict(following).items()
                    if key in UserProfileResponseDTO.__dataclass_fields__
                }
            )
            for following in followings
        ]

        return PaginatedFollowingsResponseDTO(
            followings=followings_data,
            previous_followings_data=previous_link,
            next_followings_data=next_link,
        )
