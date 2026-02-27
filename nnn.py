import os
import sys
import subprocess

def log_info(message):
    print(f"[INFO] {message}")

def log_success(message):
    print(f"[SUCCESS] {message}")

def log_error(message):
    print(f"[ERROR] {message}", file=sys.stderr)

def log_warning(message):
    print(f"[WARNING] {message}")

def run_tests():
    """
    Run the hapztext-v2 API test suite.
    """
    log_info("Starting hapztext-v2 API Test Suite...")
    
    # Ensure correct settings are used
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.testing")
    
    # Path to the virtual environment python interpreter
    venv_python = os.path.join(".venv", "Scripts", "python.exe")
    
    if not os.path.exists(venv_python):
        # Fallback to system python if venv is not found in the expected location
        log_warning(f"Virtual environment python not found at {venv_python}. Using default python.")
        venv_python = sys.executable

    # Construct the pytest command
    cmd = [
        venv_python, 
        "-m", "pytest", 
        "apps/presentation/tests/",
        "-v",  # Verbose
        "--tb=short"  # Short traceback
    ]
    
    log_info(f"Executing: {' '.join(cmd)}")
    
    try:
        # Run the command and pipe output to terminal
        result = subprocess.run(cmd, check=False)
        
        if result.returncode == 0:
            log_success("All tests passed successfully!")
        else:
            log_error(f"Tests failed with exit code: {result.returncode}")
            
        sys.exit(result.returncode)
        
    except KeyboardInterrupt:
        log_warning("Test execution interrupted by user.")
        sys.exit(1)
    except Exception as e:
        log_error(f"An unexpected error occurred: {e}")
        sys.exit(1)

if __name__ == "__main__":
    run_tests()
