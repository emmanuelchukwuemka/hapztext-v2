from rest_framework import serializers

from ..domain.enums import Ethnicity, RelationshipStatus


class UserDetailSerializer(serializers.Serializer):
    id = serializers.CharField(read_only=True)
    username = serializers.CharField(required=False)

    def validate(self, attrs):
        attrs["id"] = self.context.get("id")
        return attrs


class UserProfileDetailSerializer(serializers.Serializer):
    user_id = serializers.CharField(read_only=True)
    birth_date = serializers.DateField(required=False)
    ethnicity = serializers.ChoiceField(
        choices=Ethnicity.choices(), default=Ethnicity.OTHER
    )
    relationship_status = serializers.ChoiceField(
        choices=RelationshipStatus.choices(), default=RelationshipStatus.SINGLE
    )
    first_name = serializers.CharField(required=False)
    last_name = serializers.CharField(required=False)
    bio = serializers.CharField(required=False)
    occupation = serializers.CharField(required=False)
    profile_picture = serializers.ImageField(required=False)
    location = serializers.CharField(
        required=False,
        help_text="User's location, e.g., 'MorningGrove, Lagos, Nigeria'",
    )
    height = serializers.DecimalField(max_digits=5, decimal_places=2, required=False)
    weight = serializers.DecimalField(max_digits=5, decimal_places=2, required=False)

    def validate(self, attrs):
        attrs["user_id"] = self.context.get("user_id")
        return attrs


class UserProfileListSerializer(serializers.Serializer):
    page = serializers.IntegerField(required=True)
    page_size = serializers.IntegerField(required=True)


class FollowUserSerializer(serializers.Serializer):
    follower_id = serializers.CharField(read_only=True)
    following_id = serializers.CharField(required=True)

    def validate(self, attrs):
        attrs["follower_id"] = self.context.get("follower_id")

        if attrs["following_id"] == attrs["follower_id"]:
            raise serializers.ValidationError("Users cannot follow themselves.")

        return attrs
