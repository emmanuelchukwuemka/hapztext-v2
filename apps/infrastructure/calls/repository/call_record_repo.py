"""
Call Record Repository
"""

from typing import List, Optional, Dict, Any
import logging
from uuid import uuid4

from django.db import transaction
from django.db.models import Q, Prefetch, Count
from django.utils import timezone

from apps.infrastructure.calls.models import CallRecordModel, CallParticipantModel
from apps.infrastructure.calls.utils.call_app_util import CallAppUtil
from apps.infrastructure.calls.custom_exceptions import (
    CUstomCallParticipantForeignKeyError,
)
from apps.infrastructure.users.models.tables import User


logger = logging.getLogger(__name__)


class CallRecordRepository:
    """
    Repository service for Google Meet-style voice/video calls.
    Handles group calls, participant management, and real-time call states.
    """

    @staticmethod
    def create_group_call(
        initiator_id: str,
        participant_ids: List[str],
        call_type: str = CallRecordModel.CallType.VIDEO,
        title: Optional[str] = None,
    ) -> CallRecordModel:
        """
        Create a new group call.

        Args:
            initiator_id: User who creates the meeting
            participant_ids: Users to invite to the call
            call_type: VIDEO or VOICE call
            title: Optional meeting title

        Returns:
            CallRecordModel instance
        """
        try:
            with transaction.atomic():
                call = CallRecordModel.objects.create(
                    initiator_id=initiator_id,
                    call_type=call_type,
                    status=CallRecordModel.CallStatus.CANCELED,  # Starts as "active"
                    title=(title or str(uuid4())),
                )

                # Add all participants including initiator
                all_participants = set(participant_ids) | {initiator_id}
                call_participants = []

                for user_id in all_participants:
                    participant_status = (
                        CallParticipantModel.ParticipantStatus.CONNECTING
                    )
                    join_time = None

                    if user_id != initiator_id:
                        user_exists = User.objects.filter(id=user_id)
                        if not user_exists:
                            raise CUstomCallParticipantForeignKeyError()
                    if user_id == initiator_id:
                        participant_status = (
                            CallParticipantModel.ParticipantStatus.JOINED
                        )
                        join_time = timezone.now()

                    call_participants.append(
                        CallParticipantModel(
                            call=call,
                            user_id=user_id,
                            status=participant_status,
                            join_time=join_time,
                        )
                    )

                CallParticipantModel.objects.bulk_create(call_participants)

                logger.info(
                    "Group call %s created by %s with %s participants",
                    call.id,
                    initiator_id,
                    len(all_participants),
                )
                return call

        except CUstomCallParticipantForeignKeyError as e:
            logger.error("Failed to create group call: %s", str(e))
            raise e
        except Exception as e:
            logger.error("Failed to create group call: %s", str(e))
            raise e

    @staticmethod
    def join_call(call_id: str, user_id: str) -> bool:
        """
        User joins an active call.

        Args:
            call_id: The call ID
            user_id: User joining the call

        Returns:
            Boolean indicating success
        """
        try:
            with transaction.atomic():
                (
                    participant,
                    created,
                ) = CallParticipantModel.objects.select_for_update().get_or_create(
                    call_id=call_id,
                    user_id=user_id,
                    defaults={
                        "status": CallParticipantModel.ParticipantStatus.JOINED,
                        "join_time": timezone.now(),
                    },
                )

                if not created:
                    # Update existing participant
                    participant.status = CallParticipantModel.ParticipantStatus.JOINED
                    participant.join_time = timezone.now()
                    participant.leave_time = None
                    participant.save()

                # Update call status to indicate it's active
                CallRecordModel.objects.filter(
                    id=call_id,
                    status=CallRecordModel.CallStatus.CANCELED,  # Only update if still "active"
                ).update(status=CallRecordModel.CallStatus.COMPLETED)

                logger.info("User %s joined call %s", user_id, call_id)
                return True

        except Exception as e:
            logger.error(
                "Failed to join call %s for user %s: %s", call_id, user_id, str(e)
            )
            return False

    @staticmethod
    def leave_call(call_id: str, user_id: str) -> bool:
        """
        User leaves an active call.

        Args:
            call_id: The call ID
            user_id: User leaving the call

        Returns:
            Boolean indicating success
        """
        try:
            with transaction.atomic():
                participant = CallParticipantModel.objects.select_for_update().get(
                    call_id=call_id, user_id=user_id
                )

                participant.status = CallParticipantModel.ParticipantStatus.LEFT
                participant.leave_time = timezone.now()
                participant.save()

                # Check if call should be ended (no active participants)
                active_participants = CallParticipantModel.objects.filter(
                    call_id=call_id,
                    status=CallParticipantModel.ParticipantStatus.JOINED,
                ).count()

                if active_participants == 0:
                    CallRecordRepository._end_call_automatically(call_id)

                logger.info("User %s left call %s", user_id, call_id)
                return True

        except CallParticipantModel.DoesNotExist:
            logger.error("Participant %s not found in call %s", user_id, call_id)
            return False
        except Exception as e:
            logger.error(
                "Failed to leave call %s for user %s: %s", call_id, user_id, str(e)
            )
            return False

    @staticmethod
    def _end_call_automatically(call_id: str) -> None:
        """
        Automatically end call when no participants remain.
        """
        try:
            call = CallRecordModel.objects.get(id=call_id)
            call.end_time = timezone.now()
            call.status = CallRecordModel.CallStatus.COMPLETED

            if call.start_time is not None and call.end_time is not None:
                call.duration = call.end_time - call.start_time

            call.save()
            logger.info("Call %s automatically ended (no participants)", call_id)
        except Exception as e:
            logger.error("Failed to automatically end call %s: %s", call_id, str(e))

    @staticmethod
    def get_active_call(call_id: str) -> Optional[Dict[str, Any]]:
        """
        Get active call details with participant information.

        Args:
            call_id: The call ID

        Returns:
            Dictionary with call and participant details
        """
        try:
            call = CallRecordModel.objects.select_related("initiator").get(id=call_id)

            participants = (
                CallParticipantModel.objects.filter(call_id=call_id)
                .select_related("user")
                .order_by("join_time")
            )

            active_participants = participants.filter(
                status=CallParticipantModel.ParticipantStatus.JOINED
            )

            return {
                "call": call,
                "all_participants": list(participants),
                "active_participants": list(active_participants),
                "participant_count": participants.count(),
                "active_count": active_participants.count(),
            }

        except CallRecordModel.DoesNotExist:
            return None
        except Exception as e:
            logger.error("Failed to get active call %s: %s", call_id, str(e))
            return None

    @staticmethod
    def get_user_active_calls(user_id: str) -> List[CallRecordModel]:
        """
        Get all active calls where user is currently participating.

        Args:
            user_id: The user ID

        Returns:
            List of active calls
        """
        try:
            return list(
                CallRecordModel.objects.filter(
                    participant_links__user_id=user_id,
                    participant_links__status=CallParticipantModel.ParticipantStatus.JOINED,
                    end_time__isnull=True,
                )
                .select_related("initiator")
                .prefetch_related(
                    Prefetch(
                        "participant_links",
                        queryset=CallParticipantModel.objects.select_related(
                            "user"
                        ).filter(status=CallParticipantModel.ParticipantStatus.JOINED),
                    )
                )
                .distinct()
                .order_by("-start_time")
            )
        except Exception as e:
            logger.error("Failed to get active calls for user %s: %s", user_id, str(e))
            return []

    @staticmethod
    @transaction.atomic
    def update_participant_status(
        call_id: str,
        user_id: str,
        new_status: str,
    ) -> bool:
        """
        Update the status of a participant in a call.

        Handles:
        - CONNECTING
        - JOINED   : sets join_time
        - DECLINED
        - BUSY
        - MISSED
        - LEFT     : sets leave_time

        Returns True if updated, False if no change or not found.
        """

        try:
            participant = CallParticipantModel.objects.select_for_update().get(
                call_id=call_id, user_id=user_id
            )
            if not participant:
                logger.warning("participant not found: %s", participant)
                return False

            # If same status, do nothing
            if participant.status == new_status:
                return True

            now = timezone.now()

            # JOINED : user entered call
            if new_status == CallParticipantModel.ParticipantStatus.JOINED:
                participant.join_time = now

            # LEFT : user exited call
            if new_status == CallParticipantModel.ParticipantStatus.LEFT:
                participant.leave_time = now

            # MISSED : user never answered
            if new_status == CallParticipantModel.ParticipantStatus.MISSED:
                participant.join_time = None
                participant.leave_time = now

            # DECLINED : user actively rejected call
            if new_status == CallParticipantModel.ParticipantStatus.DECLINED:
                participant.join_time = None
                participant.leave_time = now

            # CONNECTING : initial state, nothing to do

            participant.status = new_status
            participant.save(update_fields=["status", "join_time", "leave_time"])
            return True

        except CallParticipantModel.DoesNotExist as exc:
            logger.error("CallParticipantModel does not exist: %s", str(exc))
            return False
        except Exception as exc:
            logger.error("Error updating participant status: %s", str(exc))
            raise exc

    @staticmethod
    def invite_to_call(call_id: str, inviter_id: str, new_user_ids: List[str]) -> bool:
        """
        Invite additional users to an existing call.

        Args:
            call_id: The call ID
            inviter_id: User sending the invitation
            new_user_ids: List of user IDs to invite

        Returns:
            Boolean indicating success
        """
        try:
            with transaction.atomic():
                call = CallRecordModel.objects.get(id=call_id)

                existing_participant_ids = set(
                    CallParticipantModel.objects.filter(call_id=call_id).values_list(
                        "user_id", flat=True
                    )
                )

                new_participants = []
                for user_id in new_user_ids:
                    if user_id not in existing_participant_ids:
                        user_exists = User.objects.filter(id=user_id)
                        if not user_exists:
                            raise CUstomCallParticipantForeignKeyError()
                        new_participants.append(
                            CallParticipantModel(
                                call=call,
                                user_id=user_id,
                                status=CallParticipantModel.ParticipantStatus.CONNECTING,
                            )
                        )

                if new_participants:
                    CallParticipantModel.objects.bulk_create(new_participants)
                    logger.info(
                        "Invited %s users to call %s by %s",
                        len(new_participants),
                        call_id,
                        inviter_id,
                    )

                return True

        except CUstomCallParticipantForeignKeyError as e:
            logger.error("Failed to create group call: %s", str(e))
            raise e
        except Exception as e:
            logger.error("Failed to invite users to call %s: %s", call_id, str(e))
            return False

    @staticmethod
    def update_participant_media_state(
        call_id: str, user_id: str, video_enabled: bool, audio_enabled: bool
    ) -> bool:
        """
        Update participant's media state (video/audio on/off).

        Args:
            call_id: The call ID
            user_id: The user ID
            video_enabled: Whether video is enabled
            audio_enabled: Whether audio is enabled

        Returns:
            Boolean indicating success
        """
        try:
            participant = CallParticipantModel.objects.get(
                call_id=call_id, user_id=user_id
            )

            participant.video_enabled = video_enabled
            participant.audio_enabled = audio_enabled
            participant.save()

            logger.debug("Updated media state for user %s in call %s", user_id, call_id)
            return True

        except CallParticipantModel.DoesNotExist:
            return False
        except Exception as e:
            logger.error("Failed to update media state: %s", str(e))
            return False

    @staticmethod
    def get_call_summary(call_id: str) -> Optional[Dict[str, Any]]:
        """
        Get comprehensive call summary for the call room.

        Args:
            call_id: The call ID

        Returns:
            Dictionary with call summary
        """
        try:
            call = CallRecordModel.objects.select_related("initiator").get(id=call_id)
            participants = CallParticipantModel.objects.filter(
                call_id=call_id
            ).select_related("user")

            participant_stats = participants.aggregate(
                total=Count("id"),
                joined=Count(
                    "id", filter=Q(status=CallParticipantModel.ParticipantStatus.JOINED)
                ),
                left=Count(
                    "id", filter=Q(status=CallParticipantModel.ParticipantStatus.LEFT)
                ),
                missed=Count(
                    "id", filter=Q(status=CallParticipantModel.ParticipantStatus.MISSED)
                ),
            )

            active_participants = participants.filter(
                status=CallParticipantModel.ParticipantStatus.JOINED
            )
            # print("initiator: ", initiator)

            return_value = {
                "call_info": call.model_dump(),
                "initiator": CallAppUtil.model_dump(
                    model=call.initiator,
                    omit={
                        "password",
                        "last_login",
                        "is_superuser",
                        "is_staff",
                        "is_active",
                        "date_joined",
                        "is_email_verified",
                        "created_at",
                        "updated_at",
                    },
                ),
                "participant_stats": participant_stats,
                "active_participants": [
                    CallAppUtil.model_dump(model=model) for model in active_participants
                ],
                "all_participants": [
                    CallAppUtil.model_dump(model=model) for model in participants
                ],
                "is_active": call.end_time is None,
                "duration_so_far": (
                    (timezone.now() - call.start_time).microseconds
                    if call.end_time is None
                    else call.duration and call.duration.microseconds or 0
                ),
            }
            # logger.info("return_value: %s", return_value)
            return return_value

        except CallRecordModel.DoesNotExist:
            return None
        except Exception as e:
            logger.error("Failed to get call summary for %s: %s", call_id, str(e))
            return None

    @staticmethod
    def end_call_for_all(call_id: str, ended_by: str) -> bool:
        """
        Force end call for all participants (host action).

        Args:
            call_id: The call ID
            ended_by: User ID who ended the call

        Returns:
            Boolean indicating success
        """
        try:
            with transaction.atomic():
                call = CallRecordModel.objects.get(id=call_id)
                # Update all participants to LEFT status
                CallParticipantModel.objects.filter(
                    call=call,
                    status=CallParticipantModel.ParticipantStatus.JOINED,
                ).update(
                    status=CallParticipantModel.ParticipantStatus.LEFT,
                    leave_time=timezone.now(),
                )

                # End the call

                call.end_time = timezone.now()
                call.status = CallRecordModel.CallStatus.COMPLETED

                if call.start_time and call.end_time is not None:
                    call.duration = call.end_time - call.start_time

                call.save()

                logger.info(
                    "Call %s ended for all participants by %s", call_id, ended_by
                )
                return True

        except Exception as e:
            logger.error("Failed to end call for all participants: %s", str(e))
            return False

    @staticmethod
    def get_recent_calls(user_id: str, limit: int = 10) -> List[Dict[str, Any]]:
        """
        Get recent calls for quick access (like recent meetings).

        Args:
            user_id: The user ID
            limit: Number of recent calls to return

        Returns:
            List of recent call summaries
        """
        try:
            calls = (
                CallRecordModel.objects.filter(
                    Q(initiator_id=user_id) | Q(participant_links__user_id=user_id)
                )
                .select_related("initiator")
                .prefetch_related(
                    Prefetch(
                        "participant_links",
                        queryset=CallParticipantModel.objects.select_related("user"),
                    )
                )
                .distinct()
                .order_by("-start_time")[:limit]
            )

            recent_calls = []
            for call in calls:
                user_participation = call.participant_links.filter(
                    user_id=user_id
                ).first()
                recent_calls.append(
                    {
                        "call": call,
                        "user_role": (
                            "initiator"
                            if call.initiator.id == user_id
                            else "participant"
                        ),
                        "user_status": (
                            user_participation.status if user_participation else None
                        ),
                        "participant_count": call.participant_links.count(),
                    }
                )

            return recent_calls

        except Exception as e:
            logger.error("Failed to get recent calls for user %s: %s", user_id, str(e))
            return []

    @staticmethod
    def get_call_by_id(call_id: str) -> Optional[CallRecordModel]:
        """
        Retrieve a call by ID with participants prefetched.

        Args:
            call_id: The call ID

        Returns:
            CallRecordModel instance or None
        """
        try:
            return (
                CallRecordModel.objects.select_related("initiator")
                .prefetch_related(
                    Prefetch(
                        "participant_links",
                        queryset=CallParticipantModel.objects.select_related("user"),
                    )
                )
                .get(id=call_id)
            )
        except CallRecordModel.DoesNotExist:
            return None

    @staticmethod
    def _validate_call_access(call_id: str, user_id: str) -> bool:
        """
        Validate that user has access to this call.

        Args:
            call_id: The call ID
            user_id: The user ID

        Returns:
            Boolean indicating access
        """
        try:
            return (
                CallRecordModel.objects.filter(id=call_id)
                .filter(Q(initiator_id=user_id) | Q(participants__id=user_id))
                .exists()
            )
        except Exception:
            return False

    @staticmethod
    def get_active_participants(call_id: str) -> List[CallParticipantModel]:
        """
        Get currently active (joined) participants in a call.

        Args:
            call_id: The call ID

        Returns:
            List of active CallParticipantModel instances
        """
        try:
            return list(
                CallParticipantModel.objects.filter(
                    call_id=call_id,
                    status=CallParticipantModel.ParticipantStatus.JOINED,
                )
                .select_related("user")
                .order_by("join_time")
            )
        except Exception as e:
            logger.error(
                "Failed to get active participants for call %s: %s", call_id, str(e)
            )
            return []

    @staticmethod
    def get_call_participants(call_id: str) -> List[CallParticipantModel]:
        """
        Get all participants for a call.

        Args:
            call_id: The call ID

        Returns:
            List of CallParticipantModel instances
        """
        try:
            return list(
                CallParticipantModel.objects.filter(call_id=call_id)
                .select_related("user")
                .order_by("join_time")
            )
        except Exception as e:
            logger.error("Failed to get participants for call %s: %s", call_id, str(e))
            return []

    @staticmethod
    def get_user_call_history(
        user_id: str,
        page: int = 1,
        page_size: int = 20,
        call_type: Optional[str] = None,
        status: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Get paginated call history for a user (both initiated and participated).

        Args:
            user_id: The user ID
            page: Page number
            page_size: Number of items per page
            call_type: Filter by call type (optional)
            status: Filter by call status (optional)

        Returns:
            Dictionary containing calls and pagination info
        """
        try:
            # Get calls where user is initiator or participant
            initiated_calls = Q(initiator_id=user_id)
            participated_calls = Q(participant_links__user_id=user_id)

            queryset = (
                CallRecordModel.objects.filter(initiated_calls | participated_calls)
                .select_related("initiator")
                .prefetch_related(
                    Prefetch(
                        "participant_links",
                        queryset=CallParticipantModel.objects.select_related("user"),
                    )
                )
                .distinct()
                .order_by("-start_time")
            )

            # Apply filters
            if call_type:
                queryset = queryset.filter(call_type=call_type)
            if status:
                queryset = queryset.filter(status=status)

            total_count = queryset.count()
            total_pages = (total_count + page_size - 1) // page_size

            start_index = (page - 1) * page_size
            end_index = start_index + page_size

            calls = queryset[start_index:end_index]

            return {
                "calls": list(calls),
                "pagination": {
                    "page": page,
                    "page_size": page_size,
                    "total_count": total_count,
                    "total_pages": total_pages,
                    "has_next": page < total_pages,
                    "has_previous": page > 1,
                },
            }

        except Exception as e:
            logger.error("Failed to get call history for user %s: %s", user_id, str(e))
            return {"calls": [], "pagination": {}}

    @staticmethod
    def get_user_call_statistics(user_id: str) -> Dict[str, Any]:
        """
        Get call statistics for a user.

        Args:
            user_id: The user ID

        Returns:
            Dictionary with call statistics
        """
        try:
            # Get calls where user is initiator or participant
            initiated_calls = Q(initiator_id=user_id)
            participated_calls = Q(participant_links__user_id=user_id)

            calls = CallRecordModel.objects.filter(
                initiated_calls | participated_calls
            ).distinct()

            total_calls = calls.count()
            completed_calls = calls.filter(
                status=CallRecordModel.CallStatus.COMPLETED
            ).count()
            missed_calls = calls.filter(
                status=CallRecordModel.CallStatus.MISSED
            ).count()
            declined_calls = calls.filter(
                status=CallRecordModel.CallStatus.DECLINED
            ).count()
            canceled_calls = calls.filter(
                status=CallRecordModel.CallStatus.CANCELED
            ).count()
            video_calls = calls.filter(call_type=CallRecordModel.CallType.VIDEO).count()
            voice_calls = calls.filter(call_type=CallRecordModel.CallType.VOICE).count()

            # Calculate average duration for completed calls
            completed_with_duration = calls.filter(
                status=CallRecordModel.CallStatus.COMPLETED, duration__isnull=False
            )

            total_duration = sum(
                (
                    call.duration.total_seconds()
                    for call in completed_with_duration
                    if call.duration
                ),
                0,
            )
            avg_duration = (
                total_duration / completed_calls if completed_calls > 0 else 0
            )

            # Calculate call initiation stats
            initiated_calls_count = CallRecordModel.objects.filter(
                initiator_id=user_id
            ).count()

            return {
                "total_calls": total_calls,
                "completed_calls": completed_calls,
                "missed_calls": missed_calls,
                "declined_calls": declined_calls,
                "canceled_calls": canceled_calls,
                "video_calls": video_calls,
                "voice_calls": voice_calls,
                "initiated_calls": initiated_calls_count,
                "participated_calls": total_calls - initiated_calls_count,
                "average_duration_seconds": avg_duration,
                "completion_rate": (
                    (completed_calls / total_calls * 100) if total_calls > 0 else 0
                ),
                "success_rate": (
                    ((completed_calls + missed_calls) / total_calls * 100)
                    if total_calls > 0
                    else 0
                ),
            }

        except Exception as e:
            logger.error(
                "Failed to get call statistics for user %s: %s", user_id, str(e)
            )
            return {}
