import os
import sys

# Add the project root to sys.path
sys.path.append(os.getcwd())

from apps.core.logging import setup_logging
from loguru import logger

LOG_FILE = "logs/hapztext.log"
setup_logging("DEBUG", LOG_FILE)

logger.info("TEST LOG MESSAGE - INFO")
logger.error("TEST LOG MESSAGE - ERROR")
try:
    1/0
except Exception:
    logger.exception("TEST LOG MESSAGE - EXCEPTION")

print("Logging test completed. Check logs/hapztext.log")
