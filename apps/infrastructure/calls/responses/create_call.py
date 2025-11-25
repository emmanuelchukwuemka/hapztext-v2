"""
Create call
"""

from drf_spectacular.utils import OpenApiExample

CallCreateRequestExample = OpenApiExample(
    name="Call Creation Request",
    value={
        "call_type": "voice",
        "title": "New call",
        "participant_ids": ["O4yLfpn-7A6D4xV6aVe8b"],
    },
    request_only=True,
    description="Example of a successful call creation request body.",
)
