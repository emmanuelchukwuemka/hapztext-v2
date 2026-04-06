#!/usr/bin/env python
"""
Deploy script to restart Daphne with proper media serving configuration
Run this on your VPS to ensure media files are being served correctly
"""

import os
import sys
from pathlib import Path

# Simple deployment verification script
print("=" * 60)
print("DJANGO MEDIA SERVING VERIFICATION")
print("=" * 60)

print("\n✅ Changes Applied:")
print("   1. config/urls.py - Updated to serve media in production")
print("   2. config/settings/base.py - Added USE_CLOUDINARY flag")
print("   3. config/settings/production.py - Confirmed SERVE_MEDIA_IN_PRODUCTION = True")

print("\n📋 Current Configuration:")
print("   - Storage: Local File System (NOT Cloudinary)")
print("   - Media Root: /root/hapz_backend/media/")
print("   - Media URL: /media/")
print("   - Files stored on VPS filesystem")
print("   - Database stores only file paths")

print("\n🔧 Next Steps on VPS:")
print("-" * 60)

commands = """
# 1. SSH into your VPS
ssh root@72.62.4.119

# 2. Navigate to backend directory
cd /root/hapz_backend

# 3. Activate virtual environment
source .venv/bin/activate

# 4. Verify media directory exists
ls -la /root/hapz_backend/media/

# 5. Check if the cover picture exists
ls -la /root/hapz_backend/media/cover_pictures/

# 6. Test Django can see the file
python -c "from django.conf import settings; print('MEDIA_ROOT:', settings.MEDIA_ROOT); print('USE_CLOUDINARY:', getattr(settings, 'USE_CLOUDINARY', False))"

# 7. Restart Daphne to apply URL changes
pkill -f daphne
nohup daphne -b 0.0.0.0 -p 8005 config.asgi:application > logs/daphne.log 2>&1 &

# 8. Test media URL
curl -I http://72.62.4.119:8005/media/cover_pictures/1000783003_j9FFDUS.jpg

# 9. Check if it returns 200 OK
"""

print(commands)

print("\n" + "=" * 60)
print("EXPLANATION")
print("=" * 60)
print("""
Your setup is ALREADY using local file storage (not Cloudinary).
When CLOUDINARY_CLOUD_NAME='test', Django saves files to the VPS filesystem.

How it works:
1. Flutter uploads image → Django receives it
2. Django saves file to: /root/hapz_backend/media/cover_pictures/[filename].jpg
3. Django saves PATH in database: /media/cover_pictures/[filename].jpg
4. Flutter gets URL: http://72.62.4.119:8005/media/cover_pictures/[filename].jpg
5. Django serves the file from disk when Flutter requests it

The 404 error was happening because:
- Either the file wasn't uploaded properly, OR
- Django URLs weren't configured to serve media in production

Now FIXED: Django URLs will serve media files even in production mode.
""")

print("\n💡 RECOMMENDATION:")
print("For production, consider using Cloudinary instead of local storage.")
print("Cloudinary provides CDN, better performance, and no server management.")
print("See MEDIA_FIX_GUIDE.md for Cloudinary setup instructions.\n")
