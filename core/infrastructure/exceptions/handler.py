import traceback
from typing import Any, Dict, List

from django.db import IntegrityError
from rest_framework import status
from rest_framework.exceptions import (
    APIException,
    AuthenticationFailed,
    MethodNotAllowed,
    NotAuthenticated,
    NotFound,
    ParseError,
    Throttled,
    ValidationError,
)
from rest_framework.response import Response
from rest_framework.views import exception_handler

from ...infrastructure.exceptions import (
    BadRequestError,
    BaseAPIException,
    ConflictError,
    UnprocessableEntityError,
)
from ...infrastructure.logging.base import logger


def hapz_exception_handler(exc: Exception, context: Dict[str, Any]) -> Response | None:
    if isinstance(exc, IntegrityError):
        logger.exception(f"Unhandled database constraint error: {exc}.")
        exc = ConflictError()
    if isinstance(exc, ParseError):
        exc = UnprocessableEntityError(detail=str(exc.detail))
    elif isinstance(exc, ValueError):
        exc = BadRequestError(detail=str(exc))
    elif isinstance(exc, (TypeError, AttributeError, KeyError, IndexError)):
        logger.exception(f"Unhandled application error: {type(exc).__name__}: {exc}.")
        exc = BaseAPIException(
            detail="An unexpected internal server error occurred. Please try again later."
        )
    elif not isinstance(exc, APIException):
        logger.exception(f"Unhandled server error: {type(exc).__name__}: {exc}.")
        exc = BaseAPIException(
            detail="An unexpected internal server error occurred. Please try again later."
        )

    response = exception_handler(exc, context)

    response_data = {
        "success": False,
        "message": "An error occurred.",
        "error": {},
        "status_code": None,
    }

    if response is None:
        tb = traceback.extract_tb(exc.__traceback__)
        if tb:
            last_frame = tb[-1]
            location = f'File "{last_frame.filename}", line {last_frame.lineno}, in {last_frame.name}\n    {last_frame.line}'
        else:
            location = "No traceback available"

        exc_type = type(exc).__name__
        exc_msg = str(exc)
        logger.error(
            f"Truly unhandled exception after DRF handler -> {exc_type}: {exc_msg}\n{location}. This should be investigated."
        )

        response_data["error"] = {"detail": "Internal server error"}
        response_data["status_code"] = status.HTTP_500_INTERNAL_SERVER_ERROR

        return Response(data=response_data, status=response_data["status_code"])

    response_data["status_code"] = response.status_code

    if isinstance(exc, ValidationError):
        response_data["message"] = "Validation error"
        response_data["error"] = {"detail": normalize_error_detail(response.data)}
    elif isinstance(exc, AuthenticationFailed):
        response_data["message"] = "Authentication failed"
        response_data["error"] = {"detail": str(exc.detail)}
    elif isinstance(exc, NotAuthenticated):
        response_data["message"] = "Authentication required"
        response_data["error"] = {"detail": str(exc)}
    elif isinstance(exc, MethodNotAllowed):
        response_data["message"] = "Method not allowed"
        response_data["error"] = {"detail": str(exc)}
    elif isinstance(exc, NotFound):
        response_data["message"] = "Not found"
        response_data["error"] = {"detail": str(exc.detail)}
    elif isinstance(exc, Throttled):
        response_data["message"] = "Rate limit exceeded"
        response_data["error"] = {
            "detail": f"Rate limit exceeded. Try again in {exc.wait} seconds."
        }
    else:
        if hasattr(exc, "detail"):
            response_data["error"] = {"detail": str(exc.detail)}
        else:
            response_data["error"] = {
                "detail": "An unknown error occurred. Try again later."
            }

    if hasattr(exc, "status_code"):
        response_data["status_code"] = exc.status_code

    response.data = response_data

    return response


def normalize_error_detail(detail: Any) -> str | List[str] | Dict[str, Any]:
    if isinstance(detail, str):
        return detail

    if isinstance(detail, dict):
        normalized = {}
        for key, value in detail.items():
            if hasattr(value, "__iter__") and not isinstance(value, str):
                if len(value) == 1 and hasattr(value[0], "message"):
                    normalized[key] = str(value[0].message)
                else:
                    values_list = list(value)
                    normalized[key] = (
                        str(values_list[0])
                        if len(values_list) == 1
                        else [
                            str(v.message) if hasattr(v, "message") else str(v)
                            for v in values_list
                        ]
                    )
            else:
                normalized[key] = str(value)
        return normalized

    if hasattr(detail, "__iter__"):
        return [str(item) for item in detail]

    return str(detail)
