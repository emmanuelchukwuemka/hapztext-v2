from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import include, path, re_path
from django.views.static import serve
from drf_spectacular.views import (
    SpectacularAPIView,
    SpectacularRedocView,
    SpectacularSwaggerView,
)

urlpatterns = [
    path("admin/", admin.site.urls),
    path("schema/", SpectacularAPIView.as_view(), name="schema"),
    path(
        "docs/swagger-ui/",
        SpectacularSwaggerView.as_view(url_name="schema"),
        name="swagger-ui",
    ),
    path("docs/redoc/", SpectacularRedocView.as_view(url_name="schema"), name="redoc"),
    path("api/v1/", include("api.v1")),
    
    # Manual media URL pattern for production (works when DEBUG=False)
    # This serves media files directly through Django
    re_path(r'^media/(?P<path>.*)$', serve, {
        'document_root': settings.MEDIA_ROOT,
    }),
]

# Also add using static() for development
urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    
# Always serve static files
urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
