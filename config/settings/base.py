from pathlib import Path

import dj_database_url
import environ

from apps.core.logging import setup_logging

BASE_DIR = Path(__file__).resolve().parent.parent.parent

env = environ.Env()
environ.Env.read_env(BASE_DIR / ".env")

LOGS_DIR = BASE_DIR / "logs"
LOGS_DIR.mkdir(exist_ok=True)
LOG_FILE = LOGS_DIR / "hapztext.log"
LOG_FILE.touch(exist_ok=True)
LOGGING_LEVEL = env.str("DJANGO_LOGGING_LEVEL", default="INFO")

setup_logging(log_level=LOGGING_LEVEL, log_file=LOG_FILE)

SECRET_KEY = env.str("DJANGO_SECRET_KEY")

DEBUG = env.bool("DJANGO_DEBUG")

ALLOWED_HOSTS = env.str("DJANGO_ALLOWED_HOSTS").split(",")

CORS_ALLOWED_ORIGINS = env.str("CORS_ALLOWED_ORIGINS").split(",")

INSTALLED_APPS = [
    "daphne",
    "channels",
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "corsheaders",
    "whitenoise",
    "rest_framework",
    "knox",
    "drf_spectacular",
    "drf_spectacular_sidecar",
    "django_eventstream",
    "apps.presentation.apps.UsersConfig",
    "apps.presentation.apps.AuthenticationConfig",
    "apps.presentation.apps.PostsConfig",
    "apps.presentation.apps.NotificationsConfig",
    "apps.presentation.apps.ChatConfig",
]

MIDDLEWARE = [
    "corsheaders.middleware.CorsMiddleware",
    "whitenoise.middleware.WhiteNoiseMiddleware",
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "config.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [BASE_DIR / "apps/presentation/templates"],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.debug",
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "config.wsgi.application"
ASGI_APPLICATION = "config.asgi.application"

DATABASES = {
    "default": dj_database_url.config(
        default=env.str("DATABASE_URL"),
        conn_max_age=600,
        conn_health_checks=True,
    )
}

AUTH_PASSWORD_VALIDATORS = [
    {
        "NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.MinimumLengthValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.CommonPasswordValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.NumericPasswordValidator",
    },
]

LANGUAGE_CODE = "en-us"

TIME_ZONE = "UTC"

USE_I18N = True

USE_TZ = True

STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
STATIC_ROOT.mkdir(exist_ok=True)
STATICFILES_STORAGE = "whitenoise.storage.CompressedManifestStaticFilesStorage"

MEDIA_URL = "/media/"
MEDIA_ROOT = BASE_DIR / "media"
MEDIA_ROOT.mkdir(exist_ok=True)

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

AUTH_USER_MODEL = "users.User"

CORS_ALLOW_CREDENTIALS = True

OTP_EXPIRY_MINUTES = env.int("OTP_EXPIRY_MINUTES", default=10)

DEFAULT_FROM_EMAIL = env.str("DEFAULT_FROM_EMAIL", default="noreply@hapztext.com")

REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": [
        "knox.auth.TokenAuthentication",
    ],
    "DEFAULT_THROTTLE_CLASSES": [
        "rest_framework.throttling.AnonRateThrottle",
        "rest_framework.throttling.UserRateThrottle",
    ],
    "DEFAULT_THROTTLE_RATES": {
        "anon": "10/min",
        "user": "20/min",
    },
    "DEFAULT_SCHEMA_CLASS": "drf_spectacular.openapi.AutoSchema",
    "EXCEPTION_HANDLER": "apps.core.exceptions.custom_exception_handler",
}

REST_KNOX = {
    "AUTH_TOKEN_CHARACTER_LENGTH": 64,
    "TOKEN_LIMIT_PER_USER": 3,
    "AUTO_REFRESH": True,
    "MIN_REFRESH_INTERVAL": 60,
    "AUTH_HEADER_PREFIX": "Bearer",
    "EXPIRY_DATETIME_FORMAT": "iso-8601",
}

SPECTACULAR_SETTINGS = {
    "TITLE": "HapzText API",
    "DESCRIPTION": "A modern social media API built with Django REST Framework",
    "VERSION": "1.0.0",
    "SERVE_INCLUDE_SCHEMA": False,
    "SWAGGER_UI_DIST": "SIDECAR",
    "SWAGGER_UI_FAVICON_HREF": "SIDECAR",
    "REDOC_DIST": "SIDECAR",
}

BACKEND_DOMAIN = env.str("BACKEND_DOMAIN")

EMAIL_BACKEND = env.str("EMAIL_BACKEND")
EMAIL_HOST = env.str("EMAIL_HOST")
EMAIL_PORT = env.int("EMAIL_PORT")
EMAIL_USE_TLS = env.bool("EMAIL_USE_TLS")
EMAIL_HOST_USER = env.str("EMAIL_HOST_USER")
EMAIL_HOST_PASSWORD = env.str("EMAIL_HOST_PASSWORD")
DEFAULT_FROM_EMAIL = env.str("DEFAULT_FROM_EMAIL", EMAIL_HOST_USER)

REDIS_URL = env.str("REDIS_URL")


EVENTSTREAM_CHANNELMANAGER_CLASS = (
    "apps.infrastructure.notifications.channels.AuthenticatedChannelManager"
)

EVENTSTREAM_REDIS = {
    "host": env.str("REDIS_HOST"),
    "port": env.int("REDIS_PORT"),
    "db": env.int("REDIS_DB"),
    "password": env.str("REDIS_PASSWORD"),
    "ssl": True,
}

EVENTSTREAM_STORAGE_CLASS = "django_eventstream.storage.DjangoModelStorage"

EVENTSTREAM_ALLOW_ORIGINS = CORS_ALLOWED_ORIGINS
EVENTSTREAM_ALLOW_CREDENTIALS = True
EVENTSTREAM_ALLOW_HEADERS = "Authorization"

CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels_redis.core.RedisChannelLayer",
        "CONFIG": {
            "hosts": [(env.str("REDIS_HOST", "redis"), env.int("REDIS_PORT", 6379))],
            "capacity": 1500,  # Maximum number of messages to store
            "expiry": 10,  # Message expiry time in seconds
        },
    },
}

CELERY_ACCEPT_CONTENT = ["application/json", "application/x-python-serialize"]
CELERY_TASK_SERIALIZER = "pickle"
CELERY_RESULT_SERIALIZER = "pickle"
CELERY_BROKER_URL = env.str("REDIS_URL")
CELERY_RESULT_BACKEND = env.str("REDIS_URL")
