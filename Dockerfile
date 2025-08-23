FROM python:3.12-slim-bookworm

RUN apt update && apt install -y \
    --no-install-recommends \
    curl \
    && apt upgrade -y \
    && rm -rf /var/lib/apt/lists/* \
    && apt clean

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

RUN groupadd -r appuser && useradd -r -g appuser -u 1001 appuser

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app \
    UV_CACHE_DIR=/tmp/.uv-cache

USER appuser

WORKDIR /app

RUN mkdir -p /app/logs /app/staticfiles /app/media \
    && chown -R appuser:appuser /app \
    && chmod 755 /app/logs /app/staticfiles /app/media

COPY --chown=appuser:appuser . .

RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync

RUN chmod +x /app/startup.sh || true

RUN rm -rf /tmp/* /var/tmp/* \
    && find /app -name "*.pyc" -delete \
    && find /app -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true 