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
EXCLUDE_DIRS = [".git", ".venv", "__pycache__", ".pytest_cache", "staticfiles", "media", "android", "ios", "build", "linux", "macos", "windows", "web", ".dart_tool", "db.sqlite3", "db.sqlite3-journal"]

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

def sync_codebase(ssh):
    """Upload project files using SFTP."""
    print(f"[INFO] Synchronizing codebase to {REMOTE_PATH}...")
    sftp = ssh.open_sftp()
    
    # Ensure remote directory exists
    mkdir_p_remote(sftp, REMOTE_PATH)

    local_root = os.getcwd()
    for root, dirs, files in os.walk(local_root):
        # Filter excluded directories
        dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS and not d.startswith(".")]
        
        # Calculate remote path using forward slashes
        rel_path = os.path.relpath(root, local_root)
        if rel_path == ".":
            rem_dir = REMOTE_PATH
        else:
            # Ensure we only use forward slashes for remote
            rem_dir = f"{REMOTE_PATH}/{rel_path.replace(os.sep, '/')}"
            mkdir_p_remote(sftp, rem_dir)

        for f in files:
            # Skip hidden files EXCEPT .env, and the deployment script itself
            if (f.startswith(".") and f != ".env") or f == "deploy_vps.py" or f.endswith(".pyc") or f == "test_calls_output.txt":
                continue
                
            local_file = os.path.join(root, f)
            remote_file = f"{rem_dir}/{f}"
            
            try:
                sftp.put(local_file, remote_file)
            except Exception as e:
                print(f"[WARNING] Failed to upload {f}: {e}")
    
    sftp.close()
    print("[SUCCESS] Codebase synchronized.")

# --- Main Deployment Loop ---

def main():
    print("==========================================")
    print("      Django VPS Deployment Script        ")
    print("==========================================")

    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    try:
        print(f"[INFO] Connecting to {HOST}...")
        ssh.connect(HOST, username=USERNAME, password=PASSWORD)
    except Exception as e:
        print(f"[ERROR] Failed to connect: {e}")
        sys.exit(1)

    # 1. Clear existing process on the target port
    run_remote_command(ssh, f"fuser -k {PORT}/tcp || true", f"Clearing existing process on port {PORT}")

    # 2. Upload Code
    sync_codebase(ssh)

    # 3. Patch remote .env
    patch_cmds = [
        f"touch {REMOTE_PATH}/.env",
        f"grep -q 'DJANGO_ALLOWED_HOSTS' {REMOTE_PATH}/.env && sed -i 's/^DJANGO_ALLOWED_HOSTS=.*/DJANGO_ALLOWED_HOSTS={HOST},localhost,127.0.0.1/' {REMOTE_PATH}/.env || echo 'DJANGO_ALLOWED_HOSTS={HOST},localhost,127.0.0.1' >> {REMOTE_PATH}/.env",
        f"grep -q 'DJANGO_DEBUG' {REMOTE_PATH}/.env && sed -i 's/^DJANGO_DEBUG=.*/DJANGO_DEBUG=False/' {REMOTE_PATH}/.env || echo 'DJANGO_DEBUG=False' >> {REMOTE_PATH}/.env",
        f"grep -q 'DJANGO_SECRET_KEY' {REMOTE_PATH}/.env || echo 'DJANGO_SECRET_KEY=production-secret-change-me-later' >> {REMOTE_PATH}/.env",
        f"grep -q 'DJANGO_SECURE_SSL_REDIRECT' {REMOTE_PATH}/.env && sed -i 's/^DJANGO_SECURE_SSL_REDIRECT=.*/DJANGO_SECURE_SSL_REDIRECT=False/' {REMOTE_PATH}/.env || echo 'DJANGO_SECURE_SSL_REDIRECT=False' >> {REMOTE_PATH}/.env",
        f"grep -q 'BACKEND_DOMAIN' {REMOTE_PATH}/.env && sed -i 's|^BACKEND_DOMAIN=.*|BACKEND_DOMAIN=http://{HOST}:{PORT}|' {REMOTE_PATH}/.env || echo 'BACKEND_DOMAIN=http://{HOST}:{PORT}' >> {REMOTE_PATH}/.env",
        f"grep -q 'CLOUDINARY_CLOUD_NAME' {REMOTE_PATH}/.env || echo 'CLOUDINARY_CLOUD_NAME=test' >> {REMOTE_PATH}/.env",
        f"grep -q 'CLOUDINARY_API_KEY' {REMOTE_PATH}/.env || echo 'CLOUDINARY_API_KEY=test' >> {REMOTE_PATH}/.env",
        f"grep -q 'CLOUDINARY_API_SECRET' {REMOTE_PATH}/.env || echo 'CLOUDINARY_API_SECRET=test' >> {REMOTE_PATH}/.env",
        f"grep -q 'DATABASE_URL' {REMOTE_PATH}/.env || echo 'DATABASE_URL=postgresql://hapztext:hapztext_pass_2024@localhost:5432/hapztext_db' >> {REMOTE_PATH}/.env"
    ]
    run_remote_command(ssh, " && ".join(patch_cmds), "Configuring environment variables")

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
