from rest_framework import serializers

from apps.domain.users.enums import Ethnicity, RelationshipStatus


class UserDetailSerializer(serializers.Serializer):
    id = serializers.CharField(read_only=True)
    username = serializers.CharField(required=False)

    def validate(self, attrs):
        attrs["id"] = self.context.get("id")
        return attrs


class UserProfileDetailSerializer(serializers.Serializer):
    user_id = serializers.CharField(required=True)
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
    height = serializers.DecimalField(
        max_digits=5, min_value=0, decimal_places=2, required=False
    )
    weight = serializers.DecimalField(
        max_digits=5, min_value=0, decimal_places=2, required=False
    )


class UserProfileListSerializer(serializers.Serializer):
    page = serializers.IntegerField(required=True)
    page_size = serializers.IntegerField(required=True)


class FollowRequestSerializer(serializers.Serializer):
    requester_id = serializers.CharField(read_only=True)
    target_id = serializers.CharField(read_only=True)

    def validate(self, attrs):
        attrs["requester_id"] = self.context.get("requester_id")
        attrs["target_id"] = self.context.get("target_id")

        if attrs["target_id"] == attrs["requester_id"]:
            raise serializers.ValidationError(
                "Users cannot send follow requests to themselves."
            )

        return attrs


class HandleFollowRequestSerializer(serializers.Serializer):
    request_id = serializers.CharField(read_only=True)
    action = serializers.ChoiceField(choices=["accepted", "declined"], required=True)
    user_id = serializers.CharField(read_only=True)

    def validate(self, attrs):
        attrs["request_id"] = self.context.get("request_id")
        attrs["user_id"] = self.context.get("user_id")
        attrs["action"] = attrs["action"].lower().strip()
        return attrs


class PaginatedDataRequestSerializer(serializers.Serializer):
    page = serializers.IntegerField(required=True)
    page_size = serializers.IntegerField(required=True)
    user_id = serializers.CharField(read_only=True)

    def validate(self, attrs):
        attrs["user_id"] = self.context.get("user_id")
        return attrs


class UserFollowersSerializer(serializers.Serializer):
    user_id = serializers.CharField(read_only=True)
    page = serializers.IntegerField(required=True)
    page_size = serializers.IntegerField(required=True)

    def validate(self, attrs):
        attrs["user_id"] = self.context.get("user_id")
        return attrs


class UserFollowingsSerializer(serializers.Serializer):
    user_id = serializers.CharField(read_only=True)
    page = serializers.IntegerField(required=True)
    page_size = serializers.IntegerField(required=True)

    def validate(self, attrs):
        attrs["user_id"] = self.context.get("user_id")
        return attrs
