from pathlib import Path

import environ

BASE_DIR = Path(__file__).resolve().parent.parent.parent

env = environ.Env()
environ.Env.read_env(BASE_DIR / ".env")

ENVIRONMENT = env.str("DJANGO_ENVIRONMENT", "development")

if ENVIRONMENT == "production":
    from .production import *
else:
    from .development import *
