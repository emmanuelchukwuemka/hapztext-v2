import os
import sys
import django

# Add the project root to sys.path
sys.path.append(os.getcwd())

# Setup Django
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")
django.setup()

from apps.presentation.rule_registry import get_user_repository

def verify_search():
    user_repo = get_user_repository()
    query = "test"
    page = 1
    page_size = 10
    
    print(f"Searching for users with query: '{query}'")
    users, prev, next_link = user_repo.search(query, page, page_size)
    
    print(f"Found {len(users)} users.")
    for user in users:
        print(f"- ID: {user.id}, Username: {user.username}, Email: {user.email}")

if __name__ == "__main__":
    verify_search()
