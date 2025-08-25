from typing import Any

from rest_framework import status
from rest_framework.response import Response


class StandardResponse:
    @staticmethod
    def success(
        data: Any = None,
        message: str = "Resource action successful.",
        status_code: int = status.HTTP_200_OK,
    ) -> Response:
        return Response(
            {
                "success": True,
                "message": message,
                "data": data,
                "status_code": status_code,
            },
            status=status_code,
        )

    @staticmethod
    def created(
        data: Any = None, message: str = "Resource creation successful."
    ) -> Response:
        return StandardResponse.success(
            data=data, message=message, status_code=status.HTTP_201_CREATED
        )

    @staticmethod
    def updated(
        data: Any = None, message: str = "Resource update successful."
    ) -> Response:
        return StandardResponse.success(
            data=data, message=message, status_code=status.HTTP_202_ACCEPTED
        )

    @staticmethod
    def deleted(message: str = "Resource deletion successful.") -> Response:
        return Response(
            {"success": True, "message": message}, status=status.HTTP_204_NO_CONTENT
        )
