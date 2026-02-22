# src/paths.py
import os
import platform
from pathlib import Path

from src.formatting import header
from src.logger import get_logger

logger = get_logger()

BASE_DIR = Path(__file__).resolve().parents[1]


def get_platform() -> str:
    return platform.machine()


def get_input_dir() -> Path:
    sm_path = os.getenv("SM_CHANNEL_TRAINING")
    if sm_path and Path(sm_path).exists():
        return Path(sm_path)
    # SageMaker default mount point for the "training" channel
    default_sm_training = Path("/opt/ml/input/data/training")
    if default_sm_training.exists():
        return default_sm_training
    # Fallback to generic SageMaker input path if present
    default_sm_input = Path("/opt/ml/input/data")
    if default_sm_input.exists():
        return default_sm_input
    local_path = BASE_DIR / "input" / "data" / "training"
    local_path.mkdir(parents=True, exist_ok=True)
    return local_path


def get_model_dir() -> Path:
    sm_dir = os.getenv("SM_MODEL_DIR")
    if sm_dir and Path(sm_dir).exists():
        return Path(sm_dir)
    # SageMaker default model directory
    default_sm_model = Path("/opt/ml/model")
    if default_sm_model.exists():
        return default_sm_model
    local_path = BASE_DIR / "output" / "model"
    local_path.mkdir(parents=True, exist_ok=True)
    return local_path


def get_output_dir() -> Path:
    sm_dir = os.getenv("SM_OUTPUT_DIR")
    if sm_dir and Path(sm_dir).exists():
        return Path(sm_dir)
    # SageMaker default output directory
    default_sm_output = Path("/opt/ml/output")
    if default_sm_output.exists():
        return default_sm_output
    local_path = BASE_DIR / "output"
    local_path.mkdir(parents=True, exist_ok=True)
    return local_path


def print_paths():
    logger.info(header("PATHS"))
    logger.info(f"PLATFORM   = {get_platform()}")
    logger.info(f"INPUT_DIR  = {get_input_dir().resolve()}")
    logger.info(f"MODEL_DIR  = {get_model_dir().resolve()}")
    logger.info(f"OUTPUT_DIR = {get_output_dir().resolve()}")
    logger.info(50 * "=" + "\n")


if __name__ == "__main__":
    print_paths()
