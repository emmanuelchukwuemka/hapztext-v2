from django.urls import include, path

urlpatterns = [
    path("users/", include("api.v1.users")),
    path("authentication/", include("api.v1.authentication")),
    path("posts/", include("api.v1.posts")),
    path("notifications/", include("api.v1.notifications")),
]
