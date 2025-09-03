from django.urls import path

from apps.presentation.views.posts import (
    create_post,
    fetch_posts_list,
    fetch_user_posts,
    react_to_post,
    remove_post_reaction,
    share_post,
)

urlpatterns = [
    path("", create_post, name="create-post"),
    path("list/<int:page>/<int:page_size>/", fetch_posts_list, name="fetch-posts-list"),
    path(
        "user/<str:user_id>/<int:page>/<int:page_size>/",
        fetch_user_posts,
        name="fetch-user-posts",
    ),
    path(
        "<str:post_id>/react/",
        react_to_post,
        name="react-to-post",
    ),
    path(
        "<str:post_id>/react/delete/",
        remove_post_reaction,
        name="remove-post-reaction",
    ),
    path(
        "<str:post_id>/share/",
        share_post,
        name="share-post",
    ),
]
