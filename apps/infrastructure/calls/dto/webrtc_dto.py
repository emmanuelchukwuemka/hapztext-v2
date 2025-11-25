"""
Web RTC DTO
"""

from typing import Dict, Optional
import dataclasses

from apps.infrastructure.calls.custom_exceptions import CustomWebRTCMediaStateError


@dataclasses.dataclass
class MediaStateValidatorDto:
    """
    MediaStateValidator
    """

    type: str
    audio: Dict[str, bool]
    video: Dict[str, bool]
    screen: Optional[Dict[str, bool]] = None
    device_info: Optional[Dict[str, str]] = None

    ALLOWED_SPECIAL_DEVICE_IDS = {
        "default",
        "communications",
        "screen-share",
    }

    def validate(self) -> None:
        """
        Validate the combined WebRTC media and device state.


        sample: {
            "type": "media_state",
            "audio": {
                "enabled": true,
                "muted": false
            },
            "video": {
                "enabled": true,
                "muted": false
            },
            "screen": {
                "sharing": false
            },
            "device_info": {
                "audio_input_id": "default",
                "video_input_id": "front-camera-uuid",
                "audio_output_id": "default",
                "screen_input_id": "screen-share",
            },
        }

        """
        if self.type != "media_state":
            raise CustomWebRTCMediaStateError("type must be 'media_state'")

        # ########################## AUDIO ##########################
        if not isinstance(self.audio, dict):
            raise CustomWebRTCMediaStateError("audio must be an object")

        for key in ["enabled", "muted"]:
            if key in self.audio and not isinstance(self.audio[key], bool):
                raise CustomWebRTCMediaStateError(f"audio.{key} must be a boolean")

        # ########################## VIDEO ##########################
        if not isinstance(self.video, dict):
            raise CustomWebRTCMediaStateError("video must be an object")

        for key in ["enabled", "muted"]:
            if key in self.video and not isinstance(self.video[key], bool):
                raise CustomWebRTCMediaStateError(f"video.{key} must be a boolean")

        # ########################## SCREEN ##########################
        if self.screen:
            if not isinstance(self.screen, dict):
                raise CustomWebRTCMediaStateError("screen must be an object")

            if "sharing" in self.screen and not isinstance(
                self.screen["sharing"], bool
            ):
                raise CustomWebRTCMediaStateError("screen.sharing must be boolean")

        # ########################## DEVICE INFO ##########################
        if self.device_info:
            if not isinstance(self.device_info, dict):
                raise CustomWebRTCMediaStateError("device_info must be an object")

            for key, value in self.device_info.items():
                if not isinstance(value, str):
                    raise CustomWebRTCMediaStateError(
                        f"device_info.{key} must be a string"
                    )

                # Validate device ID patterns
                if value.strip() == "":
                    raise CustomWebRTCMediaStateError(
                        f"device_info.{key} cannot be empty"
                    )

                # Allow browser-provided full UUIDs or "default"
                if (
                    value not in self.ALLOWED_SPECIAL_DEVICE_IDS
                    and not self._looks_like_device_uuid(value)
                ):
                    raise CustomWebRTCMediaStateError(
                        f"device_info.{key} ('{value}') is not a valid device ID"
                    )

    @staticmethod
    def _looks_like_device_uuid(value: str) -> bool:
        """
        Device UUIDs usually look like:
        - "abcd1234abcd1234"
        - "{long-hardware-id}"
        - Chrome often returns 32-36 character IDs

        This checks for realistic length.
        """
        return 8 <= len(value) <= 64
