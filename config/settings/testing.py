from .base import *

# Celery
CELERY_TASK_ALWAYS_EAGER = True
CELERY_TASK_EAGER_PROPAGATES = True

# Database
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': ':memory:',
    }
}

# Skip some middlewares if they cause issues in tests
# MIDDLEWARE = [m for m in MIDDLEWARE if 'Whitenoise' not in m]

# Ensure we use the console email backend for tests
EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend'

# Use a local in-memory channel layer for tests
CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels.layers.InMemoryChannelLayer",
    },
}

# Disabled Redis for EventStream in tests
EVENTSTREAM_REDIS = {}
