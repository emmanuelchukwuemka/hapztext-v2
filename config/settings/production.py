from .base import *

import os

# Production settings for Vercel deployment
# These settings optimize the application for Vercel serverless functions

# Disable debug mode in production
DEBUG = False

# Add Vercel domains to allowed hosts
ALLOWED_HOSTS = [
    ".vercel.app",
    "*.vercel.app",
] + ALLOWED_HOSTS

# CSRF trusted origins for Vercel deployment
CSRF_TRUSTED_ORIGINS = [
    "https://*.vercel.app",
    "https://*.now.sh",
]

# Security headers for HTTPS
SECURE_SSL_REDIRECT = os.getenv("DJANGO_SECURE_SSL_REDIRECT", "True").lower() == "true"
SECURE_HSTS_SECONDS = 31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_BROWSER_XSS_FILTER = True
SECURE_CONTENT_SECURITY_POLICY = {
    "default-src": ("'self'",),
}
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
X_FRAME_OPTIONS = "DENY"

# Security: Set a higher cookie age for Vercel's function timeout
SESSION_COOKIE_AGE = 86400  # 24 hours

# Static files with WhiteNoise for efficient serving
STATIC_URL = "/static/"
STATICFILES_STORAGE = "whitenoise.storage.CompressedManifestStaticFilesStorage"

# Media files configuration for production
MEDIA_URL = "/media/"
MEDIA_ROOT = "/root/hapz_backend/media"

# CORS settings
CORS_ALLOW_CREDENTIALS = True

# Serve media files in production through Django
# This ensures media files are accessible even when using Cloudinary
SERVE_MEDIA_IN_PRODUCTION = True

# Optimize database connection for Vercel
# Pool connections to reduce overhead
DATABASES = {
    "default": {
        **DATABASES["default"],
        "CONN_MAX_AGE": 60,  # Shorter pool age for serverless
        "ATOMIC_REQUESTS": False,  # Avoid long transactions
    }
}

# Logging for production (output to console for Vercel logs)
LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "verbose": {
            "format": "{levelname} {asctime} {module} {process:d} {thread:d} {message}",
            "style": "{",
        },
        "simple": {
            "format": "{levelname} {message}",
            "style": "{",
        },
    },
    "handlers": {
        "console": {
            "class": "logging.StreamHandler",
            "formatter": "simple",
        },
    },
    "root": {
        "handlers": ["console"],
        "level": "INFO",
    },
    "loggers": {
        "django": {
            "handlers": ["console"],
            "level": "INFO",
            "propagate": False,
        },
    },
}

# Important Vercel Limitations & Notes:
# ====================================
# 1. WEBSOCKETS/CHANNELS: 
#    - Vercel functions have maximum execution time (Pro: 60s, if using Edge: 25s)
#    - WebSockets may not work well due to timeout limitations
#    - Consider using a dedicated WebSocket provider (Socket.io with Pusher, etc.)
#
# 2. LONG-RUNNING TASKS (Celery):
#    - Not suitable for Vercel due to function timeouts
#    - Alternative: Use external task queue (Celery with external broker)
#    - Or: Use Vercel Cron Jobs for scheduled tasks
#
# 3. FILE STORAGE:
#    - Vercel has read-only filesystem except /tmp (cleared after each execution)
#    - Using Cloudinary is the correct approach
#    - Ensure all file uploads go through Cloudinary
#
# 4. ENVIRONMENT VARIABLES:
#    - All sensitive data MUST be set in Vercel project settings
#    - Never commit .env file with real values
#    - Use .env.vercel.example as a template

# Disable Channels for Vercel due to timeout limitations
# If you need real-time features, consider:
# - Pusher/Echo for WebSockets
# - AWS AppSync
# - Firebase Realtime Database
# Uncomment if completely disabling WebSocket support:
# INSTALLED_APPS = [app for app in INSTALLED_APPS if app not in ["daphne", "channels"]]