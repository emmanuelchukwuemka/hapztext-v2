"""
Call Factory
"""

from factory.declarations import (
    Sequence,
    LazyAttribute,
    PostGenerationMethodCall,
    SubFactory,
    LazyFunction,
)
from factory.django import DjangoModelFactory
from django.utils import timezone

from django.contrib.auth import get_user_model
from apps.infrastructure.calls.models.call_record import (
    CallRecordModel,
    CallParticipantModel,
)

User = get_user_model()


class UserFactory(DjangoModelFactory):
    """
    UserFactory
    """

    class Meta:  # type: ignore
        """
        Meta
        """

        model = User

    username = Sequence(lambda n: f"user{n}")
    email = LazyAttribute(lambda o: f"{o.username}@example.com")
    password = PostGenerationMethodCall("set_password", "password123")


class CallRecordFactory(DjangoModelFactory):
    """
    CallRecordFactory
    """

    class Meta:  # type: ignore
        """
        Meta
        """

        model = CallRecordModel

    initiator = SubFactory(UserFactory)
    call_type = CallRecordModel.CallType.VOICE
    title = Sequence(lambda n: f"Test Call {n}")
    start_time = LazyFunction(timezone.now)
    status = CallRecordModel.CallStatus.COMPLETED
    is_recording = False


class CallParticipantFactory(DjangoModelFactory):
    """
    CallParticipantFactory
    """

    class Meta:  # type: ignore
        """
        Meta
        """

        model = CallParticipantModel

    call = SubFactory(CallRecordFactory)
    user = SubFactory(UserFactory)
    joined_at = LazyFunction(timezone.now)
    status = CallParticipantModel.ParticipantStatus.JOINED
