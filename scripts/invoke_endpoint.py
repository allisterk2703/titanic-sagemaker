# scripts/invoke_endpoint.py
import os
import json
import boto3
from pathlib import Path
from dotenv import load_dotenv

import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from src.logger import get_logger

load_dotenv()

logger = get_logger()

PROJECT_NAME = Path(__file__).resolve().parents[1].name
ENDPOINT_NAME = f"{PROJECT_NAME}-endpoint"
AWS_REGION = os.getenv("AWS_REGION", "eu-north-1")

# Charger l'exemple JSON
example_path = Path(__file__).resolve().parents[1] / "input" / "example_input.json"
with example_path.open() as f:
    payload = json.load(f)

# SageMaker runtime client
client = boto3.client("sagemaker-runtime", region_name=AWS_REGION)

# Appel à l'endpoint
response = client.invoke_endpoint(
    EndpointName=ENDPOINT_NAME,
    ContentType="application/json",
    Body=json.dumps(payload),
)

# Résultat
result = json.loads(response["Body"].read().decode())
logger.info(f"✅ Prediction: {result}")
