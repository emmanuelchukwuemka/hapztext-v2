from django.urls import path

from apps.presentation.views.notifications import (
    get_notification_preferences,
    get_notifications,
    mark_notifications_read,
    notifications_stream_view,
    update_notification_preferences,
)

urlpatterns = [
    path("<int:page>/<int:page_size>/", get_notifications, name="get-notifications"),
    path("mark-read/", mark_notifications_read, name="mark-notifications-read"),
    path(
        "preferences/",
        get_notification_preferences,
        name="get-notification-preferences",
    ),
    path(
        "preferences/update/",
        update_notification_preferences,
        name="update-notification-preferences",
    ),
    path("stream/", notifications_stream_view, name="notifications-stream"),
]
