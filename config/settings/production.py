import dj_database_url

from .base import *  # noqa

SECRET_KEY = env.str("DJANGO_SECRET_KEY")  # noqa

DEBUG = env.str("DJANGO_DEBUG")  # noqa

ALLOWED_HOSTS = env.str("DJANGO_ALLOWED_HOSTS").split(",")  # noqa

DATABASES = {
    "default": dj_database_url.config(
        default=env.str("DATABASE_URL"),  # noqa
        conn_max_age=600,
        conn_health_checks=True,
    )
}

CORS_ALLOWED_ORIGINS = env.str("CORS_ALLOWED_ORIGINS").split(",")  # noqa

EMAIL_BACKEND = env.str("EMAIL_BACKEND")  # noqa
EMAIL_HOST = env.str("EMAIL_HOST")  # noqa
EMAIL_PORT = env.int("EMAIL_PORT")  # noqa
EMAIL_USE_TLS = env.bool("EMAIL_USE_TLS")  # noqa
EMAIL_HOST_USER = env.str("EMAIL_HOST_USER")  # noqa
EMAIL_HOST_PASSWORD = env.str("EMAIL_HOST_PASSWORD")  # noqa
DEFAULT_FROM_EMAIL = env.str("DEFAULT_FROM_EMAIL", EMAIL_HOST_USER)  # noqa
