import logging
import sys
from functools import lru_cache

from django.conf import settings
from loguru import logger


class InterceptHandler(logging.Handler):
    def emit(self, record: logging.LogRecord) -> None:
        try:
            level = logger.level(record.levelname).name
        except ValueError:
            level = record.levelno

        frame, depth = logging.currentframe(), 2
        while frame.f_code.co_filename == logging.__file__:
            frame = frame.f_back
            depth += 1

        logger.opt(depth=depth, exception=record.exc_info).log(
            level, record.getMessage()
        )


@lru_cache(maxsize=1)
def setup_logging() -> None:
    logging.root.handlers = [InterceptHandler()]
    logging.root.setLevel(settings.LOGGING_LEVEL)

    for file in logging.root.manager.loggerDict.keys():
        logging.getLogger(file).handlers = []
        logging.getLogger(file).propagate = True

    logger.configure(
        handlers=[
            {
                "sink": sys.stdout,
                "format": "<green>{time:YYYY-MM-DD HH:mm:ss}</green> | <level>{level: <5}</level> | <cyan>{file}</cyan>:<cyan>{line}</cyan> - <level>{message}</level>",
                "filter": lambda record: record["extra"].get("target") != "file",
            },
            {
                "sink": settings.LOG_FILE,
                "rotation": "10 MB",
                "retention": "10 days",
                "format": "{time:YYYY-MM-DD HH:mm:ss} | {level: <5} | {file}:{line} - {message}",
            },
        ]
    )


setup_logging()
