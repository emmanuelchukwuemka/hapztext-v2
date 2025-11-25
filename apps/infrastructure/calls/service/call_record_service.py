"""
Call Record Service
"""

from typing import List, Dict, Any
from datetime import timedelta
import logging

from django.db.models import Q
from django.utils import timezone
from rest_framework.exceptions import ValidationError
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework import status

from apps.infrastructure.calls.repository import CallRecordRepository
from apps.infrastructure.calls.models import CallRecordModel
from apps.infrastructure.calls.serializer import (
    CallCreateSerializer,
    JoinCallSerializer,
    EndCallSerializer,
    InviteCallSerializer,
    GetCallHistorySerializer,
    UpdateCallTitleSerializer,
)
from apps.infrastructure.calls.custom_exceptions import (
    CUstomCallParticipantForeignKeyError,
)


logger = logging.getLogger(__name__)


class CallRecordService:
    """
    Service class for CallRecordModel operations to be used via API.
    Handles business logic for call management, statistics, and reporting.
    Uses CallRecordRepository for data operations.
    """

    @staticmethod
    def create_call(
        request: Request,
    ) -> Response:
        """
        Create a new call with participants.

        Args:
            request (Request): The request object.

        Returns:
            Response with call details and participant information
        """
        try:
            user = request.user
            schema = CallCreateSerializer(data=request.data)
            schema.is_valid(raise_exception=True)

            validated: dict = schema.validated_data  # type: ignore

            participant_ids = validated.get("participant_ids", [])
            if user.id in participant_ids:
                return Response(
                    data={
                        "success": False,
                        "message": "Current user ID not allowed in Participant IDs.",
                        "status_code": status.HTTP_400_BAD_REQUEST,
                        "errors": ["Current user ID not allowed in Participant IDs."],
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )

            call = CallRecordRepository.create_group_call(
                initiator_id=user.id,
                participant_ids=participant_ids,
                call_type=validated.get("call_type", ""),
                title=validated.get("title"),
            )

            # Get detailed call information
            call_summary = CallRecordRepository.get_call_summary(call.id)

            return Response(
                data={
                    "success": True,
                    "message": "Call created successfully",
                    "data": {
                        "call": call.model_dump(),
                        "call_summary": call_summary,
                    },
                    "status_code": status.HTTP_201_CREATED,
                },
                status=status.HTTP_201_CREATED,
            )
        except ValidationError as exc:
            logger.error("ValidationError, Failed to create call: %s", str(exc))
            return Response(
                data={
                    "success": False,
                    "message": "Validation error",
                    "errors": [exc.detail],
                    "status_code": exc.status_code,
                },
                status=status.HTTP_400_BAD_REQUEST,
            )
        except CUstomCallParticipantForeignKeyError as exc:
            logger.error(
                "CUstomCallParticipantForeignKeyError, Failed to create call: %s",
                str(exc),
            )
            return Response(
                data={
                    "success": False,
                    "message": str(exc),
                    "status_code": status.HTTP_404_NOT_FOUND,
                    "errors": [str(exc)],
                },
                status=status.HTTP_404_NOT_FOUND,
            )
        except Exception as e:
            logger.error("Uncaught Exception, Failed to create call: %s", str(e))
        return Response(
            data={
                "success": False,
                "message": "Failed to create call",
                "status_code": status.HTTP_500_INTERNAL_SERVER_ERROR,
                "errors": [],
            },
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )

    @staticmethod
    def join_call(request: Request) -> Response:
        """
        Join an existing call.

        Args:
            request (Request): The request object.

        Returns:
            Response with operation result and call state
        """
        call_id = None
        try:
            user = request.auth["user"]

            schema = JoinCallSerializer(data=request.data)
            if not schema.is_valid():
                raise ValidationError(schema.errors)

            validated: dict = schema.validated_data  # type: ignore
            call_id = validated.get("call_id", "")

            success = CallRecordRepository.join_call(
                call_id=validated.get("call_id", ""), user_id=user.id
            )

            if success:
                call_summary = CallRecordRepository.get_call_summary(call_id)
                active_participants = CallRecordRepository.get_active_participants(
                    call_id
                )

                return Response(
                    data={
                        "success": True,
                        "data": {
                            "call_summary": call_summary,
                            "active_participants": active_participants,
                        },
                        "message": "Joined call successfully",
                        "status_code": status.HTTP_201_CREATED,
                    }
                )
            return Response(
                data={
                    "success": False,
                    "message": "Failed to join call",
                    "data": {},
                    "status_code": status.HTTP_417_EXPECTATION_FAILED,
                },
                status=status.HTTP_417_EXPECTATION_FAILED,
            )
        except ValidationError as exc:
            raise exc

        except Exception as e:
            logger.error("Failed to join call %s: %s", call_id, str(e))
            return Response(
                data={
                    "success": False,
                    "message": "Failed to join call",
                    "errors": [],
                    "status_code": status.HTTP_500_INTERNAL_SERVER_ERROR,
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

    @staticmethod
    def leave_call(request: Request) -> Response:
        """
        Leave an active call.

        Args:
            request (Request): The request object.
        Returns:
            Response with operation result
        """
        call_id = None
        try:
            user = request.auth["user"]
            schema = JoinCallSerializer(data=request.data)
            if not schema.is_valid():
                raise ValidationError(schema.errors)

            validated: dict = schema.validated_data  # type: ignore
            call_id = validated.get("call_id", "")

            success = CallRecordRepository.leave_call(call_id=call_id, user_id=user.id)

            if success:
                call_summary = CallRecordRepository.get_call_summary(call_id)

                return Response(
                    data={
                        "success": True,
                        "call_summary": call_summary,
                        "message": "Left call successfully",
                    }
                )
            return Response(data={"success": False, "message": "Failed to leave call"})
        except ValidationError as exc:
            raise exc

        except Exception as e:
            logger.error("Failed to leave call %s: %s", call_id, str(e))
            return Response(
                data={"success": False, "message": "Failed to leave call"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

    @staticmethod
    def end_call(request: Request) -> Response:
        """
        End a call for all participants.

        Args:
            request (Request): The request object.

        Returns:
            Dictionary with operation result
        """
        call_id = None
        try:
            user = request.auth["user"]
            schema = EndCallSerializer(data=request.data)

            if not schema.is_valid():
                raise ValidationError(schema.errors)

            validated: dict = schema.validated_data  # type: ignore
            call_id = validated.get("call_id", "")
            # Verify user has permission to end the call
            if not CallRecordService._can_end_call(call_id=call_id, user_id=user.id):
                return Response(
                    data={
                        "success": False,
                        "message": "You do not have permission to end this call",
                    }
                )

            success = CallRecordRepository.end_call_for_all(
                call_id=call_id, ended_by=user
            )

            if success:
                call_record = CallRecordRepository.get_call_by_id(call_id)

                return Response(
                    data={
                        "success": True,
                        "data": call_record,
                        "message": "Call ended successfully",
                    }
                )
            return Response(data={"success": False, "message": "Failed to end call"})

        except ValidationError as exc:
            raise exc
        except Exception as e:
            logger.error("Failed to end call %s: %s", call_id, str(e))
            return Response(
                data={"success": False, "message": "Failed to end call"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

    @staticmethod
    def invite_to_call(request: Request) -> Response:
        """
        Invite users to an existing call.

        Args:
            request (Request): The request object.

        Returns:
            Dictionary with operation result
        """
        call_id = None
        try:
            user = request.auth["user"]
            schema = InviteCallSerializer(data=request.data)
            if not schema.is_valid():
                raise ValidationError(schema.errors)

            validated: dict = schema.validated_data  # type: ignore
            call_id = validated.get("call_id", "")
            invitee_ids = validated.get("invitee_ids", [])

            success = CallRecordRepository.invite_to_call(
                call_id=call_id, inviter_id=user.id, new_user_ids=invitee_ids
            )

            if success:
                call_summary = CallRecordRepository.get_call_summary(call_id)

                return Response(
                    data={
                        "success": True,
                        "data": {
                            "call_summary": call_summary,
                            "invited_users": invitee_ids,
                        },
                        "message": f"Invited {len(invitee_ids)} users to the call",
                    }
                )
            return Response(
                data={"success": False, "message": "Failed to invite users to call"}
            )

        except ValidationError as exc:
            raise exc
        except Exception as e:
            logger.error("Failed to invite users to call %s: %s", call_id, str(e))
            return Response(
                data={"success": False, "message": "Failed to invite users"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

    @staticmethod
    def get_call_details(request: Request) -> Response:
        """
        Get detailed information about a call.

        Args:
            request (Request): The request object.

        Returns:
            Dictionary with call details
        """
        call_id = None
        try:
            user = request.auth["user"]
            schema = JoinCallSerializer(data=request.data)
            if not schema.is_valid():
                raise ValidationError(schema.errors)
            validated: dict = schema.validated_data  # type: ignore
            call_id = validated.get("call_id", "")
            # Verify user has access to the call
            if not CallRecordRepository._validate_call_access(
                call_id=call_id, user_id=user.id
            ):
                return Response(
                    data={
                        "success": False,
                        "message": "You do not have access to this call",
                    }
                )

            call_summary = CallRecordRepository.get_call_summary(call_id)
            active_participants = CallRecordRepository.get_active_participants(call_id)
            all_participants = CallRecordRepository.get_call_participants(call_id)

            return Response(
                data={
                    "success": True,
                    "message": "Call details retrieved successfully.",
                    "data": {
                        "call_summary": call_summary,
                        "active_participants": active_participants,
                        "all_participants": all_participants,
                        "is_active": (
                            call_summary["is_active"] if call_summary else False
                        ),
                    },
                }
            )

        except ValidationError as exc:
            raise exc
        except Exception as e:
            logger.error("Failed to get call details for %s: %s", call_id, str(e))
            return Response(
                data={
                    "success": False,
                    "message": f"Failed to get call details: {str(e)}",
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

    @staticmethod
    def get_user_call_history(request: Request) -> Response:
        """
        Get paginated call history for a user with advanced filtering.

        Args:
            request (Request): The request object.

        Returns:
            Dictionary with calls and pagination info
        """
        user_id = None
        try:
            user = request.auth["user"]
            user_id = user.id
            schema = GetCallHistorySerializer(data=request.data)
            if not schema.is_valid():
                raise ValidationError(schema.errors)

            validated: dict = schema.validated_data  # type: ignore

            date_to = validated.get("date_to")
            date_from = validated.get("date_from")
            page = validated.get("page", 1)
            limit = validated.get("limit", 50)
            call_type = validated.get("call_type", None)
            call_status = validated.get("call_status")

            result = CallRecordRepository.get_user_call_history(
                user_id=user_id,
                page=page,
                page_size=limit,
                call_type=call_type,
                status=call_status,
            )

            # Apply additional date filtering if provided
            calls = result["calls"]
            if date_from or date_to:
                filtered_calls = []
                for call in calls:
                    call_date = call.start_time.date()

                    if (
                        date_from
                        and call_date
                        < timezone.datetime.strptime(date_from, "%Y-%m-%d").date()
                    ):
                        continue
                    if (
                        date_to
                        and call_date
                        > timezone.datetime.strptime(date_to, "%Y-%m-%d").date()
                    ):
                        continue

                    filtered_calls.append(call)

                result["calls"] = filtered_calls

            return Response(
                data={
                    "success": True,
                    "data": result["calls"],
                    "pagination": result["pagination"],
                    "message": "Call history retrieved successfully.",
                }
            )

        except ValidationError as exc:
            raise exc
        except Exception as e:
            logger.error("Failed to get call history for user %s: %s", user_id, str(e))
            return Response(
                data={
                    "success": False,
                    "data": [],
                    "pagination": {},
                    "message": "Failed to get call history",
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

    @staticmethod
    def get_user_statistics(request: Request) -> Response:
        """
        Get comprehensive call statistics for a user.

        Args:
            request (Request): The request object.

        Returns:
            Dictionary with user call statistics
        """
        user_id = None
        try:
            user = request.auth["user"]
            user_id = user.id
            stats = CallRecordRepository.get_user_call_statistics(user_id)

            # Add additional statistics
            recent_calls = CallRecordRepository.get_recent_calls(user_id, limit=50)

            # Calculate weekly activity
            weekly_activity = CallRecordService._calculate_weekly_activity(user_id)

            # Most frequent call partners
            frequent_partners = CallRecordService._get_frequent_call_partners(user_id)

            return Response(
                data={
                    "success": True,
                    "message": "Statistics retrieved successfully",
                    "data": {
                        "basic_stats": stats,
                        "weekly_activity": weekly_activity,
                        "frequent_partners": frequent_partners,
                        "recent_calls_count": len(recent_calls),
                    },
                }
            )

        except ValidationError as exc:
            raise exc
        except Exception as e:
            logger.error("Failed to get statistics for user %s: %s", user_id, str(e))
            return Response(
                data={"success": False, "message": "Failed to get statistics"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

    @staticmethod
    def update_call_title(request: Request) -> Response:
        """
        Update call title/meeting name.

        Args:
            request (Request): The request object.

        Returns:
            Dictionary with operation result
        """
        call_id = None
        try:
            user = request.auth["user"]
            schema = UpdateCallTitleSerializer(data=request.data)
            if not schema.is_valid():
                raise ValidationError(schema.errors)
            validated: dict = schema.validated_data  # type: ignore
            call_id = validated.get("call_id", "")
            # Verify user has permission to update the call
            if not CallRecordService._can_modify_call(call_id=call_id, user_id=user.id):
                return Response(
                    data={
                        "success": False,
                        "message": "You do not have permission to modify this call",
                    }
                )

            call = CallRecordModel.objects.get(id=call_id)
            call.title = validated.get("new_title", "")
            call.save()

            return Response(
                data={
                    "success": True,
                    "call": call,
                    "message": "Call title updated successfully",
                }
            )

        except CallRecordModel.DoesNotExist:
            return Response(data={"success": False, "message": "Call not found"})
        except ValidationError as exc:
            raise exc
        except Exception as e:
            logger.error("Failed to update call title for %s: %s", call_id, str(e))
            return Response(
                data={
                    "success": False,
                    "message": "Failed to update call title",
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

    @staticmethod
    def get_active_calls(request: Request) -> Response:
        """
        Get all active calls for a user.

        Args:
            request (Request): The request object.

        Returns:
            Dictionary with active calls
        """
        user_id = None
        try:
            user = request.auth["user"]
            user_id = user.id
            active_calls = CallRecordRepository.get_user_active_calls(user_id=user_id)

            return Response(
                data={
                    "success": True,
                    "data": {
                        "active_calls": active_calls,
                        "count": len(active_calls),
                    },
                }
            )

        except ValidationError as exc:
            raise exc
        except Exception as e:
            logger.error("Failed to get active calls for user %s: %s", user_id, str(e))
            return Response(
                data={
                    "data": {
                        "success": False,
                        "active_calls": [],
                    },
                    "message": "Failed to get active calls",
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

    # Helper Methods

    @staticmethod
    def _can_end_call(call_id: str, user_id: str) -> bool:
        """Check if user can end the call."""
        try:
            call = CallRecordRepository.get_call_by_id(call_id)
            if not call:
                return False
            return call.initiator.id == user_id
        except Exception:
            return False

    @staticmethod
    def _can_modify_call(call_id: str, user_id: str) -> bool:
        """Check if user can modify the call."""
        try:
            call = CallRecordRepository.get_call_by_id(call_id)
            if not call:
                return False
            return call.initiator.id == user_id
        except Exception:
            return False

    @staticmethod
    def _calculate_weekly_activity(user_id: str) -> Dict[str, int]:
        """Calculate weekly call activity for a user."""
        try:
            end_date = timezone.now()
            start_date = end_date - timedelta(days=30)

            calls = CallRecordModel.objects.filter(
                Q(initiator_id=user_id) | Q(participants__id=user_id),
                start_time__gte=start_date,
                start_time__lte=end_date,
            ).distinct()

            weekly_activity = {}
            for call in calls:
                week = call.start_time.strftime("%Y-%U")
                weekly_activity[week] = weekly_activity.get(week, 0) + 1

            return weekly_activity

        except Exception as e:
            logger.error(
                "Failed to calculate weekly activity for user %s: %s", user_id, str(e)
            )
            return {}

    @staticmethod
    def _get_frequent_call_partners(
        user_id: str, limit: int = 5
    ) -> List[Dict[str, Any]]:
        """Get most frequent call partners for a user."""
        try:
            # TODO: This would require a more complex query to find frequent call partners
            # For now, return empty list
            return []

        except Exception as e:
            logger.error(
                "Failed to get frequent partners for user %s: %s", user_id, str(e)
            )
            return []
