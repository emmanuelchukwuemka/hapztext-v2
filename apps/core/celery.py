import os

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")

from celery import Celery, shared_task
from loguru import logger


app = Celery("hapztext")
app.config_from_object("django.conf:settings", namespace="CELERY")
app.autodiscover_tasks()


@shared_task(bind=True, max_retries=3)
def publish_scheduled_posts_task(self, post_id: str):
    from apps.infrastructure.posts.models import Post
    from apps.infrastructure.posts.repositories import to_domain_post_data
    from apps.presentation.factory import (
        get_notify_followers_of_post_rule,
        get_notify_post_creator_of_reply_rule,
    )

    try:
        post = Post.objects.get(id=post_id)
        if post.is_reply and post.previous_post_id:
            original_post = to_domain_post_data(
                Post.objects.get(id=post.previous_post_id)
            )

            notify_reply_rule = get_notify_post_creator_of_reply_rule()
            notify_reply_rule(
                post_creator_id=original_post.sender_id,
                replier_id=post.sender_id,
                original_post_id=post.previous_post_id,
                reply_id=post.id,
            )
        else:
            notify_followers_rule = get_notify_followers_of_post_rule()
            notify_followers_rule(
                post_creator_id=post.sender_id,
                post_id=post.id,
                post_content=post.text_content or "New media post",
            )
    except Exception as e:
        logger.error(f"Failed to send post notifications: {e}")

        try:
            raise self.retry(exc=e)
        except self.MaxRetriesExceededError:
            logger.error(
                "Max retries exceeded for publish_scheduled_posts_task, giving up"
            )
