"""
Discover Repository
Handles Redis-based presence tracking for Discover mode
"""

from typing import List, Dict, Any, Optional
import datetime
import logging
from redis.asyncio import Redis

logger = logging.Logger(__name__)


class DiscoverRepository:
    """
    DiscoverRepository:
    """

    def __init__(self, redis_client: Redis) -> None:
        """
        Constructor
        """

        self.redis = redis_client

    async def enter_discover(
        self,
        user_id: str,
        username: str,
        additional_data: Optional[Dict[str, Any]] = None,
        ttl: Optional[int] = 7200,  # two hours
    ) -> bool:
        """
        Marks the user as present in discover with optional additional data and TTL.

        Args:
            user_id: The user's unique identifier
            username: The user's username
            additional_data: Optional additional user data to store
            ttl: Time to live in seconds for the entry

        Returns:
            bool: True if user was added successfully, False otherwise

        """
        user_key = f"discover_user:{user_id}"
        current_timestamp = datetime.datetime.now(datetime.timezone.utc).timestamp()

        user_data = {
            "user_id": user_id,
            "username": username,
            "joined_at": str(current_timestamp),
        }

        if additional_data:
            user_data.update(additional_data)

        try:
            async with self.redis.pipeline() as pipe:
                await pipe.hset(user_key, mapping=user_data)  # type: ignore

                if ttl:
                    await pipe.expire(user_key, ttl)

                results = await pipe.execute()

            insert_count = results[0]
            return insert_count > 0

        except Exception as exc:
            logger.error("Error adding user %s to discover: %s", user_id, str(exc))
            return False

    async def is_in_discover(self, user_id: str) -> bool:
        """
        Checks if user is currently in discover.

        Args:
            user_id: The user's unique identifier

        Returns:
            bool: True if user is in discover, False otherwise
        """
        user_key = f"discover_user:{user_id}"

        try:
            exists = await self.redis.exists(user_key)

            return bool(exists)

        except Exception as exc:
            logger.error("Error checking existence for user %s: %s", user_id, str(exc))
            return False

    async def get_active_users(self, previous_cursor: int = 0, limit: int = 20):
        """
        Returns a tuple containing the next cursor and a list of
        active discover users (paged).
        """
        try:
            active_users = []

            scan_result = await self.redis.scan(
                cursor=previous_cursor,
                count=limit,
                match="discover_user:*",
            )

            # Unpack the results:
            next_cursor: int = scan_result[0]
            user_keys: List[bytes] = scan_result[1]

            if not user_keys:
                return 0, []

            pipeline = self.redis.pipeline()

            for key in user_keys:
                pipeline.hgetall(key.decode())

            user_data_results: List[Dict[bytes, bytes]] = await pipeline.execute()

            for user_data_byte in user_data_results:
                if user_data_byte:
                    user_data = {
                        key.decode("utf-8"): value.decode("utf-8")
                        for key, value in user_data_byte.items()
                    }

                    active_users.append(user_data)

            return next_cursor, active_users

        except Exception as exc:
            logger.error(
                "Error checking fetching active users in discover: %s", str(exc)
            )
            return 0, []

    async def leave_discover(self, user_id: str) -> bool:
        """
        Removes a user from the discover active list..

        Args:
            user_id: The user's unique identifier (str).

        Returns:
            bool: True if the key was deleted (user was active), False otherwise.
        """
        user_key = f"discover_user:{user_id}"

        try:
            deleted_count = await self.redis.delete(user_key)

            return deleted_count == 1

        except Exception as exc:
            logger.error("Error removing user %s from discover: %s", user_id, str(exc))
            return False
