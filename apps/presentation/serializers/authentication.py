import re

from rest_framework import serializers


class CreateUserSerializer(serializers.Serializer):
    email = serializers.EmailField(required=True)
    username = serializers.CharField(required=True)
    password = serializers.CharField(required=True)
    password_confirm = serializers.CharField(required=True)

    def validate_password(self, value) -> str:
        if " " in value:
            raise serializers.ValidationError("Password must not contain spaces.")

        if not re.search(r"[a-z]", value):
            raise serializers.ValidationError(
                "Password must contain at least one lowercase character."
            )

        if not re.search(r"[A-Z]", value):
            raise serializers.ValidationError(
                "Password must contain at least one uppercase character."
            )

        if not re.search(r"[~!@#$%^&*()-=+:;,./<>?]", value):
            raise serializers.ValidationError(
                "Password must contain at least one special character."
            )

        return value


class LoginSerializer(serializers.Serializer):
    email = serializers.EmailField(required=True)
    password = serializers.CharField(required=True)


class VerifyEmailSerializer(serializers.Serializer):
    email = serializers.EmailField(required=True)
    otp_code = serializers.CharField(required=True)


class LogoutSerializer(serializers.Serializer):
    auth_token = serializers.CharField(required=True)


class PasswordResetRequestSerializer(serializers.Serializer):
    email = serializers.EmailField(required=True)
    purpose = serializers.CharField(required=False, default="password_reset")

    def validate_purpose(self, value) -> str:
        value = "password_reset"
        return value


class EmailVerificationRequestSerializer(serializers.Serializer):
    email = serializers.EmailField(required=True)
    purpose = serializers.CharField(required=False, default="email_verification")

    def validate_purpose(self, value) -> str:
        value = "email_verification"
        return value


class PasswordResetConfirmSerializer(serializers.Serializer):
    new_password = serializers.CharField(required=True)
    new_password_confirm = serializers.CharField(required=False)
    otp_code = serializers.CharField(required=True)

    def validate_new_password(self, value) -> str:
        if " " in value:
            raise serializers.ValidationError("Password must not contain spaces.")

        if not re.search(r"[a-z]", value):
            raise serializers.ValidationError(
                "Password must contain at least one lowercase character."
            )

        if not re.search(r"[A-Z]", value):
            raise serializers.ValidationError(
                "Password must contain at least one uppercase character."
            )

        if not re.search(r"[~!@#$%^&*()-=+:;,./<>?]", value):
            raise serializers.ValidationError(
                "Password must contain at least one special character."
            )

        return value
