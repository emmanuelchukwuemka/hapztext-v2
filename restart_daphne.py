#!/usr/bin/env python3
"""
Restart Daphne with proper configuration
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
print("  Restarting Daphne Properly            ")
print("==========================================")

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(hostname=HOST, username=USERNAME, password=PASSWORD)

try:
    # Kill existing process
    print("\n[1] Killing existing Daphne process...")
    run_command(ssh, "pkill -f daphne || true")
    time.sleep(2)
    
    # Check Django can find settings
    print("\n[2] Testing Django settings...")
    exit_status, out, err = run_command(ssh, "cd /root/hapz_backend && source .venv/bin/activate && python -c \"from config.settings import production; print('DEBUG:', production.DEBUG); print('MEDIA_ROOT:', production.MEDIA_ROOT); print('SERVE_MEDIA_IN_PRODUCTION:', getattr(production, 'SERVE_MEDIA_IN_PRODUCTION', False))\"")
    if exit_status == 0:
        print(out)
    else:
        print(f"❌ Error: {err}")
    
    # Start Daphne properly
    print("\n[3] Starting Daphne in background...")
    run_command(ssh, "cd /root/hapz_backend && source .venv/bin/activate && export DJANGO_SETTINGS_MODULE=config.settings.production && nohup daphne -b 0.0.0.0 -p 8005 config.asgi:application > logs/daphne.log 2>&1 &")
    time.sleep(5)
    
    # Check if running
    print("\n[4] Checking if Daphne is running...")
    exit_status, out, err = run_command(ssh, "ps aux | grep daphne | grep -v grep")
    print(f"Process:\n{out}")
    
    exit_status, out, err = run_command(ssh, "netstat -tlnp | grep :8005")
    if out:
        print(f"✅ Server listening: {out}")
    else:
        print("❌ Server NOT listening!")
        # Check logs
        print("\n[5] Checking Daphne logs...")
        exit_status, out, err = run_command(ssh, "tail -50 /root/hapz_backend/logs/daphne.log")
        print(f"Logs:\n{out}")
    
    # Test media URL
    print("\n[6] Testing media file access...")
    exit_status, out, err = run_command(ssh, "curl -I http://localhost:8005/media/cover_pictures/1000783004.jpg 2>&1 | head -10")
    print(f"Response:\n{out}")
    
    print("\n==========================================")
    print("✅ Restart complete!")
    print("==========================================")
    
finally:
    ssh.close()
