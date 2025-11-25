"""
TEST CHAT ROUTES
"""

import uuid
import pytest
from django.contrib.auth import get_user_model

from apps.infrastructure.calls.models import CallRecordModel, CallParticipantModel

User = get_user_model()


@pytest.mark.django_db
class TestCreateModels:
    """
    TestChatRoute

    """

    def test_call_record_creation(self):
        """
        Test for call record creation
        """
        email = f"{str(uuid.uuid4()).replace("-", "")}@test.com"
        title = str(uuid.uuid4())
        username = str(uuid.uuid4())

        user = User.objects.create_user(
            email=email,
            password="Johnson1234#",
            username=username,
        )

        assert user.email == email

        record = CallRecordModel.objects.create(
            title=title,
            end_time=None,
            initiator=user,
        )

        assert record.id is not None
        assert record.start_time is not None

        assert record.initiator == user

    def test_call_participants(self):
        """
        Test call participants creation
        """
        email1 = f"{str(uuid.uuid4()).replace("-", "")}@test.com"
        email2 = f"{str(uuid.uuid4()).replace("-", "")}@test.com"
        title = str(uuid.uuid4())
        username1 = str(uuid.uuid4())
        username2 = str(uuid.uuid4())

        user1 = User.objects.create_user(
            email=email1,
            password="Johnson1234#",
            username=username1,
        )

        assert user1.email == email1

        user2 = User.objects.create_user(
            email=email2,
            password="Johnson1234#",
            username=username2,
        )

        assert user2.email == email2

        record = CallRecordModel.objects.create(
            title=title,
            end_time=None,
            initiator=user1,
        )

        assert record is not None

        participant1 = CallParticipantModel.objects.create(
            call=record,
            user=user1,
        )

        assert participant1 is not None

        participant2 = CallParticipantModel.objects.create(
            call=record,
            user=user2,
        )
        assert participant2 is not None
