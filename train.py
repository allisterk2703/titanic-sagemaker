#!/usr/bin/env python3
import os

from src.config import TARGET_COLUMN
from src.evaluate import evaluate
from src.formatting import header
from src.load import load_data
from src.logger import get_logger
from src.paths import print_paths
from src.preprocess import preprocess
from src.train import train_model

logger = get_logger()


def print_environment_variables():
    """Print SageMaker environment variables if present."""
    sm_vars = {k: v for k, v in os.environ.items() if k.startswith("SM_")}

    if not sm_vars:
        logger.info("No SageMaker environment variables found\n")
        return

    logger.info(header("SAGEMAKER ENVIRONMENT VARIABLES"))
    for k, v in sm_vars.items():
        logger.info(f"{k} = {v}")
    logger.info(50 * "=" + "\n")


def main():
    print_paths()
    print_environment_variables()

    # Load raw data
    df = load_data()

    # Preprocess it
    df = preprocess(df)

    # Train and save artifacts (model, scaler, features, X_test_scaled, y_test)
    train_model(df, target_col=TARGET_COLUMN)

    # Evaluate using stored artifacts
    evaluate()


if __name__ == "__main__":
    main()
