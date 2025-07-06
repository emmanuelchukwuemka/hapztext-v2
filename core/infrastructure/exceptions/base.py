from typing import Any

from rest_framework import status
from rest_framework.exceptions import APIException


class BaseAPIException(APIException):
    status_code = status.HTTP_500_INTERNAL_SERVER_ERROR
    default_detail = "An unknown error occurred."
    default_code = "api_error"

    def __init__(self, detail: Any = None, code: str | None = None) -> None:
        if detail is None:
            detail = self.default_detail
        if code is None:
            code = self.default_code

        super().__init__(detail=detail, code=code)


class ConflictError(BaseAPIException):
    status_code = status.HTTP_409_CONFLICT
    default_detail = "Database constraint violation occurred."
    default_code = "conflict"


class UnprocessableEntityError(BaseAPIException):
    status_code = status.HTTP_422_UNPROCESSABLE_ENTITY
    default_detail = "Unable to process provided data."
    default_code = "unprocessable_entity"


class BadRequestError(BaseAPIException):
    status_code = status.HTTP_400_BAD_REQUEST
    default_detail = "Bad request"
    default_code = "bad_request"
