"""
Discover Repository
Handles Redis-based presence tracking for Discover mode
"""

from typing import List
from redis.asyncio import Redis


class DiscoverRepository:
    """
    DiscoverRepository:
    """

    def __init__(self, redis_client: Redis) -> None:
        """
        Constructor
        """

        self.dis_set = "discover:active_users"
        self.redis = redis_client

    async def enter_discover(self, user_id: str) -> None:
        """
        Marks the user as present in discover.
        """
        await self.redis.sadd(self.dis_set, user_id)  # type: ignore

    async def leave_discover(self, user_id: str) -> None:
        """
        Removes user from discover.
        """
        await self.redis.srem(self.dis_set, user_id)  # type: ignore

    async def get_active_users(self) -> List[str]:
        """
        Returns list of all active discover users.
        """
        members = await self.redis.smembers(self.dis_set)  # type: ignore
        active_users = [
            user.decode() if isinstance(user, bytes) else user for user in members
        ]
        return active_users

    async def is_active(self, user_id: str) -> bool:
        """
        Checks if a user is in discover.
        """
        return bool(await self.redis.sismember(self.dis_set, user_id))  # type: ignore
