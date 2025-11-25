"""
Calls
"""

from django.urls import path

from apps.infrastructure.calls.views import (
    create_new_call,
)

urlpatterns = [
    path("", create_new_call, name="create-new-call"),
]
