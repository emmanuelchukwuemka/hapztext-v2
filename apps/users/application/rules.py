from dataclasses import asdict

from ..domain.entities import UserFollowing, UserProfile
from .dtos import (
    FollowUserDTO,
    PaginatedUserProfileListResponseDTO,
    UserDetailDTO,
    UserFollowingResponseDTO,
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

    def execute(self, dto: UserDetailDTO) -> UserResponseDTO:
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

    def execute(self, dto: UserDetailDTO) -> UserResponseDTO:
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

    def execute(self, dto: UserProfileDetailDTO) -> UserProfileResponseDTO:
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

    def execute(self, dto: UserProfileDetailDTO) -> UserResponseDTO:
        user_profile = self.user_profile_repository.find_by_user(dto.user_id)
        if not user_profile:
            raise ValueError(f"Profile for user with id '{dto.user_id}' does not exist.")

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

    def execute(self, dto: UserProfileDetailDTO) -> UserProfileResponseDTO:
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

        updated_profile = self.user_repository.update(user_profile, **update_fields)

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

    def execute(self, dto: UserProfileListDTO) -> PaginatedUserProfileListResponseDTO:
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
        user_profile_repository: UserProfileRepositoryInterface,
        user_following_repository: UserFollowingRepositoryInterface,
    ):
        self.user_profile_repository = user_profile_repository
        self.user_following_repository = user_following_repository

    def execute(self, dto: FollowUserDTO) -> UserFollowingResponseDTO:
        if not self.user_profile_repository.find_by_user(
            dto.follower_id
        ) or not self.user_profile_repository.find_by_user(dto.following_id):
            raise ValueError(
                "Following relationship cannot be created for an invalid user."
            )

        user_following = UserFollowing(**asdict(dto))

        created_following = self.user_following_repository.create(user_following)

        return UserFollowingResponseDTO(
            **{
                key: value
                for key, value in asdict(created_following).items()
                if key in UserFollowingResponseDTO.__dataclass_fields__
            }
        )
