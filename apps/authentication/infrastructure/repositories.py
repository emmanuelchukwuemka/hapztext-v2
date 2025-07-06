from typing import Any, Dict

from ..application.ports import OTPCodeRepositoryInterface
from ..domain.entities import OTPCode as DomainOTPCode
from ..domain.enums import OTPCodePurpose
from ..infrastructure.models import OTPCode


class DjangoOTPCodeRepository(OTPCodeRepositoryInterface):
    def create(self, otp_code: DomainOTPCode) -> DomainOTPCode:
        django_otp_code = self._to_django_otp_code_data(otp_code)

        created_otp_code = OTPCode.objects.create(**django_otp_code)
        return self._to_domain_otp_code_data(created_otp_code)

    def find_by_code(self, code: str) -> DomainOTPCode | None:
        try:
            django_otp_code = OTPCode.objects.get(code=code)
            return self._to_domain_otp_code_data(django_otp_code)

        except OTPCode.DoesNotExist:
            return None

    def has_valid_code(self, user_id: str, purpose: OTPCodePurpose) -> bool:
        existing_otp_code = OTPCode.objects.filter(user_id=user_id).first()
        if existing_otp_code:
            if existing_otp_code.purpose == purpose and existing_otp_code.is_valid():
                return True

            existing_otp_code.delete()

        return False

    def _to_django_otp_code_data(
        self, domain_otp_code: DomainOTPCode
    ) -> Dict[str, Any]:
        return {
            "user_id": domain_otp_code.user_id,
            "purpose": domain_otp_code.purpose,
            "code": domain_otp_code.code,
        }

    def _to_domain_otp_code_data(self, django_otp_code: OTPCode) -> DomainOTPCode:
        return DomainOTPCode(
            user_id=django_otp_code.user_id,
            purpose=django_otp_code.purpose,
            code=django_otp_code.code,
            id=django_otp_code.id,
            created_at=django_otp_code.created_at,
            expires_at=django_otp_code.expires_at,
        )
