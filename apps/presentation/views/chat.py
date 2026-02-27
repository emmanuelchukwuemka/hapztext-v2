from dataclasses import asdict

from drf_spectacular.utils import extend_schema
from rest_framework.decorators import (
    api_view,
    parser_classes,
    permission_classes,
    throttle_classes,
)
from rest_framework.parsers import JSONParser, MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.throttling import UserRateThrottle

from apps.application.chat.dtos import (
    ConversationListDTO,
    ConversationMessagesDTO,
    CreateConversationDTO,
    MarkMessagesReadDTO,
    SendMessageDTO,
)
from apps.presentation.responses import StandardResponse
from apps.presentation.serializers.chat import (
    ConversationListSerializer,
    ConversationMessagesSerializer,
    CreateConversationSerializer,
    MarkMessagesReadSerializer,
    MediaUploadSerializer,
    SendMessageSerializer,
)
from apps.presentation.serializers.examples import (
    ErrorResponseExampleSerializer,
    SuccessResponseExampleSerializer,
)

from apps.presentation.rule_registry import (
    get_conversation_messages_rule,
    get_create_conversation_rule,
    get_mark_messages_read_rule,
    get_send_message_rule,
    get_user_conversations_rule,
)


@extend_schema(
    request=CreateConversationSerializer,
    responses={
        201: SuccessResponseExampleSerializer,
        400: ErrorResponseExampleSerializer,
        500: ErrorResponseExampleSerializer,
    },
    description="Create a new private conversation between two users",
    tags=["Chat"],
)
@api_view(["POST"])
@permission_classes([IsAuthenticated])
@throttle_classes([UserRateThrottle])
def create_conversation(request: Request) -> Response:
    serializer = CreateConversationSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    participant_ids = serializer.validated_data["participant_ids"]
    if str(request.user.id) not in participant_ids:
        participant_ids[0] = str(request.user.id)

    create_conversation_rule = get_create_conversation_rule()
    conversation = create_conversation_rule(
        CreateConversationDTO(
            participant_ids=participant_ids,
            conversation_type="private",
        )
    )

    return StandardResponse.created(
        data=asdict(conversation), message="Conversation created successfully."
    )


@extend_schema(
    request=SendMessageSerializer,
    responses={
        201: SuccessResponseExampleSerializer,
        400: ErrorResponseExampleSerializer,
        500: ErrorResponseExampleSerializer,
    },
    description="Send a message in a conversation",
    tags=["Chat"],
)
@api_view(["POST"])
@permission_classes([IsAuthenticated])
@throttle_classes([UserRateThrottle])
def send_message(request: Request, conversation_id: str) -> Response:
    serializer = SendMessageSerializer(
        data=request.data,
        context={"conversation_id": conversation_id, "sender_id": str(request.user.id)},
    )
    serializer.is_valid(raise_exception=True)

    send_message_rule = get_send_message_rule()
    message = send_message_rule(SendMessageDTO(**serializer.validated_data))

    return StandardResponse.created(
        data=asdict(message), message="Message sent successfully."
    )


@extend_schema(
    responses={
        200: SuccessResponseExampleSerializer,
        400: ErrorResponseExampleSerializer,
        500: ErrorResponseExampleSerializer,
    },
    description="Get messages in a conversation with pagination",
    tags=["Chat"],
)
@api_view(["GET"])
@permission_classes([IsAuthenticated])
@throttle_classes([UserRateThrottle])
def get_conversation_messages(
    request: Request, conversation_id: str, page: int, page_size: int
) -> Response:
    serializer = ConversationMessagesSerializer(
        data={"page": page, "page_size": page_size},
        context={"conversation_id": conversation_id, "user_id": str(request.user.id)},
    )
    serializer.is_valid(raise_exception=True)

    get_messages_rule = get_conversation_messages_rule()
    messages_data = get_messages_rule(
        ConversationMessagesDTO(**serializer.validated_data)
    )

    return StandardResponse.success(
        data=asdict(messages_data), message="Messages fetched successfully."
    )


@extend_schema(
    responses={
        200: SuccessResponseExampleSerializer,
        400: ErrorResponseExampleSerializer,
        500: ErrorResponseExampleSerializer,
    },
    description="Get all conversations for the current user",
    tags=["Chat"],
)
@api_view(["GET"])
@permission_classes([IsAuthenticated])
@throttle_classes([UserRateThrottle])
def get_conversations(request: Request, page: int, page_size: int) -> Response:
    serializer = ConversationListSerializer(
        data={"page": page, "page_size": page_size},
        context={"user_id": str(request.user.id)},
    )
    serializer.is_valid(raise_exception=True)

    get_conversations_rule = get_user_conversations_rule()
    conversations_data = get_conversations_rule(
        ConversationListDTO(**serializer.validated_data)
    )

    return StandardResponse.success(
        data=asdict(conversations_data), message="Conversations fetched successfully."
    )


@extend_schema(
    request=MarkMessagesReadSerializer,
    responses={
        200: SuccessResponseExampleSerializer,
        400: ErrorResponseExampleSerializer,
        500: ErrorResponseExampleSerializer,
    },
    description="Mark messages as read in a conversation",
    tags=["Chat"],
)
@api_view(["POST"])
@permission_classes([IsAuthenticated])
@throttle_classes([UserRateThrottle])
def mark_messages_read(request: Request, conversation_id: str) -> Response:
    serializer = MarkMessagesReadSerializer(
        data=request.data,
        context={"conversation_id": conversation_id, "user_id": str(request.user.id)},
    )
    serializer.is_valid(raise_exception=True)

    mark_read_rule = get_mark_messages_read_rule()
    mark_read_rule(MarkMessagesReadDTO(**serializer.validated_data))

    return StandardResponse.success(message="Messages marked as read successfully.")


@extend_schema(
    request=MediaUploadSerializer,
    responses={
        201: SuccessResponseExampleSerializer,
        400: ErrorResponseExampleSerializer,
        500: ErrorResponseExampleSerializer,
    },
    description="Upload media file for chat message",
    tags=["Chat"],
)
@api_view(["POST"])
@permission_classes([IsAuthenticated])
@throttle_classes([UserRateThrottle])
@parser_classes([MultiPartParser])
def upload_media(request: Request) -> Response:
    """
    Upload media file and return URL to use in message
    """
    from apps.infrastructure.chat.storage import save_chat_media

    serializer = MediaUploadSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    file = serializer.validated_data["file"]
    message_type = serializer.validated_data["message_type"]

    try:
        media_url = save_chat_media(file, message_type, str(request.user.id))

        return StandardResponse.created(
            data={"media_url": media_url, "message_type": message_type},
            message="Media uploaded successfully.",
        )
    except Exception as e:
        from loguru import logger

        logger.error(f"Failed to upload media: {e}")
        return StandardResponse.error(
            data={"error": "Failed to upload media file"},
            message="Media upload failed.",
            status_code=500,
        )
