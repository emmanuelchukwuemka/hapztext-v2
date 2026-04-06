import os
import sys
import time
import socket
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
REPO_URL = "https://github.com/emmanuelchukwuemka/hapztext-v2"
BRANCH = "main"  # The branch to deploy

# --- Helper Functions ---

def run_remote_command(ssh, command, description="", wait=True):
    """Run a command on the remote server and print its output."""
    if description:
        print(f"[INFO] {description}...")
    
    stdin, stdout, stderr = ssh.exec_command(command)
    
    if not wait:
        # Give a small buffer for the command to start
        time.sleep(1)
        return True, "Command sent to background"

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

def mkdir_p_remote(sftp, remote_directory):
    """Recursive mkdir on remote server."""
    if remote_directory == "/":
        return
    if remote_directory == "":
        return
    try:
        sftp.stat(remote_directory)
    except IOError:
        parent = os.path.dirname(remote_directory.rstrip('/'))
        mkdir_p_remote(sftp, parent)
        try:
            sftp.mkdir(remote_directory)
            print(f"[INFO] Created remote directory: {remote_directory}")
        except IOError:
            pass

def push_to_github():
    """Push local changes to GitHub."""
    print("[INFO] Pushing changes to GitHub...")
    try:
        # Check for local changes to commit
        status = subprocess.run(["git", "status", "--porcelain"], capture_output=True, text=True).stdout
        if status:
            print("[INFO] Local changes detected, committing...")
            subprocess.run(["git", "add", "."], check=True)
            subprocess.run(["git", "commit", "-m", "Deployment update: code synchronization"], check=True)
        
        # Push to origin
        print(f"[INFO] Pushing to origin {BRANCH}...")
        subprocess.run(["git", "push", "origin", f"main:{BRANCH}" if BRANCH != "main" else "main"], check=True)
        print("[SUCCESS] Pushed to GitHub.")
        return True
    except subprocess.CalledProcessError as e:
        print(f"[ERROR] Failed to push to GitHub: {e}")
        return False

def sync_codebase_via_git(ssh):
    """Clone or pull the codebase from GitHub on the remote server for a clean start."""
    print(f"[INFO] Synchronizing codebase from GitHub to {REMOTE_PATH}...")
    
    # 1. Ensure git is installed on the server
    run_remote_command(ssh, "which git || (apt-get update && apt-get install -y git)", "Checking for git on server")

    # 2. Clear existing directory for a fresh start (per user request: "clear everything")
    # We remove the directory to ensure no stale files remain. 
    # NOTE: This will remove any local logs/media inside the folder.
    run_remote_command(ssh, f"rm -rf {REMOTE_PATH}", f"Clearing remote directory {REMOTE_PATH}")
    
    # 3. Clone the repository fresh
    clone_cmd = f"git clone -b {BRANCH} {REPO_URL} {REMOTE_PATH}"
    success, _ = run_remote_command(ssh, clone_cmd, f"Cloning repository from {REPO_URL}")
    
    if success:
        print("[SUCCESS] Codebase synchronized via Git.")
    return success

# --- Main Deployment Loop ---

def main():
    print("==========================================")
    print("      Django VPS Deployment Script        ")
    print("==========================================")

    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    try:
        print(f"[INFO] Connecting to {HOST}...")
        ssh.connect(HOST, username=USERNAME, password=PASSWORD, timeout=30)
    except Exception as e:
        print(f"[ERROR] Failed to connect: {e}")
        sys.exit(1)

    # 1. Clear existing process on the target port
    run_remote_command(ssh, f"fuser -k {PORT}/tcp || true", f"Clearing existing process on port {PORT}")

    # 2. Push local changes to GitHub
    if not push_to_github():
        print("[WARNING] Proceeding without local push. (Is the branch already up to date?)")

    # 3. Remote Synchronization (Clear and Clone)
    if not sync_codebase_via_git(ssh):
        print("[ERROR] Failed to synchronize codebase. Check repository accessibility.")
        sys.exit(1)

    # 3. Generate and Upload .env file
    print("[INFO] Generating production .env file...")
    env_content = f"""DJANGO_ENVIRONMENT=production
DJANGO_SECRET_KEY=production-secret-{time.time()}
DJANGO_DEBUG=False
DJANGO_ALLOWED_HOSTS={HOST},localhost,127.0.0.1
CORS_ALLOWED_ORIGINS=http://{HOST}:{PORT},http://localhost:3000
BACKEND_DOMAIN=http://{HOST}:{PORT}
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
"""
    sftp = ssh.open_sftp()
    with sftp.file(f"{REMOTE_PATH}/.env", "w") as f:
        f.write(env_content)
    sftp.close()
    print("[SUCCESS] Environment variables configured.")

    # 4. Setup Project Environment
    base_env = f"export DJANGO_SETTINGS_MODULE=config.settings.production"
    log_file = f"{REMOTE_PATH}/logs/deploy.log"
    
    setup_cmds = [
        f"mkdir -p {REMOTE_PATH}/logs {REMOTE_PATH}/media",
        f"chmod -R 777 {REMOTE_PATH}/media || true",
        f"cd {REMOTE_PATH}",
        # Install PostgreSQL if not already installed
        "which psql || (apt-get update && apt-get install -y postgresql postgresql-contrib)",
        # Start PostgreSQL service
        "service postgresql start || true",
        # Create database and user
        "sudo -u postgres psql -c \"CREATE USER hapztext WITH PASSWORD 'hapztext_pass_2024';\" || true",
        "sudo -u postgres psql -c \"CREATE DATABASE hapztext_db OWNER hapztext;\" || true",
        "sudo -u postgres psql -c \"GRANT ALL PRIVILEGES ON DATABASE hapztext_db TO hapztext;\" || true",
        # Python environment and dependencies
        "python3 -m venv .venv || true",
        f"source .venv/bin/activate && {base_env} && pip install -r requirements.txt daphne psycopg2-binary --quiet",
        f"source .venv/bin/activate && {base_env} && python3 manage.py migrate --noinput",
        f"source .venv/bin/activate && {base_env} && python3 manage.py collectstatic --noinput --clear --verbosity=0"
    ]
    run_remote_command(ssh, " && ".join(setup_cmds), "Setting up PostgreSQL and running migrations")

    # 5. Start Server in Background
    start_cmd = (
        f"cd {REMOTE_PATH} && "
        f"source .venv/bin/activate && "
        f"{base_env} && "
        f"nohup daphne -b 0.0.0.0 -p {PORT} config.asgi:application > {log_file} 2>&1 &"
    )
    run_remote_command(ssh, start_cmd, f"Starting Daphne server on port {PORT}", wait=False)

    # 6. Verify Server Status
    print(f"[INFO] Verifying server status on port {PORT}...")
    time.sleep(3) # Wait for startup
    
    check_cmd = f"netstat -tuln | grep :{PORT}"
    success, result = run_remote_command(ssh, check_cmd)
    
    if success and result:
        print("\n" + "="*42)
        print("[SUCCESS] Update completed successfully!")
        print(f"API URL: http://{HOST}:{PORT}/api/v1/")
        print("="*42)
    else:
        print("\n" + "="*42)
        print("[WARNING] Server may have failed to start. Check logs.")
        print(f"Log: {log_file}")
        print("="*42)
    
    ssh.close()

if __name__ == "__main__":
    main()
