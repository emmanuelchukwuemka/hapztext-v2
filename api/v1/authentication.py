from django.urls import path

from apps.authentication.presentation.views import (
    login_user,
    logout_user,
    register_user,
    request_password_reset,
    reset_password,
    verify_email,
)

urlpatterns = [
    path("register/", register_user, name="register"),
    path("login/", login_user, name="login"),
    path("verify-email/", verify_email, name="verify-email"),
    path("logout/", logout_user, name="logout"),
    path("password-reset/", request_password_reset, name="request-password-reset"),
    path("password-reset/confirm/", reset_password, name="confirm-password-reset"),
]