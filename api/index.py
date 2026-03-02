"""
Vercel serverless function handler for Django application.
This file serves as the entry point for all HTTP requests on Vercel.
"""

import os
import sys
import django
from pathlib import Path

# Add the parent directory to Python path
BASE_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BASE_DIR))

# Configure Django settings
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.production")

# Setup Django
django.setup()

# Import the WSGI application
from config.wsgi import application

# Export for Vercel
__all__ = ["application"]
