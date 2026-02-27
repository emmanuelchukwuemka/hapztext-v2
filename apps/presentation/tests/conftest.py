import pytest
from rest_framework.test import APIClient
from apps.presentation.tests.factories import UserFactory

@pytest.fixture
def api_client():
    return APIClient()

@pytest.fixture
def authenticated_client(api_client, user):
    api_client.force_authenticate(user=user)
    return api_client

@pytest.fixture
def user(db):
    return UserFactory()

@pytest.fixture
def second_user(db):
    return UserFactory()

@pytest.fixture(autouse=True)
def mock_eventstream(monkeypatch):
    try:
        import django_eventstream
        monkeypatch.setattr("django_eventstream.send_event", lambda *args, **kwargs: None)
    except ImportError:
        pass
