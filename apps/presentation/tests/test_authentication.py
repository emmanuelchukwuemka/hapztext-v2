import pytest
from django.urls import reverse
from rest_framework import status
from apps.infrastructure.authentication.models.tables import OTPCode
from apps.presentation.tests.factories import UserFactory, OTPCodeFactory

@pytest.mark.django_db
class TestAuthenticationAPI:
    def test_register_user_success(self, api_client):
        url = reverse('register')
        data = {
            "email": "newuser@example.com",
            "username": "newuser",
            "password": "Password123!",
            "password_confirm": "Password123!",
            "first_name": "New",
            "last_name": "User"
        }
        response = api_client.post(url, data)
        assert response.status_code == status.HTTP_201_CREATED
        assert response.data['success'] is True
        assert response.data['message'] == "Registration successful. An OTP code has been sent to your email for verification."
        
    def test_login_user_success(self, api_client):
        user = UserFactory(password='Password123!', is_email_verified=True)
        url = reverse('login')
        data = {
            "email": user.email,
            "password": "Password123!"
        }
        response = api_client.post(url, data)
        assert response.status_code == status.HTTP_200_OK
        assert 'auth' in response.data['data']['tokens']
        
    def test_request_email_verification_success(self, api_client):
        user = UserFactory(is_email_verified=False)
        url = reverse('request-email-verification')
        data = {
            "email": user.email,
            "purpose": "email_verification"
        }
        response = api_client.post(url, data)
        assert response.status_code == status.HTTP_200_OK
        assert response.data['success'] is True
        assert response.data['message'] == "Email verification OTP code sent successfully."

    def test_verify_email_success(self, api_client):
        user = UserFactory(is_email_verified=False)
        otp = OTPCodeFactory(user=user, code='123456', purpose='email_verification')
        url = reverse('confirm-email-verification')
        data = {
            "email": user.email,
            "otp_code": "123456"
        }
        response = api_client.post(url, data)
        assert response.status_code == status.HTTP_200_OK
        assert response.data['success'] is True
        assert response.data['message'] == "Email verification successful."

    def test_request_password_reset_success(self, api_client):
        user = UserFactory(is_email_verified=True)
        url = reverse('request-password-reset')
        data = {
            "email": user.email,
            "purpose": "password_reset"
        }
        response = api_client.post(url, data)
        assert response.status_code == status.HTTP_200_OK
        assert response.data['success'] is True
        assert response.data['message'] == "Password reset OTP code sent successfully."

    def test_reset_password_success(self, api_client):
        user = UserFactory(is_email_verified=True)
        otp = OTPCodeFactory(user=user, code='123456', purpose='password_reset')
        url = reverse('confirm-password-reset')
        data = {
            "email": user.email,
            "otp_code": "123456",
            "new_password": "NewPassword123!",
            "new_password_confirm": "NewPassword123!"
        }
        response = api_client.post(url, data)
        assert response.status_code == status.HTTP_200_OK
        assert response.data['success'] is True
        assert response.data['message'] == "Password reset successful."
