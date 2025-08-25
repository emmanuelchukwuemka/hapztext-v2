from typing import Any, Dict, List, Tuple

from django.db import IntegrityError
from django.urls import reverse

from apps.application.users.ports import (
    UserFollowingRepositoryInterface,
    UserProfileRepositoryInterface,
    UserRepositoryInterface,
)
from apps.core.exceptions import ConflictError
from apps.domain.users.entities import User as DomainUser
from apps.domain.users.entities import UserFollowing as DomainUserFollowing
from apps.domain.users.entities import UserProfile as DomainUserProfile

from .models.tables import User, UserFollowing, UserProfile


def from_domain_user_data(domain_user: DomainUser) -> Dict[str, Any]:
    return {
        "email": domain_user.email,
        "username": domain_user.username,
        "password": domain_user.hashed_password,
        "is_email_verified": domain_user.is_email_verified,
        "is_active": domain_user.is_active,
    }


def to_domain_user_data(django_user: User) -> DomainUser:
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


def from_domain_user_profile_data(
    domain_user_profile: DomainUserProfile,
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


def to_domain_user_profile_data(django_user_profile: UserProfile) -> DomainUserProfile:
    return DomainUserProfile(
        id=django_user_profile.id,
        user_id=django_user_profile.user_id,
        first_name=django_user_profile.first_name,
        last_name=django_user_profile.last_name,
        profile_picture=(
            django_user_profile.profile_picture.name
            if django_user_profile.profile_picture
            else None
        ),
        bio=django_user_profile.bio,
        birth_date=django_user_profile.birth_date,
        occupation=django_user_profile.occupation,
        height=django_user_profile.height,
        weight=django_user_profile.weight,
        ethnicity=django_user_profile.ethnicity,
        relationship_status=django_user_profile.relationship_status,
        created_at=django_user_profile.created_at,
        updated_at=django_user_profile.updated_at,
    )


def from_domain_user_following_data(
    domain_user_following: DomainUserFollowing,
) -> Dict[str, Any]:
    try:
        follower_profile = UserProfile.objects.get(
            user_id=domain_user_following.follower_id
        )
        following_profile = UserProfile.objects.get(
            user_id=domain_user_following.following_id
        )
        return {
            "follower": follower_profile,
            "following": following_profile,
            "status": domain_user_following.status,
        }
    except UserProfile.DoesNotExist:
        raise ValueError(
            "Following relationship cannot be created for a user without a profile."
        )


def to_domain_user_following_data(
    django_user_following: UserFollowing,
) -> DomainUserFollowing:
    return DomainUserFollowing(
        id=django_user_following.id,
        follower_id=django_user_following.follower.user_id,
        following_id=django_user_following.following.user_id,
        status=django_user_following.status,
        created_at=django_user_following.created_at,
        updated_at=django_user_following.updated_at,
    )


class DjangoUserRepository(UserRepositoryInterface):
    def create(self, user: DomainUser) -> DomainUser:
        django_user = from_domain_user_data(user)

        created_user = User.objects.create_user(**django_user)
        return to_domain_user_data(created_user)

    def update(self, user: Any, **extras) -> DomainUser:
        for key, value in extras.items():
            if hasattr(user, key):
                setattr(user, key, value)

        user.save()
        return to_domain_user_data(user)

    def find_by_email(self, email: str, raw: bool = False) -> Any:
        try:
            django_user = User.objects.get(email=email)

            if raw:
                return django_user
            else:
                return to_domain_user_data(django_user)

        except User.DoesNotExist:
            return None

    def find_by_id(self, id: str, raw: bool = False) -> Any:
        try:
            django_user = User.objects.get(id=id)

            if raw:
                return django_user
            else:
                return to_domain_user_data(django_user)

        except User.DoesNotExist:
            return None


class DjangoUserProfileRepository(UserProfileRepositoryInterface):
    def create(self, user_profile: DomainUserProfile) -> DomainUserProfile:
        django_user_profile = from_domain_user_profile_data(user_profile)

        created_user_profile = UserProfile.objects.create(**django_user_profile)
        return to_domain_user_profile_data(created_user_profile)

    def update(self, user_profile: Any, **extras) -> DomainUserProfile:
        for key, value in extras.items():
            if hasattr(user_profile, key):
                setattr(user_profile, key, value)

        user_profile.save()
        return to_domain_user_profile_data(user_profile)

    def find_by_user(self, user_id: str, raw: bool = False) -> Any:
        try:
            django_user_profile = UserProfile.objects.get(user_id=user_id)

            if raw:
                return django_user_profile
            else:
                return to_domain_user_profile_data(django_user_profile)

        except UserProfile.DoesNotExist:
            return None

    def profiles_list(
        self, page: int, page_size: int
    ) -> Tuple[List[Any], str | None, str | None]:
        queryset = (
            UserProfile.objects.all().select_related("user").order_by("-created_at")
        )
        total_profiles = queryset.count()

        offset = (page - 1) * page_size
        end = offset + page_size

        profiles = [
            to_domain_user_profile_data(qs) for qs in list(queryset[offset:end])
        ]

        previous_link = None
        if page > 1:
            previous_link = reverse(
                "fetch-profiles-list", kwargs={"page": page - 1, "page_size": page_size}
            )

        next_link = None
        if end < total_profiles:
            next_link = reverse(
                "fetch-profiles-list", kwargs={"page": page + 1, "page_size": page_size}
            )

        return profiles, previous_link, next_link

    def get_followers(
        self, user_id: str, page: int, page_size: int
    ) -> Tuple[List[Any], str | None, str | None]:
        """Get profiles of users who follow the given user"""
        followers_queryset = (
            UserProfile.objects.filter(
                following_set__following__user_id=user_id,
                following_set__status="accepted",
            )
            .select_related("user")
            .order_by("-following_set__created_at")
        )

        total_followers = followers_queryset.count()
        offset = (page - 1) * page_size
        end = offset + page_size

        followers = [
            to_domain_user_profile_data(profile)
            for profile in list(followers_queryset[offset:end])
        ]

        previous_link = None
        if page > 1:
            previous_link = reverse(
                "get-user-followers",
                kwargs={"user_id": user_id, "page": page - 1, "page_size": page_size},
            )

        next_link = None
        if end < total_followers:
            next_link = reverse(
                "get-user-followers",
                kwargs={"user_id": user_id, "page": page + 1, "page_size": page_size},
            )

        return followers, previous_link, next_link

    def get_followings(
        self, user_id: str, page: int, page_size: int
    ) -> Tuple[List[Any], str | None, str | None]:
        """Get profiles of users that the given user follows"""
        followings_queryset = (
            UserProfile.objects.filter(
                follower_set__follower__user_id=user_id, follower_set__status="accepted"
            )
            .select_related("user")
            .order_by("-follower_set__created_at")
        )

        total_followings = followings_queryset.count()
        offset = (page - 1) * page_size
        end = offset + page_size

        followings = [
            to_domain_user_profile_data(profile)
            for profile in list(followings_queryset[offset:end])
        ]

        previous_link = None
        if page > 1:
            previous_link = reverse(
                "get-user-followings",
                kwargs={"user_id": user_id, "page": page - 1, "page_size": page_size},
            )

        next_link = None
        if end < total_followings:
            next_link = reverse(
                "get-user-followings",
                kwargs={"user_id": user_id, "page": page + 1, "page_size": page_size},
            )

        return followings, previous_link, next_link


class DjangoUserFollowingRepository(UserFollowingRepositoryInterface):
    def create(self, user_following: DomainUserFollowing) -> DomainUserFollowing:
        django_user_following = from_domain_user_following_data(user_following)

        try:
            existing = UserFollowing.objects.filter(
                follower=django_user_following["follower"],
                following=django_user_following["following"],
                status="declined",
            )
            if existing.exists():
                existing.delete()

            created_user_following = UserFollowing.objects.create(
                **django_user_following
            )
        except IntegrityError as e:
            if "UNIQUE constraint failed" in str(e):
                raise ConflictError("A follow request already exists.")

        return to_domain_user_following_data(created_user_following)

    def find_by_id(self, request_id: str) -> DomainUserFollowing | None:
        try:
            request = UserFollowing.objects.get(id=request_id)
            return to_domain_user_following_data(request)
        except UserFollowing.DoesNotExist:
            return None

    def find_existing_request(
        self, follower_id: str, following_id: str
    ) -> DomainUserFollowing | None:
        try:
            request = UserFollowing.objects.get(
                follower__user_id=follower_id, following__user_id=following_id
            )
            return to_domain_user_following_data(request)
        except UserFollowing.DoesNotExist:
            return None

    def update_status(self, request_id: str, status: str) -> DomainUserFollowing:
        try:
            request = UserFollowing.objects.get(id=request_id)
            request.status = status
            request.save()
            return to_domain_user_following_data(request)
        except UserFollowing.DoesNotExist:
            raise ValueError("Follow request not found.")

    def get_received_requests(
        self, user_id, page, page_size, status=None
    ) -> Tuple[List[DomainUserFollowing], str | None, str | None]:
        received_requests = (
            UserFollowing.objects.filter(following__user_id=user_id)
            .select_related("follower__user", "following__user")
            .order_by("-created_at")
        )

        if status:
            received_requests = received_requests.filter(status=status)

        total_received_requests = received_requests.count()
        offset = (page - 1) * page_size
        end = offset + page_size

        received_requests = [
            to_domain_user_following_data(qs)
            for qs in list(received_requests[offset:end])
        ]

        previous_link = None
        if page > 1:
            previous_link = reverse(
                "get-pending-requests",
                kwargs={"page": page - 1, "page_size": page_size},
            )

        next_link = None
        if end < total_received_requests:
            next_link = reverse(
                "get-pending-requests",
                kwargs={"page": page + 1, "page_size": page_size},
            )

        return received_requests, previous_link, next_link

    def get_sent_requests(
        self, user_id, page, page_size, status=None
    ) -> Tuple[List[DomainUserFollowing], str | None, str | None]:
        sent_requests = (
            UserFollowing.objects.filter(follower__user_id=user_id)
            .select_related("follower__user", "following__user")
            .order_by("-created_at")
        )

        if status:
            sent_requests = sent_requests.filter(status=status)

        total_sent_requests = sent_requests.count()
        offset = (page - 1) * page_size
        end = offset + page_size

        sent_requests = [
            to_domain_user_following_data(qs) for qs in list(sent_requests[offset:end])
        ]

        previous_link = None
        if page > 1:
            previous_link = reverse(
                "get-pending-requests",
                kwargs={"page": page - 1, "page_size": page_size},
            )

        next_link = None
        if end < total_sent_requests:
            next_link = reverse(
                "get-pending-requests",
                kwargs={"page": page + 1, "page_size": page_size},
            )

        return sent_requests, previous_link, next_link

    def get_mutual_followers(
        self, user_id: str, page: int, page_size: int
    ) -> Tuple[List[Any], str | None, str | None]:
        following = UserFollowing.objects.filter(
            follower__user_id=user_id, status="accepted"
        ).values_list("following__user_id", flat=True)

        mutual_followers = (
            UserFollowing.objects.filter(
                following__user_id=user_id,
                status="accepted",
                follower__user_id__in=following,
            )
            .select_related("follower__user")
            .order_by("-created_at")
        )

        total_friends = mutual_followers.count()
        offset = (page - 1) * page_size
        end = offset + page_size

        friends = [
            to_domain_user_following_data(qs)
            for qs in list(mutual_followers[offset:end])
        ]

        previous_link = None
        if page > 1:
            previous_link = reverse(
                "get-friends-list", kwargs={"page": page - 1, "page_size": page_size}
            )

        next_link = None
        if end < total_friends:
            next_link = reverse(
                "get-friends-list", kwargs={"page": page + 1, "page_size": page_size}
            )

        return friends, previous_link, next_link
