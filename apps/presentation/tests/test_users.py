import pytest
from django.urls import reverse
from rest_framework import status
from apps.presentation.tests.factories import UserFactory, UserProfileFactory

@pytest.mark.django_db
class TestUsersAPI:
    def test_fetch_user_success(self, authenticated_client, user):
        url = reverse('fetch-user')
        response = authenticated_client.get(url)
        assert response.status_code == status.HTTP_200_OK
        assert response.data['data']['email'] == user.email

    def test_update_user_success(self, authenticated_client, user):
        url = reverse('update-user')
        data = {"username": "updated_username"}
        response = authenticated_client.put(url, data)
        assert response.status_code == status.HTTP_202_ACCEPTED
        assert response.data['data']['username'] == "updated_username"

    def test_create_user_profile_success(self, authenticated_client):
        url = reverse('create-user-profile')
        data = {
            "first_name": "John",
            "last_name": "Doe",
            "bio": "A test bio",
            "occupation": "Tester"
        }
        response = authenticated_client.post(url, data)
        assert response.status_code == status.HTTP_201_CREATED
        assert response.data['data']['first_name'] == "John"

    def test_fetch_user_profile_success(self, authenticated_client, user):
        profile = UserProfileFactory(user=user)
        url = reverse('fetch-user-profile', kwargs={'user_id': user.id})
        response = authenticated_client.get(url)
        assert response.status_code == status.HTTP_200_OK
        assert response.data['data']['user_id'] == user.id

    def test_update_user_profile_success(self, authenticated_client, user):
        profile = UserProfileFactory(user=user)
        url = reverse('update-user-profile')
        data = {"bio": "Updated bio"}
        response = authenticated_client.put(url, data)
        assert response.status_code == status.HTTP_202_ACCEPTED
        assert response.data['data']['bio'] == "Updated bio"

    def test_fetch_profiles_list_success(self, authenticated_client):
        UserProfileFactory.create_batch(5)
        url = reverse('fetch-profiles-list', kwargs={'page': 1, 'page_size': 10})
        response = authenticated_client.get(url)
        assert response.status_code == status.HTTP_200_OK
        assert len(response.data['data']['result']) >= 5

    def test_send_follow_request_success(self, authenticated_client, user, second_user):
        UserProfileFactory(user=user)
        UserProfileFactory(user=second_user)
        url = reverse('send-follow-request', kwargs={'user_id': second_user.id})
        response = authenticated_client.post(url)
        assert response.status_code == status.HTTP_201_CREATED
        assert response.data['success'] is True

    def test_search_users_success(self, authenticated_client):
        target = UserFactory(username="search_target")
        UserProfileFactory(user=target)
        url = reverse('search-users')
        response = authenticated_client.get(url, {'query': 'search_target'})
        assert response.status_code == status.HTTP_200_OK
        assert len(response.data['data']['users']) >= 1
