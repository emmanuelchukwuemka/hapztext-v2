import pytest
from django.urls import reverse
from rest_framework import status
from apps.presentation.tests.factories import UserFactory, PostFactory

@pytest.mark.django_db
class TestPostsAPI:
    def test_create_post_success(self, authenticated_client, user):
        url = reverse('create-post')
        data = {
            "post_format": "text",
            "text_content": "This is a test post content."
        }
        response = authenticated_client.post(url, data, format='json')
        assert response.status_code == status.HTTP_201_CREATED
        assert response.data['success'] is True
        assert response.data['data']['text_content'] == "This is a test post content."

    def test_fetch_posts_list_success(self, authenticated_client, user):
        PostFactory.create_batch(5, sender=user)
        url = reverse('fetch-posts-list', kwargs={'page': 1, 'page_size': 10})
        response = authenticated_client.get(url)
        assert response.status_code == status.HTTP_200_OK
        assert len(response.data['data']['result']) >= 5

    def test_fetch_user_posts_success(self, authenticated_client, user, second_user):
        PostFactory.create_batch(3, sender=second_user)
        url = reverse('fetch-user-posts', kwargs={
            'user_id': second_user.id,
            'page': 1,
            'page_size': 10
        })
        response = authenticated_client.get(url)
        assert response.status_code == status.HTTP_200_OK
        assert len(response.data['data']['result']) >= 3

    def test_delete_post_success(self, authenticated_client, user):
        post = PostFactory(sender=user)
        url = reverse('delete-post', kwargs={'post_id': post.id})
        response = authenticated_client.delete(url)
        assert response.status_code == status.HTTP_204_NO_CONTENT

    def test_react_to_post_success(self, authenticated_client, user, second_user):
        post = PostFactory(sender=second_user)
        url = reverse('react-to-post', kwargs={'post_id': post.id})
        data = {"reaction": "👍"}
        response = authenticated_client.post(url, data, format='json')
        assert response.status_code == status.HTTP_201_CREATED
        assert response.data['data']['reaction'] == "👍"

    def test_remove_post_reaction_success(self, authenticated_client, user, second_user):
        post = PostFactory(sender=second_user)
        # React first
        url_react = reverse('react-to-post', kwargs={'post_id': post.id})
        authenticated_client.post(url_react, {"reaction": "👍"}, format='json')
        
        url_remove = reverse('remove-post-reaction', kwargs={'post_id': post.id})
        response = authenticated_client.delete(url_remove)
        assert response.status_code == status.HTTP_204_NO_CONTENT

    def test_share_post_success(self, authenticated_client, user, second_user):
        post = PostFactory(sender=second_user)
        url = reverse('share-post', kwargs={'post_id': post.id})
        data = {"shared_with_message": "Check this out!"}
        response = authenticated_client.post(url, data, format='json')
        assert response.status_code == status.HTTP_201_CREATED
        assert response.data['data']['shared_with_message'] == "Check this out!"
