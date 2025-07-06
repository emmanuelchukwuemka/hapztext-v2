from typing import Any, Dict, List, Tuple

from django.urls import reverse
from django.db import IntegrityError

from ..application.ports import (
    UserFollowingRepositoryInterface,
    UserProfileRepositoryInterface,
    UserRepositoryInterface,
)
from ..domain.entities import User as DomainUser
from ..domain.entities import UserFollowing as DomainUserFollowing
from ..domain.entities import UserProfile as DomainUserProfile
from ..infrastructure.models import User, UserFollowing, UserProfile

from core.infrastructure.exceptions import ConflictError


class DjangoUserRepository(UserRepositoryInterface):
    def create(self, user: DomainUser) -> DomainUser:
        django_user = self._to_django_user_data(user)

        created_user = User.objects.create_user(**django_user)
        return self._to_domain_user_data(created_user)

    def update(self, user: Any, **extras) -> DomainUser:
        for key, value in extras.items():
            if hasattr(user, key):
                setattr(user, key, value)

        user.save()
        return self._to_domain_user_data(user)

    def find_by_email(self, email: str, raw: bool = False) -> Any:
        try:
            django_user = User.objects.get(email=email)

            if raw:
                return django_user
            else:
                return self._to_domain_user_data(django_user)

        except User.DoesNotExist:
            return None

    def find_by_id(self, id: str, raw: bool = False) -> Any:
        try:
            django_user = User.objects.get(id=id)

            if raw:
                return django_user
            else:
                return self._to_domain_user_data(django_user)

        except User.DoesNotExist:
            return None

    def _to_django_user_data(self, domain_user: DomainUser) -> Dict[str, Any]:
        return {
            "email": domain_user.email,
            "username": domain_user.username,
            "password": domain_user.hashed_password,
            "is_email_verified": domain_user.is_email_verified,
            "is_active": domain_user.is_active,
        }

    def _to_domain_user_data(self, django_user: User) -> DomainUser:
        return DomainUser(
            email=django_user.email,
            username=django_user.username,
            hashed_password=django_user.password,
            is_email_verified=django_user.is_email_verified,
            is_active=django_user.is_active,
            id=django_user.id,
            created_at=django_user.created_at,
            updated_at=django_user.updated_at,
        )


class DjangoUserProfileRepository(UserProfileRepositoryInterface):
    def create(self, user_profile: DomainUserProfile) -> DomainUserProfile:
        django_user_profile = self._to_django_user_profile_data(user_profile)

        created_user_profile = UserProfile.objects.create(**django_user_profile)
        return self._to_domain_user_profile_data(created_user_profile)

    def update(self, user_profile: Any, **extras) -> DomainUserProfile:
        for key, value in extras.items():
            if hasattr(user_profile, key):
                setattr(user_profile, key, value)

        user_profile.save()
        return self._to_domain_user_profile_data(user_profile)

    def find_by_user(self, user_id: str, raw: bool = False) -> Any:
        try:
            django_user_profile = UserProfile.objects.get(user_id=user_id)

            if raw:
                return django_user_profile
            else:
                return self._to_domain_user_profile_data(django_user_profile)

        except UserProfile.DoesNotExist:
            return None

    def profiles_list(self, page: int, page_size: int) -> Tuple[List[Any], str, str]:
        queryset = UserProfile.objects.all().order_by("-created_at")
        total_profiles = queryset.count()

        offset = (page - 1) * page_size
        end = offset + page_size

        profiles = [self._to_domain_user_profile_data(qs) for qs in list(queryset[offset:end])]

        previous_link = None
        if page > 1:
            previous_link = reverse("fetch-profiles-list", kwargs={"page": page - 1, "page_size": page_size})

        next_link = None
        if end < total_profiles:
            next_link = reverse("fetch-profiles-list", kwargs={"page": page + 1, "page_size": page_size})

        return profiles, previous_link, next_link

    def _to_django_user_profile_data(
        self, domain_user_profile: DomainUserProfile
    ) -> Dict[str, Any]:
        return {
            "user_id": domain_user_profile.user_id,
            "first_name": domain_user_profile.first_name,
            "last_name": domain_user_profile.last_name,
            "profile_picture": domain_user_profile.profile_picture,
            "bio": domain_user_profile.bio,
            "birth_date": domain_user_profile.birth_date,
            "occupation": domain_user_profile.occupation,
            "height": domain_user_profile.height,
            "weight": domain_user_profile.weight,
            "ethnicity": domain_user_profile.ethnicity,
            "relationship_status": domain_user_profile.relationship_status,
        }

    def _to_domain_user_profile_data(
        self, django_user_profile: UserProfile
    ) -> DomainUserProfile:
        following_ids = list(django_user_profile.following.values_list("id", flat=True))
        follower_ids = list(django_user_profile.followers.values_list("id", flat=True))

        return DomainUserProfile(
            id=django_user_profile.id,
            user_id=django_user_profile.user_id,
            first_name=django_user_profile.first_name,
            last_name=django_user_profile.last_name,
            profile_picture=django_user_profile.profile_picture.name,
            bio=django_user_profile.bio,
            birth_date=django_user_profile.birth_date,
            occupation=django_user_profile.occupation,
            height=django_user_profile.height,
            weight=django_user_profile.weight,
            ethnicity=django_user_profile.ethnicity,
            relationship_status=django_user_profile.relationship_status,
            following_ids=following_ids,
            follower_ids=follower_ids,
            created_at=django_user_profile.created_at,
            updated_at=django_user_profile.updated_at,
        )


class DjangoUserFollowingRepository(UserFollowingRepositoryInterface):
    def create(self, user_following: DomainUserFollowing) -> DomainUserFollowing:
        django_user_following = self._to_django_user_following_data(user_following)

        try:
            created_user_following = UserFollowing.objects.create(**django_user_following)
        except IntegrityError as e:
            if "UNIQUE constraint failed: user_following.follower_id, user_following.following_id" in str(e):
                raise ConflictError("You already follow this user.")
            
        return self._to_domain_user_following_data(created_user_following)
    
    def _to_django_user_following_data(
        self, domain_user_following: DomainUserFollowing
    ) -> Dict[str, Any]:
        try:
            follower_profile = UserProfile.objects.get(user_id=domain_user_following.follower_id)
            following_profile = UserProfile.objects.get(user_id=domain_user_following.following_id)
            return {
                "follower": follower_profile,
                "following": following_profile,
            }
        except UserProfile.DoesNotExist:
            raise ValueError("Following relationship cannot be created for a user without a profile.")


    def _to_domain_user_following_data(
        self, django_user_following: UserFollowing
    ) -> Any:
        return DomainUserFollowing(
            id=django_user_following.id,
            follower_id=django_user_following.follower_id,
            following_id=django_user_following.following_id,
            created_at=django_user_following.created_at,
        )
