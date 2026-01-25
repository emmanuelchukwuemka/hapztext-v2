from dataclasses import asdict
from datetime import UTC, datetime
from typing import List

from apps.domain.chat.entities import Conversation, ConversationParticipant, Message

from .dtos import (
    ConversationListDTO,
    ConversationMessagesDTO,
    ConversationResponseDTO,
    CreateConversationDTO,
    MarkMessagesReadDTO,
    MessageResponseDTO,
    PaginatedConversationsResponseDTO,
    PaginatedMessagesResponseDTO,
    SendMessageDTO,
)
from .ports import (
    ChatWebSocketServiceInterface,
    ConversationParticipantRepositoryInterface,
    ConversationRepositoryInterface,
    MessageRepositoryInterface,
)


class CreateConversationRule:
    def __init__(
        self,
        conversation_repository: ConversationRepositoryInterface,
        participant_repository: ConversationParticipantRepositoryInterface,
        message_repository: MessageRepositoryInterface,
    ) -> None:
        self.conversation_repository = conversation_repository
        self.participant_repository = participant_repository
        self.message_repository = message_repository

    def __call__(self, dto: CreateConversationDTO) -> ConversationResponseDTO:
        if dto.conversation_type == "private" and len(dto.participant_ids) != 2:
            raise ValueError("Private conversations must have exactly 2 participants")

        if dto.conversation_type == "private":
            existing = self.conversation_repository.find_private_conversation(
                dto.participant_ids[0], dto.participant_ids[1]
            )
            if existing:
                return ConversationResponseDTO(
                    **{
                        key: value
                        for key, value in asdict(existing).items()
                        if key in ConversationResponseDTO.__dataclass_fields__
                    }
                )

        conversation = Conversation(
            conversation_type=dto.conversation_type,
            participant_ids=dto.participant_ids,
        )

        created_conversation = self.conversation_repository.create(conversation)

        participants = [
            ConversationParticipant(
                conversation_id=created_conversation.id,
                user_id=user_id,
            )
            for user_id in dto.participant_ids
        ]
        self.participant_repository.add_participants(participants)

        last_message = self.message_repository.get_last_message(created_conversation.id)

        return ConversationResponseDTO(
            id=created_conversation.id,
            conversation_type=created_conversation.conversation_type,
            participant_ids=dto.participant_ids,
            created_at=created_conversation.created_at,
            updated_at=created_conversation.updated_at,
            last_message_at=created_conversation.last_message_at,
            last_message=last_message,
        )


class SendMessageRule:
    def __init__(
        self,
        message_repository: MessageRepositoryInterface,
        conversation_repository: ConversationRepositoryInterface,
        participant_repository: ConversationParticipantRepositoryInterface,
        chat_service: ChatWebSocketServiceInterface,
    ) -> None:
        self.message_repository = message_repository
        self.conversation_repository = conversation_repository
        self.participant_repository = participant_repository
        self.chat_service = chat_service

    def __call__(self, dto: SendMessageDTO) -> MessageResponseDTO:
        conversation = self.conversation_repository.find_by_id(dto.conversation_id)
        if not conversation:
            raise ValueError("Conversation not found")

        if not self.participant_repository.is_participant(
            dto.conversation_id, dto.sender_id
        ):
            raise ValueError("User is not a participant in this conversation")

        if dto.message_type == "text" and not dto.text_content:
            raise ValueError("Text messages must have content")
        if dto.message_type in ["image", "audio", "video"] and not dto.media_url:
            raise ValueError(f"{dto.message_type} messages must have media_url")
        if dto.is_reply:
            if not dto.previous_message_id:
                raise ValueError("Previous message id required for reply messages")
            else:
                if not self.message_repository.find_by_id(dto.previous_message_id):
                    raise ValueError("Previous message not found")

        message = Message(
            conversation_id=dto.conversation_id,
            sender_id=dto.sender_id,
            message_type=dto.message_type,
            text_content=dto.text_content,
            media_url=dto.media_url,
            is_reply=dto.is_reply,
            previous_message_id=dto.previous_message_id,
        )

        created_message = self.message_repository.create(message)

        message_data = asdict(created_message)
        self.chat_service.send_message_to_conversation(
            dto.conversation_id, message_data
        )

        self.conversation_repository.update_last_message_time(dto.conversation_id)

        return MessageResponseDTO(
            **{
                key: value
                for key, value in message_data.items()
                if key in MessageResponseDTO.__dataclass_fields__
            }
        )


class GetConversationMessagesRule:
    def __init__(
        self,
        message_repository: MessageRepositoryInterface,
        participant_repository: ConversationParticipantRepositoryInterface,
    ) -> None:
        self.message_repository = message_repository
        self.participant_repository = participant_repository

    def __call__(self, dto: ConversationMessagesDTO) -> PaginatedMessagesResponseDTO:
        if not self.participant_repository.is_participant(
            dto.conversation_id, dto.user_id
        ):
            raise ValueError("User is not a participant in this conversation")

        messages, previous_link, next_link, total = (
            self.message_repository.get_conversation_messages(
                dto.conversation_id, dto.page, dto.page_size
            )
        )

        messages_data = [
            MessageResponseDTO(
                **{
                    key: value
                    for key, value in asdict(message).items()
                    if key in MessageResponseDTO.__dataclass_fields__
                }
            )
            for message in messages
        ]

        return PaginatedMessagesResponseDTO(
            messages=messages_data,
            previous_link=previous_link,
            next_link=next_link,
            total_count=total,
        )


class GetUserConversationsRule:
    def __init__(
        self,
        conversation_repository: ConversationRepositoryInterface,
        message_repository: MessageRepositoryInterface,
    ) -> None:
        self.conversation_repository = conversation_repository
        self.message_repository = message_repository

    def __call__(self, dto: ConversationListDTO) -> PaginatedConversationsResponseDTO:
        conversations, previous_link, next_link = (
            self.conversation_repository.get_user_conversations(
                dto.user_id, dto.page, dto.page_size
            )
        )

        conversations_data = []
        for conversation in conversations:
            conv_dict = asdict(conversation)

            last_message = self.message_repository.get_last_message(conversation.id)
            conv_dict["last_message"] = asdict(last_message) if last_message else None

            unread_count = self.message_repository.get_unread_count(
                conversation.id, dto.user_id
            )
            conv_dict["unread_count"] = unread_count

            conversations_data.append(
                ConversationResponseDTO(
                    **{
                        key: value
                        for key, value in conv_dict.items()
                        if key in ConversationResponseDTO.__dataclass_fields__
                    }
                )
            )

        return PaginatedConversationsResponseDTO(
            conversations=conversations_data,
            previous_link=previous_link,
            next_link=next_link,
        )


class MarkMessagesAsReadRule:
    def __init__(
        self,
        message_repository: MessageRepositoryInterface,
        participant_repository: ConversationParticipantRepositoryInterface,
    ) -> None:
        self.message_repository = message_repository
        self.participant_repository = participant_repository

    def __call__(self, dto: MarkMessagesReadDTO) -> None:
        if not self.participant_repository.is_participant(
            dto.conversation_id, dto.user_id
        ):
            raise ValueError("User is not a participant in this conversation")

        self.message_repository.mark_as_read(
            dto.conversation_id, dto.user_id, dto.message_ids
        )
