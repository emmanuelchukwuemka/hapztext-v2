from django.urls import path


from apps.presentation.views.chat import (
    create_conversation,
    get_conversation_messages,
    get_conversations,
    mark_messages_read,
    send_message,
    upload_media,
)

urlpatterns = [
    path("conversations/", create_conversation, name="create-conversation"),
    path(
        "conversations/<str:conversation_id>/messages/<int:page>/<int:page_size>/",
        get_conversation_messages,
        name="get-conversation-messages",
    ),
    path(
        "conversations/<int:page>/<int:page_size>/",
        get_conversations,
        name="get-conversations",
    ),
    path(
        "conversations/<str:conversation_id>/messages/mark-read/",
        mark_messages_read,
        name="mark-messages-read",
    ),
    path(
        "conversations/<str:conversation_id>/messages/",
        send_message,
        name="send-message",
    ),
    path("media/upload/", upload_media, name="upload-media"),
]
