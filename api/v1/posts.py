from django.urls import path

from apps.posts.presentation.views import create_post, fetch_posts_list

urlpatterns = [
    path("", create_post, name="create-post"),
    path("list/<int:page>/<int:page_size>/", fetch_posts_list, name="fetch-posts-list"),
] 