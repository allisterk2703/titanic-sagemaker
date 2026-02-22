# src/logger.py
import logging
import sys
from datetime import datetime
from pathlib import Path


def get_logger():
    logger = logging.getLogger("titanic")
    logger.setLevel(logging.INFO)

    logger.propagate = False

    # Empêcher d'ajouter plusieurs handlers si déjà configuré
    if logger.handlers:
        return logger

    # Dossier logs/
    log_dir = Path(__file__).resolve().parents[1] / "logs"
    log_dir.mkdir(exist_ok=True)

    timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    log_file = log_dir / f"logs_{timestamp}.log"

    formatter = logging.Formatter("%(asctime)s - %(levelname)s - %(message)s")

    # Handler fichier
    fh = logging.FileHandler(log_file)
    fh.setFormatter(formatter)
    logger.addHandler(fh)

    # Handler stdout
    sh = logging.StreamHandler(sys.stdout)
    sh.setFormatter(formatter)
    logger.addHandler(sh)

    logger.info(f"Log file created: {log_file}\n")
    return logger
