from dataclasses import dataclass

from .enums import OTPCodePurpose


@dataclass(frozen=True)
class Purpose:
    value: str

    def __post_init__(self):
        if not self._is_valid():
            raise ValueError(
                f"Invalid Purpose. Select a value from {OTPCodePurpose.values()}."
            )

    def _is_valid(self) -> bool:
        return self.value in OTPCodePurpose.values()
