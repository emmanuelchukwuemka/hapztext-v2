"""
Alternative ASGI handler for Vercel (WebSocket/Channels support).
Use this if you need WebSocket support with Channels.

Note: WebSockets on Vercel have limitations due to function timeout constraints.
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

# Import the ASGI application with Channels support
from config.asgi import application

# Export for Vercel
__all__ = ["application"]
