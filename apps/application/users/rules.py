from dataclasses import asdict

from apps.domain.users.entities import UserFollowing, UserProfile

from .dtos import (
    FollowRequestDTO,
    FollowRequestResponseDTO,
    UserSearchDTO,
    FriendSearchDTO,
    SearchResponseDTO,
    FriendsListDTO,
    PaginatedFollowersResponseDTO,
    PaginatedFollowingsResponseDTO,
    PaginatedFriendsListResponseDTO,
    PaginatedUserProfileListResponseDTO,
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


class SearchUserRule:
    def __init__(
        self,
        user_repository: UserRepositoryInterface,
    ) -> None:
        self.user_repository = user_repository

    def __call__(self, dto: UserSearchDTO) -> SearchResponseDTO:
        query_lower = dto.query.lower().strip("@")

        users, previous_link, next_link = self.user_repository.search(
            query_lower, page=dto.offset, page_size=dto.limit
        )

        users_data = [
            UserResponseDTO(
                **{
                    key: value
                    for key, value in asdict(user).items()
                    if key in UserResponseDTO.__dataclass_fields__
                }
            )
            for user in users
        ]

        return SearchResponseDTO(
            users=users_data,
            previous_search_data=previous_link,
            next_search_data=next_link,
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

        user_profile = UserProfile(
            user_id=dto.user_id,
            birth_date=dto.birth_date,
            ethnicity=dto.ethnicity,
            relationship_status=dto.relationship_status,
            first_name=dto.first_name,
            last_name=dto.last_name,
            bio=dto.bio,
            occupation=dto.occupation,
            profile_picture=dto.profile_picture,
            location=dto.location,
            height=dto.height,
            weight=dto.weight,
        )

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


class FollowUserRule:
    def __init__(
        self,
        user_following_repository: UserFollowingRepositoryInterface,
        user_profile_repository: UserProfileRepositoryInterface,
    ):
        self.user_following_repository = user_following_repository
        self.user_profile_repository = user_profile_repository

    def __call__(self, dto: FollowRequestDTO) -> FollowRequestResponseDTO:
        if dto.requester_id == dto.target_id:
            raise ValueError("Users cannot follow themselves.")

        user_following = UserFollowing(
            follower_id=dto.requester_id, following_id=dto.target_id
        )

        new_follow_relationship = self.user_following_repository.create(user_following)

        return FollowRequestResponseDTO(
            requester_id=new_follow_relationship.follower_id,
            target_id=new_follow_relationship.following_id,
            **{
                key: value
                for key, value in asdict(new_follow_relationship).items()
                if key in FollowRequestResponseDTO.__dataclass_fields__
            },
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


class SearchFriendsRule:
    def __init__(
        self,
        user_following_repository: UserFollowingRepositoryInterface,
    ) -> None:
        self.user_following_repository = user_following_repository

    def __call__(self, dto: FriendSearchDTO) -> SearchResponseDTO:
        friends, previous_link, next_link = (
            self.user_following_repository.get_mutual_followers(
                user_id=dto.user_id,
                page=dto.offset,
                page_size=dto.limit,
                query=dto.query,
            )
        )

        matching_friends = []
        query_lower = dto.query.lower().strip("@")

        for friend in friends:
            if hasattr(friend, "username") and friend.username.lower().startswith(
                query_lower
            ):
                matching_friends.append(
                    {
                        "id": (
                            friend.user_id
                            if hasattr(friend, "user_id")
                            else friend.follower_id
                        ),
                        "username": (
                            f"@{friend.username}"
                            if hasattr(friend, "username")
                            else f"@{friend.user_id}"
                        ),
                    }
                )

        return SearchResponseDTO(
            users=matching_friends,
            previous_search_data=previous_link,
            next_search_data=next_link,
        )
