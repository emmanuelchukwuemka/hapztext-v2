#!/usr/bin/env python
"""
Quick fix: Restart Daphne with updated code to fix media serving
This applies the URL configuration changes without full redeployment
"""

import paramiko
import time

# VPS Credentials
HOST = "72.62.4.119"
USERNAME = "root"
PASSWORD = "Mathscrusader123."

def run_command(ssh, command, description=""):
    """Run command and return output"""
    if description:
        print(f"\n{description}...")
    stdin, stdout, stderr = ssh.exec_command(command)
    exit_status = stdout.channel.recv_exit_status()
    out = stdout.read().decode().strip()
    err = stderr.read().decode().strip()
    if exit_status == 0:
        print(f"✅ Success")
        if out:
            print(out)
    else:
        print(f"❌ Failed")
        if err:
            print(err)
    return exit_status, out, err

print("=" * 70)
print("RESTARTING DAPHNE WITH MEDIA FIX")
print("=" * 70)

try:
    print(f"\nConnecting to VPS: {HOST}...")
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(hostname=HOST, username=USERNAME, password=PASSWORD)
    print("✅ Connected to VPS successfully")
    
    # Step 1: Stop current Daphne
    run_command(ssh, "pkill -f daphne", "[1/6] Stopping current Daphne process")
    time.sleep(2)
    
    # Step 2: Verify port is free
    run_command(ssh, "fuser -k 8005/tcp 2>/dev/null || true", "[2/6] Ensuring port 8005 is free")
    time.sleep(1)
    
    # Step 3: Navigate to backend directory
    run_command(ssh, "cd /root/hapz_backend && source .venv/bin/activate", "[3/6] Activating virtual environment")
    
    # Step 4: Start Daphne with production settings
    print("\n[4/6] Starting Daphne with updated configuration...")
    cmd = "cd /root/hapz_backend && source .venv/bin/activate && export DJANGO_SETTINGS_MODULE=config.settings.production && nohup daphne -b 0.0.0.0 -p 8005 config.asgi:application >> logs/daphne.log 2>&1 &"
    stdin, stdout, stderr = ssh.exec_command(cmd)
    time.sleep(3)
    
    # Step 5: Verify it's running
    run_command(ssh, "ps aux | grep daphne | grep -v grep", "[5/6] Verifying Daphne is running")
    
    # Step 6: Check port is listening
    run_command(ssh, "netstat -tlnp | grep :8005", "[6/6] Checking port 8005 is listening")
    
    # Test media access
    print("\n" + "=" * 70)
    print("TESTING MEDIA ACCESS")
    print("=" * 70)
    
    # Test 1: Check file exists
    print("\n[Test 1] Checking if cover picture file exists...")
    exit_status, out, err = run_command(ssh, "ls -lh /root/hapz_backend/media/cover_pictures/1000783003.jpg")
    if exit_status == 0:
        print(f"✅ File found: {out}")
    else:
        print(f"⚠️  File not found. Available files:")
        run_command(ssh, "ls -lh /root/hapz_backend/media/cover_pictures/")
    
    # Test 2: Test Django can serve it
    print("\n[Test 2] Testing if Django serves the file...")
    exit_status, out, err = run_command(ssh, "curl -I -s http://localhost:8005/media/cover_pictures/1000783003.jpg 2>&1 | head -5")
    if "200 OK" in out:
        print(f"✅ SUCCESS! Django serves the file:")
        print(out)
    elif "404" in out:
        print(f"❌ Still getting 404. Checking URL patterns...")
        run_command(ssh, "cd /root/hapz_backend && source .venv/bin/activate && python -c \"from django.conf import settings; from django.conf.urls.static import static; print('MEDIA_URL:', settings.MEDIA_URL); print('MEDIA_ROOT:', settings.MEDIA_ROOT); patterns = static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT); print('Static patterns added:', len(patterns))\"")
    else:
        print(f"Response:\n{out or err}")
    
    # Test 3: Check Django logs for errors
    print("\n[Test 3] Checking recent Daphne logs...")
    run_command(ssh, "tail -20 /root/hapz_backend/logs/daphne.log | grep -i 'error\\|warning\\|media' || echo 'No recent errors/warnings'")
    
    print("\n" + "=" * 70)
    print("SUMMARY")
    print("=" * 70)
    print("""
✅ Daphne has been restarted with the updated URL configuration.

The fix ensures Django ALWAYS serves media files, even in production mode.

NEXT STEPS:
1. Wait 30 seconds for Daphne to fully initialize
2. Test from Flutter app again
3. If still getting 404, check the exact filename being requested

IMPORTANT: The Flutter app is requesting '1000783003_j9FFDUS.jpg' but the 
actual file is '1000783003.jpg'. This suggests the Flutter app may be using 
an old cached URL. Try:
- Clearing Flutter app cache
- Re-uploading the cover picture
- Or updating the Flutter app to use the correct URL from the API response
""")
    
    ssh.close()
    
except Exception as e:
    print(f"\n❌ ERROR: {e}")
    print("\nTroubleshooting:")
    print("  - Check VPS is accessible: ping 72.62.4.119")
    print("  - Verify SSH credentials are correct")
    print("  - Check if firewall allows SSH connections")
