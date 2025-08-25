from django.urls import path

from apps.presentation.views.posts import (
    create_post,
    fetch_posts_list,
    fetch_user_posts,
)

urlpatterns = [
    path("", create_post, name="create-post"),
    path("list/<int:page>/<int:page_size>/", fetch_posts_list, name="fetch-posts-list"),
    path(
        "user/<str:user_id>/<int:page>/<int:page_size>/",
        fetch_user_posts,
        name="fetch-user-posts",
    ),
]
