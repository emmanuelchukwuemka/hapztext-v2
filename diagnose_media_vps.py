#!/usr/bin/env python
"""
Diagnostic script to test media serving on VPS
This will help identify exactly what's not working
"""

import paramiko
import sys

# VPS Credentials
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

print("=" * 70)
print("MEDIA SERVING DIAGNOSTIC TEST")
print("=" * 70)

try:
    print(f"\nConnecting to VPS: {HOST}...")
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(hostname=HOST, username=USERNAME, password=PASSWORD)
    print("✅ Connected to VPS successfully")
    
    # Test 1: Check if Daphne is running
    print("\n" + "=" * 70)
    print("[TEST 1] Checking Daphne Server Status")
    print("=" * 70)
    exit_status, out, err = run_command(ssh, "ps aux | grep daphne | grep -v grep")
    if out:
        print(f"✅ Daphne is running:")
        print(out)
    else:
        print("❌ Daphne is NOT running!")
        print("   Need to start it with: cd /root/hapz_backend && source .venv/bin/activate && nohup daphne -b 0.0.0.0 -p 8005 config.asgi:application > logs/daphne.log 2>&1 &")
    
    # Test 2: Check if port 8005 is listening
    print("\n" + "=" * 70)
    print("[TEST 2] Checking Port 8005")
    print("=" * 70)
    exit_status, out, err = run_command(ssh, "netstat -tlnp | grep :8005")
    if out:
        print(f"✅ Port 8005 is listening:")
        print(out)
    else:
        print("❌ Port 8005 is NOT listening - Daphne may not be running")
    
    # Test 3: Check media directory
    print("\n" + "=" * 70)
    print("[TEST 3] Checking Media Directory")
    print("=" * 70)
    exit_status, out, err = run_command(ssh, "ls -la /root/hapz_backend/media/")
    if exit_status == 0:
        print(f"✅ Media directory exists:")
        print(out)
        
        # List subdirectories
        exit_status, out, err = run_command(ssh, "ls -lh /root/hapz_backend/media/cover_pictures/ 2>/dev/null | head -20")
        if out:
            print(f"\n📁 Cover pictures directory:")
            print(out)
        else:
            print("⚠️  cover_pictures directory doesn't exist or is empty")
    else:
        print(f"❌ Media directory doesn't exist: {err}")
    
    # Test 4: Check for the specific file
    print("\n" + "=" * 70)
    print("[TEST 4] Checking Specific File (1000783003_j9FFDUS.jpg)")
    print("=" * 70)
    exit_status, out, err = run_command(ssh, "ls -lh /root/hapz_backend/media/cover_pictures/1000783003_j9FFDUS.jpg 2>&1")
    if exit_status == 0:
        print(f"✅ File exists:")
        print(out)
    else:
        print(f"❌ File NOT found:")
        print(err)
        print("\n🔍 Searching for similar files...")
        exit_status, out, err = run_command(ssh, "find /root/hapz_backend/media -name '*1000783003*' 2>/dev/null")
        if out:
            print(f"Found similar files:\n{out}")
        else:
            print("No similar files found")
    
    # Test 5: Test local curl (from VPS)
    print("\n" + "=" * 70)
    print("[TEST 5] Testing Local Access (curl from VPS)")
    print("=" * 70)
    exit_status, out, err = run_command(ssh, "curl -I -s http://localhost:8005/media/cover_pictures/1000783003_j9FFDUS.jpg 2>&1 | head -10")
    if "200 OK" in out or "HTTP" in out:
        print(f"✅ Local access works:")
        print(out)
    else:
        print(f"❌ Local access failed:")
        print(out or err)
    
    # Test 6: Check Django settings on VPS
    print("\n" + "=" * 70)
    print("[TEST 6] Checking Django Settings on VPS")
    print("=" * 70)
    exit_status, out, err = run_command(ssh, "cd /root/hapz_backend && source .venv/bin/activate && python -c \"from django.conf import settings; print('DEBUG:', settings.DEBUG); print('MEDIA_URL:', settings.MEDIA_URL); print('MEDIA_ROOT:', settings.MEDIA_ROOT); print('SERVE_MEDIA_IN_PRODUCTION:', getattr(settings, 'SERVE_MEDIA_IN_PRODUCTION', False))\" 2>&1")
    if exit_status == 0:
        print(f"✅ Django settings:")
        print(out)
    else:
        print(f"❌ Error checking settings:")
        print(err)
    
    # Test 7: Check URL patterns
    print("\n" + "=" * 70)
    print("[TEST 7] Checking URL Configuration")
    print("=" * 70)
    exit_status, out, err = run_command(ssh, "cd /root/hapz_backend && source .venv/bin/activate && python -c \"from django.urls import get_resolver; resolver = get_resolver(); [print(p.pattern) for p in resolver.url_patterns if 'media' in str(p.pattern).lower()]\" 2>&1")
    if exit_status == 0 and out:
        print(f"✅ Media URL patterns found:")
        print(out)
    else:
        print(f"⚠️  No explicit media URL patterns found (may use static())")
        print("   This is OK if SERVE_MEDIA_IN_PRODUCTION=True")
    
    # Test 8: Remote curl test (from your local machine perspective)
    print("\n" + "=" * 70)
    print("[TEST 8] Expected External URL")
    print("=" * 70)
    print(f"External URL: http://{HOST}:8005/media/cover_pictures/1000783003_j9FFDUS.jpg")
    print(f"\nTest from your browser or:")
    print(f"curl -I http://{HOST}:8005/media/cover_pictures/1000783003_j9FFDUS.jpg")
    
    # Summary and Recommendations
    print("\n" + "=" * 70)
    print("DIAGNOSIS SUMMARY")
    print("=" * 70)
    
    issues = []
    
    # Check Daphne
    exit_status, out, err = run_command(ssh, "ps aux | grep daphne | grep -v grep")
    if not out:
        issues.append("❌ Daphne server is not running")
    
    # Check file
    exit_status, out, err = run_command(ssh, "ls -lh /root/hapz_backend/media/cover_pictures/1000783003_j9FFDUS.jpg 2>&1")
    if exit_status != 0:
        issues.append("❌ File does not exist on server")
    
    # Check local access
    exit_status, out, err = run_command(ssh, "curl -I -s http://localhost:8005/media/cover_pictures/1000783003_j9FFDUS.jpg 2>&1 | grep -q '200 OK'")
    if exit_status != 0:
        issues.append("❌ Django cannot serve the file locally")
    
    if issues:
        print("\n⚠️  ISSUES FOUND:")
        for issue in issues:
            print(f"  {issue}")
        
        print("\n🔧 RECOMMENDED FIXES:")
        print("""
1. If Daphne is not running:
   cd /root/hapz_backend && source .venv/bin/activate
   pkill -f daphne
   nohup daphne -b 0.0.0.0 -p 8005 config.asgi:application > logs/daphne.log 2>&1 &

2. If file doesn't exist:
   The file was never uploaded or was deleted. Try uploading again from Flutter app.

3. If Django can't serve locally:
   Check file permissions: chmod 644 /root/hapz_backend/media/cover_pictures/*.jpg
   Check Django logs: tail -f /root/hapz_backend/logs/daphne.log
""")
    else:
        print("\n✅ ALL TESTS PASSED!")
        print("The server should be accessible externally.")
        print("\nIf Flutter still gets 404, check:")
        print("  1. Firewall rules on VPS (port 8005 must be open)")
        print("  2. CORS settings in Django")
        print("  3. Backend URL in Flutter app matches http://72.62.4.119:8005")
    
    ssh.close()
    
except Exception as e:
    print(f"\n❌ ERROR: {e}")
    print("\nPossible issues:")
    print("  - VPS credentials are incorrect")
    print("  - Network connectivity problem")
    print("  - SSH is not enabled on VPS")
