import os
import paramiko

HOST = "72.62.4.119"
USERNAME = "root"
PASSWORD = "Mathscrusader123."
REMOTE_PATH = "/root/hapz_backend"

def main():
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    try:
        ssh.connect(HOST, username=USERNAME, password=PASSWORD)
        print(f"Connected to {HOST}")
        
        # List contents of media directory recursively
        print("\n--- Contents of media directory ---")
        stdin, stdout, stderr = ssh.exec_command(f"find {REMOTE_PATH}/media -maxdepth 3 -ls")
        print(stdout.read().decode())
        
        # Check permissions
        print("\n--- Permissions of media directory ---")
        stdin, stdout, stderr = ssh.exec_command(f"ls -ld {REMOTE_PATH}/media")
        print(stdout.read().decode())
        
        ssh.close()
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
