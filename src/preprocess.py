# src/preprocess.py
import os
import json
import pandas as pd

from src.config import TARGET_COLUMN
from src.formatting import header
from src.load import load_data
from src.logger import get_logger
from src.paths import get_model_dir, print_paths

logger = get_logger()


# No need to modify this function
def reformat_df_columns(df: pd.DataFrame) -> pd.DataFrame:
    df.columns = [col.lower().replace(" ", "_") for col in df.columns]
    logger.info(f"Reformatted columns: {list(df.columns)}")
    return df


# No need to modify this function
def drop_cols(df: pd.DataFrame, cols_to_drop: list[str]) -> pd.DataFrame:
    df = df.drop(columns=[c for c in cols_to_drop if c in df.columns])
    logger.info(f"Dropped columns: {cols_to_drop}")
    return df


# This function has to be modified
def feature_engineering(df: pd.DataFrame) -> pd.DataFrame:
    ###############################################################################
    # familysize
    if {"sibsp", "parch"}.issubset(df.columns):
        df["familysize"] = (df["sibsp"] + df["parch"] + 1).astype(float)

    # sex encoding
    if "sex" in df.columns:
        df["sex"] = df["sex"].map({"male": 0, "female": 1}).fillna(-1).astype(float)

    # embarked encoding
    if "embarked" in df.columns:
        df["embarked"] = df["embarked"].fillna("Unknown")
        unique_vals = df["embarked"].astype(str).unique().tolist()
        mapping = {v: i for i, v in enumerate(unique_vals)}
        df["embarked"] = df["embarked"].map(mapping).fillna(-1).astype(float)

    ###############################################################################
    logger.info("Feature engineered")
    return df


def fill_na_train(df: pd.DataFrame) -> pd.DataFrame:
    """
    Fill NA using medians (TRAIN MODE ONLY).
    The real median values will later be saved by train.py.
    """
    for col in ["age", "fare"]:
        if col in df.columns:
            df[col] = df[col].astype(float).fillna(df[col].median())
    logger.info("Filled NA (train mode: computed medians)")
    return df


def fill_na_predict(df: pd.DataFrame) -> pd.DataFrame:
    """
    Fill NA using saved imputation.json (PREDICT MODE ONLY).
    """
    model_dir = get_model_dir()
    imputation_file = model_dir / "imputation.json"

    if not imputation_file.exists():
        raise FileNotFoundError(
            f"imputation.json not found at {imputation_file}. " "Run training first to generate imputation values."
        )

    with open(imputation_file, "r") as f:
        imputation_values = json.load(f)

    for col, val in imputation_values.items():
        if col in df.columns:
            df[col] = df[col].astype(float).fillna(val)

    logger.info(f"Filled NA using saved imputation values: {imputation_values}")
    return df


# No need to modify this function
def reorder_columns(df: pd.DataFrame) -> pd.DataFrame:
    int_cols = sorted([col for col in df.select_dtypes(include=["int", "int64"]).columns if col != TARGET_COLUMN])
    float_cols = sorted([col for col in df.select_dtypes(include=["float", "float64"]).columns if col != TARGET_COLUMN])
    object_cols = sorted(
        [col for col in df.select_dtypes(include=["object", "string"]).columns if col != TARGET_COLUMN]
    )

    new_order = int_cols + float_cols + object_cols

    if TARGET_COLUMN in df.columns:
        new_order.append(TARGET_COLUMN)

    logger.info(f"Reordered columns: {new_order}")
    return df[new_order]


# This function has to be modified
def preprocess(df: pd.DataFrame, mode: str = "train", show_section: bool = True) -> pd.DataFrame:
    """
    Preprocess the dataframe.

    mode="train"   → compute medians locally (training flow)
    mode="predict" → load medians from imputation.json (inference flow)
    """

    if show_section:
        logger.info(header(f"DATA PREPROCESSING [{mode.upper()}]"))

    df = df.copy()

    # 1. Normalize names
    df = reformat_df_columns(df)

    # 2. Drop useless Titanic-specific columns
    df = drop_cols(df, ["passengerid", "name", "ticket", "cabin"])

    # 3. Feature engineering BEFORE imputation
    df = feature_engineering(df)

    # 4. Fill NA depending on mode
    if mode == "train":
        df = fill_na_train(df)
    elif mode == "predict":
        df = fill_na_predict(df)
    else:
        raise ValueError("mode must be 'train' or 'predict'")

    # 5. Drop duplicates
    df = df.drop_duplicates()

    # 6. Reorder columns
    df = reorder_columns(df)

    logger.info(50 * "=" + "\n")

    return df.reset_index(drop=True)


if __name__ == "__main__":
    print_paths()
    df = load_data()
    df = preprocess(df, mode="train")
    print(df.head())
    os.makedirs("input/data/processed", exist_ok=True)
    df.to_csv("input/data/processed/data.csv", index=False)