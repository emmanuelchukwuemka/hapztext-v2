#!/bin/bash

if [ "$DJANGO_ENVIRONMENT" = "development" ]; then
    echo "Development environment detected, installing dev dependencies..."
    uv sync --extra dev
else
    echo "Production environment, using base dependencies only"
    uv sync
fi

uv run manage.py collectstatic --noinput
uv run manage.py migrate
uv run daphne config.asgi:application -b 0.0.0.0 -p 8000