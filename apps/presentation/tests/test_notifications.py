import pytest
from django.urls import reverse
from rest_framework import status
from apps.presentation.tests.factories import NotificationFactory

@pytest.mark.django_db
class TestNotificationsAPI:
    def test_get_notifications_success(self, authenticated_client, user):
        NotificationFactory.create_batch(5, recipient=user)
        url = reverse('get-notifications', kwargs={'page': 1, 'page_size': 10})
        response = authenticated_client.get(url)
        assert response.status_code == status.HTTP_200_OK
        assert response.data['success'] is True
        assert len(response.data['data']['result']) >= 5

    def test_mark_notifications_read_success(self, authenticated_client, user):
        notifications = NotificationFactory.create_batch(3, recipient=user)
        url = reverse('mark-notifications-read')
        data = {
            "notification_ids": [str(n.id) for n in notifications]
        }
        response = authenticated_client.post(url, data, format='json')
        assert response.status_code == status.HTTP_200_OK
        assert response.data['success'] is True

    def test_get_notification_preferences_success(self, authenticated_client, user):
        url = reverse('get-notification-preferences')
        response = authenticated_client.get(url)
        assert response.status_code == status.HTTP_200_OK
        assert 'post_notifications_enabled' in response.data['data']

    def test_update_notification_preferences_success(self, authenticated_client, user):
        url = reverse('update-notification-preferences')
        data = {
            "post_notifications_enabled": False,
            "follow_notifications_enabled": False
        }
        response = authenticated_client.put(url, data, format='json')
        assert response.status_code == status.HTTP_200_OK
        assert response.data['data']['post_notifications_enabled'] is False
