import os
import paramiko

HOST = "72.62.4.119"
USERNAME = "root"
PASSWORD = "Mathscrusader123."
REMOTE_PATH = "/root/hapz_backend"
LOG_FILE = f"{REMOTE_PATH}/logs/deploy.log"

def main():
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    try:
        ssh.connect(HOST, username=USERNAME, password=PASSWORD)
        print(f"Connected to {HOST}")
        
        # Check logs with more context
        print("\n--- Searching for ERROR in logs ---")
        stdin, stdout, stderr = ssh.exec_command(f"grep -C 10 'ERROR' {LOG_FILE} | tail -n 50")
        print(stdout.read().decode())
        
        # Check specifically for the Cloudinary exception
        print("\n--- Searching for Cloudinary exceptions ---")
        stdin, stdout, stderr = ssh.exec_command(f"grep -C 5 'cloudinary' {LOG_FILE} | tail -n 20")
        print(stdout.read().decode())
        
        ssh.close()
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
