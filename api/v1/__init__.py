from django.urls import include, path

urlpatterns = [
    path("authentication/", include("api.v1.authentication")),
    path("users/", include("api.v1.users")),
    path("posts/", include("api.v1.posts")),
]
