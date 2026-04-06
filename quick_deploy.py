#!/usr/bin/env python3
"""
Quick Deploy Script for HapzText Backend
Installs PostgreSQL, configures database, and deploys the application
"""

import os
import sys
import time
import subprocess

try:
    import paramiko
except ImportError:
    print("[INFO] 'paramiko' package not found. Installing it now...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "paramiko"])
    import paramiko

# --- Configuration ---
HOST = "72.62.4.119"
USERNAME = "root"
PASSWORD = "Mathscrusader123."
REMOTE_PATH = "/root/hapz_backend"
PORT = 8005

def run_remote_command(ssh, command, description=""):
    """Run a command on the remote server and print its output."""
    if description:
        print(f"[INFO] {description}...")
    
    stdin, stdout, stderr = ssh.exec_command(command)
    exit_status = stdout.channel.recv_exit_status()
    out = stdout.read().decode().strip()
    err = stderr.read().decode().strip()
    
    if exit_status != 0:
        print(f"[ERROR] Command failed with exit status {exit_status}")
        print(f"Error: {err}")
        return False, err
    
    if out:
        print(out)
    return True, out

def main():
    print("==========================================")
    print("  Django Quick Deploy with PostgreSQL    ")
    print("==========================================")
    
    # Connect to server
    print(f"[INFO] Connecting to {HOST}...")
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(hostname=HOST, username=USERNAME, password=PASSWORD)
    
    try:
        # Stop existing process
        run_remote_command(ssh, f"fuser -k {PORT}/tcp || true", "Clearing existing process on port {PORT}")
        
        # Install PostgreSQL and dependencies
        run_remote_command(ssh, "apt-get update && apt-get install -y postgresql postgresql-contrib python3-pip", "Installing PostgreSQL and dependencies")
        
        # Start PostgreSQL
        run_remote_command(ssh, "service postgresql start", "Starting PostgreSQL service")
        time.sleep(2)
        
        # Create database and user
        run_remote_command(ssh, "sudo -u postgres psql -c \"CREATE USER hapztext WITH PASSWORD 'hapztext_pass_2024';\" 2>/dev/null || echo 'User may already exist'", "Creating database user")
        run_remote_command(ssh, "sudo -u postgres psql -c \"CREATE DATABASE hapztext_db OWNER hapztext;\" 2>/dev/null || echo 'Database may already exist'", "Creating database")
        run_remote_command(ssh, "sudo -u postgres psql -c \"GRANT ALL PRIVILEGES ON DATABASE hapztext_db TO hapztext;\" 2>/dev/null", "Granting privileges")
        
        # Configure .env file
        env_config = f"""BACKEND_DOMAIN=http://{HOST}:{PORT}
CORS_ALLOWED_ORIGINS=http://{HOST}:{PORT},http://localhost:8000
DJANGO_ALLOWED_HOSTS={HOST},localhost,127.0.0.1
DJANGO_DEBUG=False
DJANGO_SECRET_KEY=production-secret-change-me-later
DJANGO_SECURE_SSL_REDIRECT=False
DATABASE_URL=postgresql://hapztext:hapztext_pass_2024@localhost:5432/hapztext_db
CLOUDINARY_CLOUD_NAME=test
CLOUDINARY_API_KEY=test
CLOUDINARY_API_SECRET=test
REDIS_URL=redis://localhost:6379/0
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_DB=0
REDIS_PASSWORD=
EMAIL_BACKEND=django.core.mail.backends.console.EmailBackend
EMAIL_HOST=localhost
EMAIL_PORT=1025
EMAIL_USE_TLS=False
EMAIL_HOST_USER=
EMAIL_HOST_PASSWORD=
DEFAULT_FROM_EMAIL=noreply@hapztext.com
OTP_EXPIRY_MINUTES=10
MEDIA_ROOT=/root/hapz_backend/media
MEDIA_URL=/media/
WHITENOISE_ROOT=/root/hapz_backend/staticfiles
"""
        
        # Write .env file
        print("[INFO] Configuring .env file...")
        sftp = ssh.open_sftp()
        with sftp.file(f"{REMOTE_PATH}/.env", "w") as f:
            f.write(env_config)
        
        # Create directories
        run_remote_command(ssh, f"mkdir -p {REMOTE_PATH}/logs {REMOTE_PATH}/media && chmod -R 777 {REMOTE_PATH}/media", "Creating directories")
        
        # Setup Python environment and install dependencies
        run_remote_command(ssh, f"cd {REMOTE_PATH} && python3 -m venv .venv || true", "Creating virtual environment")
        run_remote_command(ssh, f"cd {REMOTE_PATH} && source .venv/bin/activate && pip install --upgrade pip setuptools wheel --quiet", "Upgrading pip")
        run_remote_command(ssh, f"cd {REMOTE_PATH} && source .venv/bin/activate && pip install -r requirements.txt psycopg2-binary daphne --quiet", "Installing dependencies")
        
        # Run migrations
        run_remote_command(ssh, f"cd {REMOTE_PATH} && source .venv/bin/activate && export DJANGO_SETTINGS_MODULE=config.settings.production && python manage.py migrate --noinput", "Running database migrations")
        
        # Collect static files
        run_remote_command(ssh, f"cd {REMOTE_PATH} && source .venv/bin/activate && export DJANGO_SETTINGS_MODULE=config.settings.production && python manage.py collectstatic --noinput --clear --verbosity=0", "Collecting static files")
        
        # Start Daphne server
        print(f"[INFO] Starting Daphne server on port {PORT}...")
        run_remote_command(ssh, f"cd {REMOTE_PATH} && source .venv/bin/activate && export DJANGO_SETTINGS_MODULE=config.settings.production && nohup daphne -b 0.0.0.0 -p {PORT} config.asgi:application > logs/daphne.log 2>&1 &", "Starting Daphne server")
        
        # Wait for server to start
        time.sleep(3)
        
        # Verify server is running
        run_remote_command(ssh, f"sleep 2 && netstat -tlnp | grep :{PORT}", "Verifying server status")
        
        print("\n==========================================")
        print("[SUCCESS] Deployment completed successfully!")
        print(f"API URL: http://{HOST}:{PORT}/api/v1/")
        print("==========================================")
        
    finally:
        ssh.close()

if __name__ == "__main__":
    main()
