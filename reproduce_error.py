import os
import sys
import django

# Add the project root to sys.path
sys.path.append(os.getcwd())

from django.conf import settings
from rest_framework.test import APIRequestFactory

# Setup Django
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")
django.setup()

from apps.presentation.views.authentication import register_user

factory = APIRequestFactory()

def test_register():
    print("Testing Registration...")
    url = "/api/v1/authentication/register/"
    data = {
        "email": "test_reproduce@example.com",
        "username": "test_reproduce",
        "password": "Password123!",
        "password_confirm": "Password123!"
    }
    request = factory.post(url, data, format="json")
    
    try:
        response = register_user(request)
        print(f"Status: {response.status_code}")
        print(f"Data: {response.data}")
    except Exception as e:
        print(f"Caught exception: {type(e).__name__}: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_register()
