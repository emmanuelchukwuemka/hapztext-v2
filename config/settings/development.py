from .base import *  # noqa

SECRET_KEY = "django-insecure-n4v6dk$(4n5)ey2(9$m#*job_wrl4742+%qbk#f@hoy22dvf09"

DEBUG = True

ALLOWED_HOSTS = ["*"]

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.sqlite3",
        "NAME": BASE_DIR / "db.sqlite3",  # noqa
    }
}

CORS_ALLOW_ALL_ORIGINS = True

EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"
