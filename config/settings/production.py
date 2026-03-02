from .base import *import os

# Production settings for Vercel deployment

# Security settings for production
DEBUG = False
ALLOWED_HOSTS = [
    ".vercel.app",
    "*.vercel.app",
] + ALLOWED_HOSTS

# HTTPS and security headers
SECURE_SSL_REDIRECT = True
SECURE_HSTS_SECONDS = 31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")

# Static files with WhiteNoise for efficient serving
STATIC_URL = "/static/"
STATICFILES_STORAGE = "whitenoise.storage.CompressedManifestStaticFilesStorage"

# CORS settings
CORS_ALLOW_CREDENTIALS = True

# Logging for production
LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "handlers": {
        "console": {
            "class": "logging.StreamHandler",
        },
    },
    "root": {
        "handlers": ["console"],
        "level": "INFO",
    },
}

# Note: Vercel has limitations with long-running processes and persistent storage
# Consider these limitations when using:
# - Channels/WebSockets (function timeout: 60-900 seconds depending on plan)
# - Celery tasks (recommend using external task queue or cron jobs)
# - Persistent file storage (use Cloudinary, S3, or similar cloud storage)