<p align="center">
  <img src=".github/titanic-ship.png" alt="Titanic" width="400">
</p>

# titanic-sagemaker

Prediction of Titanic survival: training a classification model locally or on AWS SageMaker, experiment tracking with MLflow, and exposing a FastAPI inference API.

## Features

- Load and preprocess Titanic data; train a classifier (e.g. sklearn pipeline).
- Run training locally or as a SageMaker training job (Docker-based).
- Deploy inference as a SageMaker endpoint or run the API locally with uvicorn.
- Track runs and artifacts with MLflow.

## Project structure

- `src/` — data loading, preprocessing, training, evaluation, prediction.
- `api/` — FastAPI app for inference.
- `input/` — sample data and example JSON input.
- `output/` — trained model artifacts and metrics (e.g. after local training).
- `Dockerfile.training`, `Dockerfile.inference` — images for SageMaker.

## Configuration

Copy `.env.example` (or create `.env`) at the project root with the following variables:

```env
AWS_REGION=eu-west-1
AWS_ACCOUNT_ID=123456789012
MLFLOW_TRACKING_URI=http://127.0.0.1:5001
```

| Variable | Description |
|---|---|
| `AWS_REGION` | AWS region used for ECR, S3, and SageMaker |
| `AWS_ACCOUNT_ID` | AWS account ID (used to build ECR URLs and bucket names) |
| `MLFLOW_TRACKING_URI` | MLflow tracking server URL — run `make run-mlflow-ui` to start it locally |

The Makefile derives all other values (`AWS_ECR_*_REPOSITORY_URL`, `AWS_MAIN_BUCKET_NAME`, etc.) from these three variables and the project directory name.

## Author

Allister K.

## License

MIT License — see [LICENSE](LICENSE) for details.
