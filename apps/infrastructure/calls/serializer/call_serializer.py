"""
Calls Serializer
"""

from rest_framework import serializers
from rest_framework.exceptions import ValidationError

from apps.infrastructure.calls.models import CallRecordModel
from apps.infrastructure.calls.dto import (
    NewCallRequestDto,
    JoinCallRequestDto,
    EndCallRequestDto,
    InviteCallRequestDto,
    GetCallHistoryRequestDto,
    UpdateCallTitleRequestDto,
)


class CallModelSerializer(serializers.ModelSerializer):
    """
    CallModelSerializer
    """

    class Meta:
        """
        Meta
        """

        model = CallRecordModel
        # Use all fields including the auto-generated ID and timestamps
        fields = "__all__"
        read_only_fields = ["id", "created_at", "updated_at"]


class CallCreateSerializer(serializers.Serializer):
    """
    CallCreateSerializer
    """

    title = serializers.CharField(
        required=False,
        min_length=1,
        max_length=100,
    )
    participant_ids = serializers.ListField(
        child=serializers.CharField(
            max_length=21,
            min_length=21,
            required=False,
        ),
        required=False,
        min_length=1,
        max_length=10,
    )
    call_type = serializers.ChoiceField(
        required=False, choices=["voice", "video"], default="video"
    )

    def validate(self, attrs: dict) -> dict:
        """
        Validate fields
        """
        payload = NewCallRequestDto(**attrs)
        payload.validate()

        return attrs


class JoinCallSerializer(serializers.Serializer):
    """
    JoinCallSerializer
    """

    call_id = serializers.CharField(required=False, min_length=21, max_length=21)

    def validate(self, attrs: dict) -> dict:
        """
        Validate fields
        """
        payload = JoinCallRequestDto(**attrs)
        payload.validate()
        return attrs


class EndCallSerializer(serializers.Serializer):
    """
    EndCallSerializer
    """

    call_id = serializers.CharField(required=False, min_length=21, max_length=21)

    def validate(self, attrs: dict) -> dict:
        """
        Validate fields
        """
        payload = EndCallRequestDto(**attrs)
        payload.validate()
        return attrs


class InviteCallSerializer(serializers.Serializer):
    """
    InviteCallSerializer
    """

    call_id = serializers.CharField(required=False, min_length=21, max_length=21)
    invitee_ids = serializers.ListField(
        child=serializers.CharField(
            max_length=21,
            min_length=21,
        ),
        required=True,
        min_length=1,
        max_length=10,
    )

    def validate(self, attrs: dict) -> dict:
        """
        Validate
        """
        payload = InviteCallRequestDto(**attrs)
        payload.validate()
        return attrs


class CallUpdateSerializer(serializers.Serializer):
    """
    CallUpdateSerializer
    """

    status = serializers.ChoiceField(choices=CallRecordModel.CallStatus, required=False)
    started_at = serializers.DateTimeField(required=False, allow_null=True)
    ended_at = serializers.DateTimeField(required=False, allow_null=True)

    def validate(self, attrs: dict) -> dict:
        """
        Performs object-level validation: ensures caller != callee,
        and that both users exist.
        """
        if (
            not attrs.get("status")
            and not attrs.get("started_at")
            and not attrs.get("ended_at")
        ):
            raise ValidationError(
                detail="must provide at least one field for call update"
            )
        return attrs


class GetCallHistorySerializer(serializers.Serializer):
    """
    GetCallHistory Serializer
    """

    page = serializers.IntegerField(required=False, min_value=1)
    limit = serializers.IntegerField(required=False, min_value=1, max_value=50)
    call_type = serializers.ChoiceField(
        choices=CallRecordModel.CallType, required=False
    )
    call_status = serializers.ChoiceField(
        required=False, choices=CallRecordModel.CallStatus
    )

    def validate(self, attrs: dict) -> dict:
        """
        Validate fields
        """
        payload = GetCallHistoryRequestDto(**attrs)
        payload.validate()

        return attrs


class UpdateCallTitleSerializer(serializers.Serializer):
    """
    UpdateCallTitleSerializer
    """

    new_title = serializers.CharField(required=True, min_length=3, max_length=100)

    def validate(self, attrs: dict) -> dict:
        """
        Validate fields
        """

        payload = UpdateCallTitleRequestDto(**attrs)
        payload.validate()

        return attrs
