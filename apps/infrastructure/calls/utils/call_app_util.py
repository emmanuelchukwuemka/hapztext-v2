"""
Model dump
"""

from typing import Dict, Any
from datetime import datetime
import re

import emoji


EMOJI_REGEX = re.compile(
    "["
    "\U0001f600-\U0001f64f"  # emoticons
    "\U0001f300-\U0001f5ff"  # symbols & pictographs
    "\U0001f680-\U0001f6ff"  # transport & map symbols
    "\U0001f1e0-\U0001f1ff"  # flags
    "\U00002700-\U000027bf"  # dingbats
    "\U0001f900-\U0001f9ff"  # supplemental symbols
    "\U0001fa70-\U0001faff"  # extended-A symbols
    "\U00002600-\U000026ff"  # miscellaneous symbols
    "]+"
)


class CallAppUtil:
    """
    Chat Util
    """

    @staticmethod
    def model_dump(model: object, omit: set | None = None) -> Dict[str, Any]:
        """
        Model dump
        """
        try:
            dict_copy = model.__dict__.copy()
            dict_copy.pop("_state", None)
            new_dict = {}
            join_time = dict_copy.get("join_time")
            if omit:
                if join_time and isinstance(join_time, datetime):
                    new_dict["join_time"] = join_time.isoformat()
                for key, value in dict_copy.items():
                    if key not in omit:
                        new_dict[key] = value
            if join_time and isinstance(join_time, datetime) and not new_dict:
                dict_copy["join_time"] = join_time.isoformat()

            return new_dict if new_dict else dict_copy
        except Exception as exc:
            raise exc

    @staticmethod
    def is_valid_emoji(value: Any) -> None:
        """
        Validates an emoji
        """
        if not isinstance(value, str):
            raise ValueError("emoji must be a string")
        is_valid = value in emoji.EMOJI_DATA
        if not is_valid:
            is_valid = bool(EMOJI_REGEX.fullmatch(value))
        if not is_valid:
            raise ValueError("emoji reaction is invalid")
