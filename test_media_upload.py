#!/usr/bin/env python3
"""
Test script to verify media uploads are working on the server
"""

import paramiko
import time

HOST = "72.62.4.119"
USERNAME = "root"
PASSWORD = "Mathscrusader123."

def run_command(ssh, command):
    """Run command and return output"""
    stdin, stdout, stderr = ssh.exec_command(command)
    exit_status = stdout.channel.recv_exit_status()
    out = stdout.read().decode().strip()
    err = stderr.read().decode().strip()
    return exit_status, out, err

print("==========================================")
print("  Testing Media Upload Configuration     ")
print("==========================================")

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(hostname=HOST, username=USERNAME, password=PASSWORD)

try:
    # Check if server is running
    print("\n[1] Checking if Daphne server is running...")
    exit_status, out, err = run_command(ssh, "netstat -tlnp | grep :8005")
    if exit_status == 0:
        print(f"✅ Server is running: {out}")
    else:
        print("❌ Server is NOT running!")
        print("Starting server...")
        run_command(ssh, "cd /root/hapz_backend && source .venv/bin/activate && export DJANGO_SETTINGS_MODULE=config.settings.production && nohup daphne -b 0.0.0.0 -p 8005 config.asgi:application > logs/daphne.log 2>&1 &")
        time.sleep(3)
    
    # Check media directory
    print("\n[2] Checking media directory...")
    exit_status, out, err = run_command(ssh, "ls -la /root/hapz_backend/media/")
    if exit_status == 0:
        print(f"Media directory contents:\n{out}")
    else:
        print(f"❌ Error: {err}")
    
    # Check profile images
    print("\n[3] Checking profile_images directory...")
    exit_status, out, err = run_command(ssh, "ls -la /root/hapz_backend/media/profile_images/ 2>/dev/null || echo 'Directory does not exist or is empty'")
    print(out)
    
    # Check cover pictures
    print("\n[4] Checking cover_pictures directory...")
    exit_status, out, err = run_command(ssh, "ls -la /root/hapz_backend/media/cover_pictures/ 2>/dev/null || echo 'Directory does not exist or is empty'")
    print(out)
    
    # Check post media
    print("\n[5] Checking post media directories...")
    exit_status, out, err = run_command(ssh, "find /root/hapz_backend/media -type f -name '*.jpg' -o -name '*.png' -o -name '*.mp4' | head -20")
    if out:
        print(f"Found media files:\n{out}")
    else:
        print("No media files found yet")
    
    # Test Django can serve media
    print("\n[6] Testing Django media URL configuration...")
    exit_status, out, err = run_command(ssh, "cd /root/hapz_backend && source .venv/bin/activate && python -c \"from django.conf import settings; print('MEDIA_URL:', settings.MEDIA_URL); print('MEDIA_ROOT:', settings.MEDIA_ROOT); print('BACKEND_DOMAIN:', settings.BACKEND_DOMAIN)\"")
    if exit_status == 0:
        print(out)
    else:
        print(f"❌ Error: {err}")
    
    # Test curl media endpoint
    print("\n[7] Testing media endpoint...")
    exit_status, out, err = run_command(ssh, "curl -s -o /dev/null -w '%{http_code}' http://localhost:8005/media/")
    if exit_status == 0:
        print(f"Media endpoint response code: {out}")
    else:
        print(f"❌ Error accessing media endpoint: {err}")
    
    print("\n==========================================")
    print("✅ Test complete!")
    print("==========================================")
    
finally:
    ssh.close()
