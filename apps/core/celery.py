import os

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")

from celery import Celery, shared_task
from loguru import logger


app = Celery("hapztext")
app.config_from_object("django.conf:settings", namespace="CELERY")
app.autodiscover_tasks()


@shared_task(bind=True, max_retries=3)
def publish_scheduled_posts_task(self):
    """Publish posts that are scheduled to go live"""
    from apps.infrastructure.posts.repositories import DjangoPostRepository

    post_repository = DjangoPostRepository()
    posts = post_repository.get_scheduled_posts()

    for post in posts:
        try:
            post_repository.publish_post(post.id)
            logger.info(f"Successfully published scheduled post {post.id}")
        except Exception as e:
            logger.error(f"Failed to publish scheduled post {post.id}: {e}")
            raise self.retry(exc=e, countdown=60)


@shared_task(bind=True, max_retries=3)
def send_post_notifications_task(self, post_data: dict):
    """Send notifications for new post asynchronously"""
    try:
        from apps.infrastructure.posts.models import Post
        from apps.infrastructure.posts.repositories import to_domain_post_data
        from apps.presentation.rule_registry import (
            get_notify_followers_of_post_rule,
            get_notify_post_creator_of_reply_rule,
        )

        if post_data.get("is_reply") and post_data.get("previous_post_id"):
            # Notify original post creator about reply
            original_post = to_domain_post_data(
                Post.objects.get(id=post_data["previous_post_id"])
            )

            notify_reply_rule = get_notify_post_creator_of_reply_rule()
            notify_reply_rule(
                post_creator_id=original_post.sender_id,
                replier_id=post_data["sender_id"],
                original_post_id=post_data["previous_post_id"],
                reply_id=post_data["id"],
            )
            logger.info(f"Sent reply notification for post {post_data['id']}")
        else:
            # Notify followers about new post
            notify_followers_rule = get_notify_followers_of_post_rule()
            notify_followers_rule(
                post_creator_id=post_data["sender_id"],
                post_id=post_data["id"],
                post_content=post_data.get("text_content") or "New media post",
            )
            logger.info(f"Sent follower notifications for post {post_data['id']}")

    except Exception as e:
        logger.error(
            f"Failed to send post notifications for {post_data.get('id')}: {e}"
        )
        raise self.retry(exc=e, countdown=30)


@shared_task(bind=True, max_retries=3)
def send_follow_notification_task(
    self, target_user_id: str, follower_id: str, follow_request_id: str = None
):
    """Send notification for new follower asynchronously"""
    try:
        from apps.presentation.rule_registry import get_notify_user_of_follow_rule

        notify_follow_rule = get_notify_user_of_follow_rule()
        notify_follow_rule(
            target_user_id=target_user_id,
            follower_id=follower_id,
            follow_request_id=follow_request_id,
        )
        logger.info(f"Sent follow notification to user {target_user_id}")

    except Exception as e:
        logger.error(f"Failed to send follow notification to {target_user_id}: {e}")
        raise self.retry(exc=e, countdown=30)
