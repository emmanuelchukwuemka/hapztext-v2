#!/bin/bash

# Vercel build script for Django application
# This script runs during the Vercel build process

set -e  # Exit on any error

echo "=========================================="
echo "Django Vercel Deployment Build"
echo "=========================================="

# Verify Python is available
if ! command -v python &> /dev/null; then
    echo "ERROR: Python is not available"
    exit 1
fi

echo "Python version: $(python --version)"

# Install production dependencies
echo ""
echo "Step 1: Installing Python dependencies..."
if [ -f "requirements-prod.txt" ]; then
    pip install --upgrade pip setuptools wheel
    pip install -r requirements-prod.txt
else
    pip install --upgrade pip setuptools wheel
    pip install -r requirements.txt gunicorn uvicorn
fi

# Set Django settings module for production
export DJANGO_SETTINGS_MODULE=config.settings.production

# Run Django checks
echo ""
echo "Step 2: Running Django system checks..."
python manage.py check --deploy

# Run database migrations
echo ""
echo "Step 3: Running database migrations..."
python manage.py migrate --noinput

# Collect static files
echo ""
echo "Step 4: Collecting static files..."
python manage.py collectstatic --noinput --clear

# Additional checks
echo ""
echo "Step 5: Verifying installation..."
python -c "import django; print(f'Django version: {django.get_version()}')"
python -c "import channels; print(f'Channels version: {channels.__version__}')"

echo ""
echo "=========================================="
echo "✅ Build completed successfully!"
echo "=========================================="
