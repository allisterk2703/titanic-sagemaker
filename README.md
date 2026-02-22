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

## Author

Allister K.

## License

MIT License — see [LICENSE](LICENSE) for details.
