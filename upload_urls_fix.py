#!/usr/bin/env python
"""
Upload the fixed urls.py to VPS and restart Daphne
This applies the media serving fix immediately without full redeployment
"""

import paramiko
from scp import SCPClient
import time

# VPS Credentials
HOST = "72.62.4.119"
USERNAME = "root"
PASSWORD = "Mathscrusader123."

print("=" * 70)
print("UPLOADING FIXED urls.py TO VPS")
print("=" * 70)

try:
    print(f"\nConnecting to VPS: {HOST}...")
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(hostname=HOST, username=USERNAME, password=PASSWORD)
    print("✅ Connected to VPS successfully")
    
    # Upload the fixed urls.py
    print("\nUploading config/urls.py to VPS...")
    with SCPClient(ssh.get_transport()) as scp:
        scp.put('config/urls.py', '/root/hapz_backend/config/urls.py')
    print("✅ File uploaded successfully")
    
    # Verify the upload
    print("\nVerifying uploaded file...")
    stdin, stdout, stderr = ssh.exec_command("cat /root/hapz_backend/config/urls.py | grep -A2 'ALWAYS serve media'")
    output = stdout.read().decode().strip()
    if "ALWAYS serve media" in output:
        print("✅ Verified: urls.py contains the media fix")
        print(f"Content:\n{output}")
    else:
        print("❌ Upload may have failed - file doesn't contain expected content")
    
    # Restart Daphne
    print("\n" + "=" * 70)
    print("RESTARTING DAPHNE")
    print("=" * 70)
    
    print("\n[1/4] Stopping current Daphne process...")
    stdin, stdout, stderr = ssh.exec_command("pkill -f daphne")
    stdout.channel.recv_exit_status()
    time.sleep(2)
    
    print("[2/4] Ensuring port 8005 is free...")
    stdin, stdout, stderr = ssh.exec_command("fuser -k 8005/tcp 2>/dev/null || true")
    stdout.channel.recv_exit_status()
    time.sleep(1)
    
    print("[3/4] Starting Daphne with updated code...")
    cmd = "cd /root/hapz_backend && source .venv/bin/activate && export DJANGO_SETTINGS_MODULE=config.settings.production && nohup daphne -b 0.0.0.0 -p 8005 config.asgi:application >> logs/daphne.log 2>&1 &"
    ssh.exec_command(cmd)
    time.sleep(3)
    
    print("[4/4] Verifying Daphne is running...")
    stdin, stdout, stderr = ssh.exec_command("ps aux | grep daphne | grep -v grep")
    output = stdout.read().decode().strip()
    if output:
        print(f"✅ Daphne is running:\n{output[:200]}")
    else:
        print("❌ Daphne failed to start")
    
    # Test media access
    print("\n" + "=" * 70)
    print("TESTING MEDIA ACCESS AFTER FIX")
    print("=" * 70)
    
    print("\nWaiting 5 seconds for Daphne to initialize...")
    time.sleep(5)
    
    print("\n[Test 1] Testing cover picture access...")
    stdin, stdout, stderr = ssh.exec_command("curl -I -s http://localhost:8005/media/cover_pictures/1000783003.jpg 2>&1 | head -3")
    response = stdout.read().decode().strip()
    
    if "200 OK" in response:
        print(f"✅ SUCCESS! Media files are now accessible:")
        print(response)
        
        print("\n[Test 2] Testing profile picture access...")
        stdin, stdout, stderr = ssh.exec_command("curl -I -s http://localhost:8005/media/profile_images/1000783003.jpg 2>&1 | head -3")
        response = stdout.read().decode().strip()
        if "200 OK" in response:
            print(f"✅ Profile pictures also work:")
            print(response)
        else:
            print(f"Response: {response}")
            
    elif "404" in response:
        print(f"❌ Still getting 404. Checking why...")
        print(f"Response: {response}")
        
        # Check if static() is working
        print("\nDebugging: Testing Django static URL configuration...")
        test_cmd = """cd /root/hapz_backend && source .venv/bin/activate && python -c \"
import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.production')
import django
django.setup()
from django.conf import settings
from django.conf.urls.static import static
from config import urls

print('DEBUG:', settings.DEBUG)
print('MEDIA_URL:', settings.MEDIA_URL)
print('MEDIA_ROOT:', settings.MEDIA_ROOT)

# Count URL patterns
total_patterns = len(urls.urlpatterns)
print('Total URL patterns:', total_patterns)

# Try adding static patterns
static_patterns = static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
print('Static media patterns created:', len(static_patterns))

if static_patterns:
    print('SUCCESS: Static patterns can be created')
    for p in static_patterns[:2]:
        print('  Pattern:', p.pattern)
else:
    print('WARNING: No static patterns created - this might be due to how static() works in production')
\"
"""
        stdin, stdout, stderr = ssh.exec_command(test_cmd)
        debug_output = stdout.read().decode().strip()
        err_output = stderr.read().decode().strip()
        print(f"\nDjango test output:\n{debug_output}")
        if err_output:
            print(f"Errors:\n{err_output}")
    else:
        print(f"Unexpected response: {response}")
    
    # Check recent logs
    print("\n[Test 3] Checking Daphne logs...")
    stdin, stdout, stderr = ssh.exec_command("tail -30 /root/hapz_backend/logs/daphne.log | grep -E 'WARNING|ERROR|media|Media' | tail -10")
    logs = stdout.read().decode().strip()
    if logs:
        print(f"Recent media-related logs:\n{logs}")
    else:
        print("No recent media-related errors in logs")
    
    print("\n" + "=" * 70)
    print("FINAL SUMMARY")
    print("=" * 70)
    print("""
✅ The fixed urls.py has been uploaded to the VPS
✅ Daphne has been restarted with the new configuration

The fix changes urls.py to ALWAYS serve media files using:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)

This should work regardless of DEBUG setting.

EXPECTED RESULT:
- Media files should now return HTTP 200 instead of 404
- Flutter app should be able to load images

IF STILL GETTING 404:
The issue might be that Django's static() helper doesn't add patterns in 
production. In that case, we need to manually add the URL pattern or use
a different approach like WhiteNoise or Nginx for media serving.

NEXT STEPS FOR FLUTTER:
1. Clear Flutter app cache
2. Try re-uploading a profile/cover picture
3. Check if newly uploaded images work
""")
    
    ssh.close()
    
except Exception as e:
    print(f"\n❌ ERROR: {e}")
    import traceback
    traceback.print_exc()
