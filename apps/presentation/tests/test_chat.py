import pytest
from django.urls import reverse
from rest_framework import status
from apps.presentation.tests.factories import UserFactory, ConversationFactory, MessageFactory, ConversationParticipantFactory

@pytest.mark.django_db
class TestChatAPI:
    def test_create_conversation_success(self, authenticated_client, user, second_user):
        url = reverse('create-conversation')
        data = {
            "participant_ids": [str(user.id), str(second_user.id)]
        }
        response = authenticated_client.post(url, data, format='json')
        assert response.status_code == status.HTTP_201_CREATED
        assert response.data['success'] is True
        assert len(response.data['data']['participant_ids']) == 2

    def test_send_message_success(self, authenticated_client, user, second_user):
        conversation = ConversationFactory()
        ConversationParticipantFactory(conversation=conversation, user=user)
        ConversationParticipantFactory(conversation=conversation, user=second_user)
        
        url = reverse('send-message', kwargs={'conversation_id': conversation.id})
        data = {
            "message_type": "text",
            "text_content": "Hello there!"
        }
        response = authenticated_client.post(url, data, format='json')
        assert response.status_code == status.HTTP_201_CREATED
        assert response.data['data']['text_content'] == "Hello there!"

    def test_get_conversation_messages_success(self, authenticated_client, user, second_user):
        conversation = ConversationFactory()
        ConversationParticipantFactory(conversation=conversation, user=user)
        ConversationParticipantFactory(conversation=conversation, user=second_user)
        MessageFactory.create_batch(5, conversation=conversation, sender=user)
        
        url = reverse('get-conversation-messages', kwargs={
            'conversation_id': conversation.id,
            'page': 1,
            'page_size': 10
        })
        response = authenticated_client.get(url)
        assert response.status_code == status.HTTP_200_OK
        assert len(response.data['data']['messages']) >= 5

    def test_get_conversations_success(self, authenticated_client, user, second_user):
        conversation = ConversationFactory()
        ConversationParticipantFactory(conversation=conversation, user=user)
        ConversationParticipantFactory(conversation=conversation, user=second_user)
        
        url = reverse('get-conversations', kwargs={'page': 1, 'page_size': 10})
        response = authenticated_client.get(url)
        assert response.status_code == status.HTTP_200_OK
        assert len(response.data['data']['conversations']) >= 1

    def test_mark_messages_read_success(self, authenticated_client, user, second_user):
        conversation = ConversationFactory()
        ConversationParticipantFactory(conversation=conversation, user=user)
        ConversationParticipantFactory(conversation=conversation, user=second_user)
        messages = MessageFactory.create_batch(3, conversation=conversation, sender=second_user)
        
        url = reverse('mark-messages-read', kwargs={'conversation_id': conversation.id})
        data = {
            "message_ids": [str(m.id) for m in messages]
        }
        response = authenticated_client.post(url, data, format='json')
        assert response.status_code == status.HTTP_200_OK
        assert response.data['success'] is True
