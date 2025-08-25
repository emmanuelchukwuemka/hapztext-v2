from django.urls import path

from apps.presentation.views.authentication import (
    login_user,
    logout_user,
    register_user,
    request_email_verification,
    request_password_reset,
    reset_password,
    verify_email,
)

urlpatterns = [
    path("register/", register_user, name="register"),
    path("login/", login_user, name="login"),
    path(
        "verify-email/request/",
        request_email_verification,
        name="request-email-verification",
    ),
    path("verify-email/", verify_email, name="confirm-email-verification"),
    path("logout/", logout_user, name="logout"),
    path(
        "password-reset/request/", request_password_reset, name="request-password-reset"
    ),
    path("password-reset/", reset_password, name="confirm-password-reset"),
]
