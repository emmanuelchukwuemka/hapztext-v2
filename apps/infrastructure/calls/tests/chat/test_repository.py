"""
Test Call Record Repository
"""

import pytest
from apps.infrastructure.calls.models import (
    CallRecordModel,
    CallParticipantModel,
)
from apps.infrastructure.calls.repository import (
    CallRecordRepository,
)


@pytest.mark.django_db
class TestCallRecordRepository:
    """
    TestCallRecordRepository
    """

    def test_a_create_group_call(self, initiator, participants):
        """
        CREATE GROUP CALL
        """
        call = CallRecordRepository.create_group_call(
            initiator_id=initiator.id,
            participant_ids=[p.id for p in participants],
            call_type=CallRecordModel.CallType.VIDEO,
            title="Team Meeting",
        )

        assert isinstance(call, CallRecordModel)
        assert call.initiator == initiator
        assert call.call_type == CallRecordModel.CallType.VIDEO
        assert call.status == CallRecordModel.CallStatus.CANCELED  # as defined

        all_participants = CallParticipantModel.objects.filter(call=call)
        assert all_participants.count() == 3

        initiator_participant = all_participants.get(user=initiator)
        assert (
            initiator_participant.status
            == CallParticipantModel.ParticipantStatus.JOINED
        )

    def test_b_join_call(self, initiator, participants):
        """
        test join Call
        """
        call = CallRecordRepository.create_group_call(
            initiator_id=initiator.id,
            participant_ids=[],
        )
        assert call

        initiator_user = participants[0]
        assert initiator_user
        ok = CallRecordRepository.join_call(
            call_id=call.id,
            user_id=initiator_user.id,
        )
        assert ok is True

        cp = CallParticipantModel.objects.get(
            call=call,
            user=initiator_user,
        )
        assert cp.status == CallParticipantModel.ParticipantStatus.JOINED

    def test_c_leave_call_auto_end(self, initiator):
        """
        Test leave call and auto end
        """
        call = CallRecordRepository.create_group_call(
            initiator_id=initiator.id,
            participant_ids=[],
        )

        # initiator is already JOINED
        ok = CallRecordRepository.leave_call(call_id=call.id, user_id=initiator.id)

        assert ok is True

        call.refresh_from_db()
        assert call.status == CallRecordModel.CallStatus.COMPLETED
        assert call.end_time is not None
        assert call.duration is not None

    def test_d_get_active_call(self, initiator, participants):
        """
        Test get active call
        """
        call = CallRecordRepository.create_group_call(
            initiator_id=initiator.id,
            participant_ids=[p.id for p in participants],
        )

        data = CallRecordRepository.get_active_call(call_id=call.id)
        assert data is not None
        assert data["call"].id == call.id
        assert len(data["all_participants"]) == 3

    def test_e_invite_to_call(self, initiator, participants, django_user_model):
        """
        Test invite new participants
        """
        extra_user = django_user_model.objects.create_user(
            username="extra", password="Johnson1234#", email="some@test.com"
        )

        call = CallRecordRepository.create_group_call(
            initiator_id=initiator.id,
            participant_ids=[participants[0].id],
        )

        ok = CallRecordRepository.invite_to_call(
            call.id,
            inviter_id=initiator.id,
            new_user_ids=[extra_user.id],
        )

        assert ok is True

        participant_ids = set(
            CallParticipantModel.objects.filter(call=call).values_list(
                "user_id", flat=True
            )
        )

        assert extra_user.id in participant_ids

    def test_f_update_participant_media_state(self, initiator):
        """
        Test update media state
        """
        call = CallRecordRepository.create_group_call(
            initiator_id=initiator.id,
            participant_ids=[],
        )

        ok = CallRecordRepository.update_participant_media_state(
            call_id=call.id,
            user_id=initiator.id,
            video_enabled=True,
            audio_enabled=False,
        )
        assert ok is True

        cp = CallParticipantModel.objects.get(call=call, user=initiator)
        assert cp.video_enabled is True
        assert cp.audio_enabled is False

    def test_g_get_recent_calls(self, initiator):
        """
        Test get recent calls
        """
        call = CallRecordRepository.create_group_call(
            initiator_id=initiator.id,
            participant_ids=[],
        )

        recent = CallRecordRepository.get_recent_calls(user_id=initiator.id)
        assert len(recent) >= 1
        assert recent[0]["call"].id == call.id

    def test_h_get_call_summary(self, initiator, participants):
        """
        Test get call summary
        """
        call = CallRecordRepository.create_group_call(
            initiator_id=initiator.id,
            participant_ids=[p.id for p in participants],
        )
        summary = CallRecordRepository.get_call_summary(call_id=call.id)

        assert summary is not None
        assert summary["call_info"] == call.model_dump()
        assert summary["participant_stats"]["total"] == 3

    def test_j_get_active_participants(self, initiator):
        """
        Test get active participants
        """
        call = CallRecordRepository.create_group_call(
            initiator_id=initiator.id,
            participant_ids=[],
        )

        participants = CallRecordRepository.get_active_participants(call_id=call.id)
        assert len(participants) == 1
        assert participants[0].user == initiator

    def test_k_get_call_participants(self, initiator, participants):
        """
        Test get participants
        """
        call = CallRecordRepository.create_group_call(
            initiator_id=initiator.id,
            participant_ids=[p.id for p in participants],
        )

        participants = CallRecordRepository.get_call_participants(call.id)
        assert len(participants) == 3

    def test_l_get_user_call_history(self, initiator):
        """
        Test get user call records
        """
        call = CallRecordRepository.create_group_call(
            initiator_id=initiator.id,
            participant_ids=[],
        )
        assert call

        history = CallRecordRepository.get_user_call_history(user_id=initiator.id)

        assert "calls" in history
        assert len(history["calls"]) >= 1
        assert "pagination" in history

    def test_m_get_user_call_statistics(self, initiator):
        """
        Test get user call record stats
        """
        call = CallRecordRepository.create_group_call(
            initiator_id=initiator.id,
            participant_ids=[],
        )

        CallRecordRepository.end_call_for_all(call.id, ended_by=initiator.id)

        stats = CallRecordRepository.get_user_call_statistics(initiator.id)

        assert stats["total_calls"] >= 1
        assert stats["completed_calls"] >= 1
        assert "average_duration_seconds" in stats

    def test_i_end_call_for_all(self, initiator, participants):
        """
        Test end call for all
        """
        call = CallRecordRepository.create_group_call(
            initiator_id=initiator.id,
            participant_ids=[p.id for p in participants],
        )

        ok = CallRecordRepository.end_call_for_all(
            call_id=call.id, ended_by=initiator.id
        )
        assert ok is True

        call.refresh_from_db(fields=["participants", "status", "end_time"])
        assert call.status == CallRecordModel.CallStatus.COMPLETED
        assert call.end_time is not None

        # for cp in CallParticipantModel.objects.filter(call=call):
        #     cp.refresh_from_db(fields=["status"])
        #     assert cp.status == CallParticipantModel.ParticipantStatus.LEFT
