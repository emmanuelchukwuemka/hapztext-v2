from typing import Any, Dict, List, Tuple

from django.db import IntegrityError
from django.db.models import Q, Count, OuterRef, Subquery
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
from apps.domain.users.entities import UserSearchResult as DomainUserSearchResult

from .models.tables import User, UserFollowing, UserProfile, UserMentionCount


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
        created_at=django_user_following.created_at,
    )


def to_domain_user_search_result(
    django_user: User,
    follower_count: int = 0,
    following_count: int = 0,
    mention_count: int = 0,
    profile_picture: str | None = None,
) -> DomainUserSearchResult:
    return DomainUserSearchResult(
        id=django_user.id,
        email=django_user.email,
        username=django_user.username,
        follower_count=follower_count,
        following_count=following_count,
        mention_count=mention_count,
        profile_picture=profile_picture,
        is_email_verified=django_user.is_email_verified,
        is_active=django_user.is_active,
        created_at=django_user.created_at,
        updated_at=django_user.updated_at,
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

    def search(
        self, query: str, page: int, page_size: int
    ) -> Tuple[List[DomainUserSearchResult], str | None, str | None]:
        from apps.infrastructure.posts.models.tables import PostTag

        follower_count_subquery = (
            UserFollowing.objects.filter(following__user_id=OuterRef("id"))
            .values("following__user_id")
            .annotate(count=Count("id"))
            .values("count")
        )

        following_count_subquery = (
            UserFollowing.objects.filter(follower__user_id=OuterRef("id"))
            .values("follower__user_id")
            .annotate(count=Count("id"))
            .values("count")
        )

        mention_count_subquery = UserMentionCount.objects.filter(
            user_id=OuterRef("id")
        ).values("count")[:1]

        queryset = (
            User.objects.filter(
                Q(username__istartswith=query)
                | Q(user_profile__first_name__istartswith=query)
                | Q(user_profile__last_name__istartswith=query),
                is_email_verified=True,
                is_active=True,
            )
            .select_related("user_profile")
            .annotate(
                follower_count=Subquery(follower_count_subquery),
                following_count=Subquery(following_count_subquery),
                mention_count=Subquery(mention_count_subquery),
            )
            .order_by("-created_at")
        )

        total_users = queryset.count()
        offset = (page - 1) * page_size
        end = offset + page_size

        users = [
            to_domain_user_search_result(
                qs,
                follower_count=qs.follower_count or 0,
                following_count=qs.following_count or 0,
                mention_count=qs.mention_count or 0,
                profile_picture=(
                    qs.user_profile.profile_picture.name
                    if hasattr(qs, "user_profile") and qs.user_profile.profile_picture
                    else None
                ),
            )
            for qs in queryset[offset:end]
            if hasattr(qs, "user_profile")
        ]

        previous_link = None
        if page > 1:
            previous_link = reverse(
                "search-users",
                query={"query": query, "offset": page - 1, "limit": page_size},
            )

        next_link = None
        if end < total_users:
            next_link = reverse(
                "search-users",
                query={"query": query, "offset": page + 1, "limit": page_size},
            )

        return users, previous_link, next_link


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
        followers_queryset = (
            UserProfile.objects.filter(
                following_set__following__user_id=user_id,
            )
            .select_related("user")
            .prefetch_related("follower_set", "following_set")
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
        followings_queryset = (
            UserProfile.objects.filter(follower_set__follower__user_id=user_id)
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
            created_user_following = UserFollowing.objects.create(
                **django_user_following
            )
        except IntegrityError as e:
            if "UNIQUE constraint failed" in str(e) or "duplicate key value" in str(e):
                raise ConflictError("You already follow this user.")
            raise e
        return to_domain_user_following_data(created_user_following)

    def get_mutual_followers(
        self, user_id: str, page: int, page_size: int, query: str | None = None
    ) -> Tuple[List[Any], str | None, str | None]:
        following = UserFollowing.objects.filter(follower__user_id=user_id).values_list(
            "following__user_id", flat=True
        )

        mutual_followers = (
            UserFollowing.objects.filter(
                following__user_id=user_id,
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
                "search-friends",
                query={"query": query, "offset": page - 1, "limit": page_size},
            )

        next_link = None
        if end < total_friends:
            next_link = reverse(
                "search-friends",
                query={"query": query, "offset": page + 1, "limit": page_size},
            )

        return friends, previous_link, next_link

    def are_friends(self, user1_id: str, user2_id: str) -> bool:
        user1_follows_user2 = UserFollowing.objects.filter(
            follower_id=user1_id, following_id=user2_id
        ).exists()

        user2_follows_user1 = UserFollowing.objects.filter(
            follower_id=user2_id, following_id=user1_id
        ).exists()

        return user1_follows_user2 and user2_follows_user1
