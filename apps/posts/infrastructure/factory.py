from ..application.rules import CreatePostRule, PostListRule, UserPostsRule
from ..infrastructure.repositories import DjangoPostRepository


def get_post_repository() -> DjangoPostRepository:
    return DjangoPostRepository()


def create_post_rule() -> CreatePostRule:
    return CreatePostRule(post_repository=get_post_repository())


def posts_list_rule() -> PostListRule:
    return PostListRule(post_repository=get_post_repository())


def user_posts_rule() -> UserPostsRule:
    return UserPostsRule(post_repository=get_post_repository())
