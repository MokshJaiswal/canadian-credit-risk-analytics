# Simple logging setup shared by the script and the notebooks.
# Every message goes to the screen AND to logs/pipeline.log, so there is a
# record of each run (when it ran, how many rows, which checks passed).
#
# Usage:
#   from src.logger import get_logger
#   log = get_logger("fetch_rates")
#   log.info("Saved 141 months")

import logging
from pathlib import Path

Path("logs").mkdir(exist_ok=True)

# WARNING for everything else (so libraries like matplotlib stay quiet),
# INFO for our own loggers (set in get_logger below)
logging.basicConfig(
    level=logging.WARNING,
    format="%(asctime)s | %(name)s | %(levelname)s | %(message)s",
    handlers=[
        logging.FileHandler("logs/pipeline.log", encoding="utf-8"),
        logging.StreamHandler(),
    ],
)


def get_logger(name: str) -> logging.Logger:
    logger = logging.getLogger(name)
    logger.setLevel(logging.INFO)
    return logger
