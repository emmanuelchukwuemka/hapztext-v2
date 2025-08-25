from typing import Any, Dict

from apps.application.authentication.ports import OTPCodeRepositoryInterface
from apps.domain.authentication.entities import OTPCode as DomainOTPCode
from apps.domain.authentication.enums import OTPCodePurpose
from apps.infrastructure.authentication.models import OTPCode


def to_domain_otp_code_data(django_otp_code: OTPCode) -> DomainOTPCode:
    return DomainOTPCode(
        user_id=django_otp_code.user_id,
        purpose=django_otp_code.purpose,
        code=django_otp_code.code,
        id=django_otp_code.id,
        created_at=django_otp_code.created_at,
        expires_at=django_otp_code.expires_at,
    )


def to_django_otp_code_data(domain_otp_code: DomainOTPCode) -> Dict[str, Any]:
    return {
        "user_id": domain_otp_code.user_id,
        "purpose": domain_otp_code.purpose,
    }


class DjangoOTPCodeRepository(OTPCodeRepositoryInterface):
    def create(self, otp_code: DomainOTPCode) -> DomainOTPCode:
        django_otp_code = to_django_otp_code_data(otp_code)

        created_otp_code = OTPCode.objects.create(**django_otp_code)
        return to_domain_otp_code_data(created_otp_code)

    def find_by_code(self, code: str) -> DomainOTPCode | None:
        try:
            django_otp_code = OTPCode.objects.get(code=code)
            return to_domain_otp_code_data(django_otp_code)

        except OTPCode.DoesNotExist:
            return None

    def has_valid_code(self, user_id: str, purpose: OTPCodePurpose) -> bool:
        existing_otp_code = OTPCode.objects.filter(user_id=user_id).first()
        if existing_otp_code:
            if existing_otp_code.purpose == purpose and existing_otp_code.is_valid():
                return True

            existing_otp_code.delete()

        return False

    def delete_by_code(self, code: str) -> None:
        try:
            OTPCode.objects.get(code=code).delete()
        except OTPCode.DoesNotExist:
            pass
