# Makefile
.PHONY: print-env help install-pip install-requirements install-requirements-dev install-all run-api clean isort black ruff install-pre-commit pre-commit build-training-amd64 build-training-arm64 build-inference-amd64 run-training-arm64 stop-training authenticate-aws create-bucket upload-data-to-bucket check-main-bucket create-ecr-training-repository create-ecr-inference-repository tag-training-image-amd64 tag-inference-image-amd64 push-training-image-amd64 push-inference-image-amd64 sagemaker-deploy-training sagemaker-create-model sagemaker-deploy-inference pipeline-local-training pipeline-sagemaker-training pipeline-sagemaker-inference 

MAKEFLAGS += --silent

include .env
export $(shell sed 's/=.*//' .env)

SRC_DIR := src
API_DIR := api
PROJECT_NAME := $(shell basename $(PWD))
IMAGE_NAME := $(PROJECT_NAME)-image
CONTAINER_NAME := $(PROJECT_NAME)-container

AWS_REGION := $(AWS_REGION)
AWS_ACCOUNT_ID := $(AWS_ACCOUNT_ID)
AWS_ECR_TRAINING_REPOSITORY_NAME := $(PROJECT_NAME)-training-repo
AWS_ECR_INFERENCE_REPOSITORY_NAME := $(PROJECT_NAME)-inference-repo
AWS_ECR_TRAINING_REPOSITORY_URL := $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(AWS_ECR_TRAINING_REPOSITORY_NAME)
AWS_ECR_INFERENCE_REPOSITORY_URL := $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(AWS_ECR_INFERENCE_REPOSITORY_NAME)
AWS_MAIN_BUCKET_NAME := $(PROJECT_NAME)-bucket-$(AWS_ACCOUNT_ID)

BLUE := \033[34m
RESET := \033[0m

# ====================================================================================================================================

help:  ## Show the list of available commands
	echo "→ List of available commands:"
	grep -h -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  🔹 %-35s %s\n", $$1, $$2}'

print-env:  ## Print loaded environment variables
	echo "PROJECT_NAME=$(PROJECT_NAME)"
	echo "IMAGE_NAME=$(IMAGE_NAME)"
	echo "CONTAINER_NAME=$(CONTAINER_NAME)"
	echo "AWS_REGION=$(AWS_REGION)"
	echo "AWS_ACCOUNT_ID=$(AWS_ACCOUNT_ID)"
	echo "AWS_ECR_TRAINING_REPOSITORY_NAME=$(AWS_ECR_TRAINING_REPOSITORY_NAME)"
	echo "AWS_ECR_INFERENCE_REPOSITORY_NAME=$(AWS_ECR_INFERENCE_REPOSITORY_NAME)"
	echo "AWS_ECR_TRAINING_REPOSITORY_URL=$(AWS_ECR_TRAINING_REPOSITORY_URL)"
	echo "AWS_ECR_INFERENCE_REPOSITORY_URL=$(AWS_ECR_INFERENCE_REPOSITORY_URL)"
	echo "AWS_MAIN_BUCKET_NAME=$(AWS_MAIN_BUCKET_NAME)"
	echo "MLFLOW_TRACKING_URI=$(MLFLOW_TRACKING_URI)"


# ====================================================================================================================================
#  Librairies installations
# ====================================================================================================================================

install-pip:  ## Install pip
	pip install --upgrade pip setuptools wheel --quiet
	echo "✅ pip, setuptools and wheel upgraded"

install-requirements:  ## Install libraries from requirements.txt
	pip install -r requirements.txt --quiet
	echo "✅ Libraries from requirements.txt installed successfully"

install-requirements-dev: install-pip  ## Install libraries from requirements-dev.txt
	pip install -r requirements-dev.txt --quiet
	echo "✅ Libraries from requirements-dev.txt installed successfully"

install-all: install-pip install-requirements-dev install-requirements  ## Install all libraries
	echo "✅ All libraries installed successfully"


# ====================================================================================================================================
#  Training & API
# ====================================================================================================================================

run-training:  ## Run the training locally
	echo "⏳ Training locally...\n"
	python train.py

run-api:  ## Run the API locally
	echo "⏳ FastAPI should be running at http://localhost:8080...\n"
	uvicorn $(API_DIR).main:app --host localhost --port 8080

run-mlflow-ui:  ## Run the MLflow UI locally
	echo "⏳ MLflow UI should be running at http://localhost:5001...\n"
	mlflow ui --backend-store-uri "sqlite:///mlflow.db" --host 127.0.0.1 --port 5001


# ====================================================================================================================================
#  Cleaning & Formatting
# ====================================================================================================================================

clean:  ## Remove temporary files
	find . -type d \( -name ".venv" -prune \) -o -type d \( -name "__pycache__" -o -name ".pytest_cache" \) -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
	echo "✅ Temporary files removed"

isort:  ## Sort Python imports
	echo "👷 Sorting imports with isort..."
	isort $(SRC_DIR) $(API_DIR) train.py
	echo "✅ Imports sorted with isort"

black:  ## Format Python code with Black
	echo "🎨 Formatting code with Black..."
	black $(SRC_DIR) $(API_DIR) train.py
	echo "✅ Code formatted with Black"

ruff:  ## Check and fix Python code with Ruff
	echo "👷 Checking and fixing code with Ruff..."
	ruff check $(SRC_DIR) $(API_DIR) train.py --fix
	ruff format $(SRC_DIR) $(API_DIR)
	echo "✅ Code checked and fixed with Ruff"

install-pre-commit:  ## Install pre-commit, only if the project is a Git repository
	if [ -d ".git" ]; then \
		echo "📦 Installing pre-commit..."; \
		pip install pre-commit && pre-commit install && echo "✅ Pre-commit installed"; \
	else \
		echo "ℹ️  Not a Git repository, skipping pre-commit installation"; \
	fi

pre-commit: isort black # ruff  ## Run all pre-commit checks without Git
	echo "✅ Pre-commit executed"


# ====================================================================================================================================
#  Docker
# ====================================================================================================================================

# Build

build-training-amd64:  ## Build the training Docker image for amd64
	docker build --platform linux/amd64 -t $(IMAGE_NAME)-training-amd64 -f Dockerfile.training .
	echo "✅ Training Docker image built for amd64"

build-training-arm64:  ## Build the training Docker image for arm64
	docker build --platform linux/arm64 -t $(IMAGE_NAME)-training-arm64 -f Dockerfile.training .
	echo "✅ Training Docker image built for arm64"

build-inference-amd64:  ## Build the inference Docker image for amd64
	docker build --platform linux/amd64 -t $(IMAGE_NAME)-inference-amd64 -f Dockerfile.inference .
	echo "✅ Inference Docker image built for amd64"

build-inference-arm64:  ## Build the inference Docker image for arm64
	docker build --platform linux/arm64 -t $(IMAGE_NAME)-inference-arm64 -f Dockerfile.inference .
	echo "✅ Inference Docker image built for arm64"

# Run 

run-training-arm64: build-training-arm64
	docker run --platform linux/arm64 --rm \
		-e SM_CHANNEL_TRAINING=/opt/ml/input/data/training \
		-e SM_MODEL_DIR=/opt/ml/model \
		-e SM_OUTPUT_DIR=/opt/ml/output \
		-v $(PWD)/input/data/training:/opt/ml/input/data/training \
		-v $(PWD)/models:/opt/ml/model \
		-v $(PWD)/predictions:/opt/ml/output \
		$(IMAGE_NAME)-training-arm64 \
		python /opt/ml/code/train
	echo "✅ Training Docker container executed"

run-inference-arm64: build-inference-arm64
	echo "⏳ Running inference Docker container..."
	echo "🔗 http://localhost:8080/docs#/"
	docker run --rm -p 8080:8080 --name $(CONTAINER_NAME)-inference-arm64 $(IMAGE_NAME)-inference-arm64

# Stop

stop-training:  ## Stop the training Docker container running locally
	docker stop $(CONTAINER_NAME)-training-arm64 || true
	docker stop $(CONTAINER_NAME)-training-amd64 || true
	echo "✅ Training Docker containers (arm64 and amd64) stopped"

stop-inference:  ## Stop the inference Docker container running locally
	docker stop $(CONTAINER_NAME)-inference-arm64 || true
	echo "✅ Inference Docker container (arm64) stopped"


# ====================================================================================================================================
#  AWS IAM
# ====================================================================================================================================

authenticate-aws:  ## Authenticate to AWS
	aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com
	echo "✅ AWS authenticated"


# ====================================================================================================================================
#  AWS S3
# ====================================================================================================================================

create-bucket:  ## Create the main AWS S3 bucket (if it doesn't exist)
	if aws s3 ls "s3://$(AWS_MAIN_BUCKET_NAME)" 2>/dev/null; then \
		echo "ℹ️  Bucket s3://$(AWS_MAIN_BUCKET_NAME) already exists in region $(AWS_REGION)"; \
	else \
		echo "⏳ Creating bucket s3://$(AWS_MAIN_BUCKET_NAME) in region $(AWS_REGION)..."; \
		aws s3 mb s3://$(AWS_MAIN_BUCKET_NAME) --region $(AWS_REGION); \
		echo "✅ Bucket s3://$(AWS_MAIN_BUCKET_NAME) created successfully in region $(AWS_REGION)"; \
		echo "🔗 https://$(AWS_REGION).console.aws.amazon.com/s3/buckets/$(AWS_MAIN_BUCKET_NAME)?region=$(AWS_REGION)&tab=objects" \
	fi

upload-data-to-bucket:  ## Upload the data to the AWS S3 bucket (timestamped + latest)
	timestamp=$$(date "+%Y-%m-%d-%H-%M-%S") && \
	echo "⏳ Uploading dataset with timestamp: $$timestamp" && \
	aws s3 cp input/data/training/data.csv s3://$(AWS_MAIN_BUCKET_NAME)/data/training/$$timestamp/data.csv --region $(AWS_REGION) && \
	echo "✅ Data uploaded to s3://$(AWS_MAIN_BUCKET_NAME)/data/training/$$timestamp/data.csv" && \
	aws s3 cp input/data/training/data.csv s3://$(AWS_MAIN_BUCKET_NAME)/data/training/latest/data.csv --region $(AWS_REGION) && \
	echo "$$timestamp" | aws s3 cp - s3://$(AWS_MAIN_BUCKET_NAME)/data/training/latest/version.txt --region $(AWS_REGION) && \
	echo "📝 Version file created: version.txt → $$timestamp" && \
	echo "📎 Copied to latest: s3://$(AWS_MAIN_BUCKET_NAME)/data/training/latest/data.csv" && \
	echo "🔗 https://$(AWS_REGION).console.aws.amazon.com/s3/buckets/$(AWS_MAIN_BUCKET_NAME)?region=$(AWS_REGION)&prefix=data%2Ftraining%2F&showversions=false&tab=objects"

check-main-bucket:  ## Check if the main AWS S3 bucket exists
	aws s3 ls s3://$(AWS_MAIN_BUCKET_NAME) --region $(AWS_REGION)
	echo "✅ Bucket s3://$(AWS_MAIN_BUCKET_NAME) exists in region $(AWS_REGION)"

show-latest-dataset-version:  ## Show the latest dataset version
	echo "🔍 Latest dataset version:"
	aws s3 cp s3://$(AWS_MAIN_BUCKET_NAME)/data/training/latest/version.txt - --region $(AWS_REGION)


# ====================================================================================================================================
#  AWS ECR
# ====================================================================================================================================

create-ecr-training-repository:  ## Create the AWS ECR repository for training (if not exists)
	if aws ecr describe-repositories --repository-names $(AWS_ECR_TRAINING_REPOSITORY_NAME) --region $(AWS_REGION) >/dev/null 2>&1; then \
		echo "ℹ️  ECR repository already exists: $(AWS_ECR_TRAINING_REPOSITORY_NAME) in region $(AWS_REGION)"; \
	else \
		echo "⏳ Creating new ECR repository: $(AWS_ECR_TRAINING_REPOSITORY_NAME)..."; \
		aws ecr create-repository \
			--repository-name $(AWS_ECR_TRAINING_REPOSITORY_NAME) \
			--image-scanning-configuration scanOnPush=true \
			--encryption-configuration encryptionType=AES256 \
			--region $(AWS_REGION); \
		echo "✅ AWS ECR repository $(AWS_ECR_TRAINING_REPOSITORY_NAME) created in region $(AWS_REGION)";
		echo "🔗 https://$(AWS_REGION).console.aws.amazon.com/ecr/private-registry/repositories?region=$(AWS_REGION)"; \
	fi

create-ecr-inference-repository:  ## Create the AWS ECR repository for inference (if not exists)
	if aws ecr describe-repositories --repository-names $(AWS_ECR_INFERENCE_REPOSITORY_NAME) --region $(AWS_REGION) >/dev/null 2>&1; then \
		echo "ℹ️  ECR repository already exists: $(AWS_ECR_INFERENCE_REPOSITORY_NAME) in region $(AWS_REGION)"; \
	else \
		echo "⏳ Creating new ECR repository: $(AWS_ECR_INFERENCE_REPOSITORY_NAME)..."; \
		aws ecr create-repository \
			--repository-name $(AWS_ECR_INFERENCE_REPOSITORY_NAME) \
			--image-scanning-configuration scanOnPush=true \
			--encryption-configuration encryptionType=AES256 \
			--region $(AWS_REGION); \
		echo "✅ AWS ECR repository $(AWS_ECR_INFERENCE_REPOSITORY_NAME) created in region $(AWS_REGION)"; \
		echo "🔗 https://$(AWS_REGION).console.aws.amazon.com/ecr/private-registry/repositories?region=$(AWS_REGION)"; \
	fi

tag-training-image-amd64:  ## Tag the training Docker image for amd64
	docker tag $(IMAGE_NAME)-training-amd64:latest $(AWS_ECR_TRAINING_REPOSITORY_URL):latest
	echo "✅ Training Docker image for amd64 tagged as $(AWS_ECR_TRAINING_REPOSITORY_URL):latest"

tag-inference-image-amd64:  ## Tag the inference Docker image for amd64
	docker tag $(IMAGE_NAME)-inference-amd64:latest $(AWS_ECR_INFERENCE_REPOSITORY_URL):latest
	echo "✅ Inference Docker image for amd64 tagged as $(AWS_ECR_INFERENCE_REPOSITORY_URL):latest"

push-training-image-amd64:  ## Push the training Docker image to the AWS repository
	docker push $(AWS_ECR_TRAINING_REPOSITORY_URL):latest
	echo "✅ Training Docker image for amd64 pushed to the AWS repository $(AWS_ECR_TRAINING_REPOSITORY_URL)"
	echo "🔗 https://$(AWS_REGION).console.aws.amazon.com/ecr/repositories/private/$(AWS_ACCOUNT_ID)/$(AWS_ECR_TRAINING_REPOSITORY_NAME)?region=$(AWS_REGION)"

push-inference-image-amd64:  ## Push the inference Docker image to the AWS repository
	docker push $(AWS_ECR_INFERENCE_REPOSITORY_URL):latest
	echo "✅ Inference Docker image for amd64 pushed to the AWS repository $(AWS_ECR_INFERENCE_REPOSITORY_URL)"
	echo "🔗 https://$(AWS_REGION).console.aws.amazon.com/ecr/repositories/private/$(AWS_ACCOUNT_ID)/$(AWS_ECR_INFERENCE_REPOSITORY_NAME)?region=$(AWS_REGION)"


# ====================================================================================================================================
#  AWS SageMaker
# ====================================================================================================================================

TIMESTAMP = $(shell date +%Y-%m-%d-%H-%M-%S)

sagemaker-deploy-training:  ## Deploy the training job using the latest dataset version
	dataset_ts=$$(aws s3 cp s3://$(AWS_MAIN_BUCKET_NAME)/data/training/latest/version.txt - --region $(AWS_REGION)) && \
	echo "⏳ Launching training job using dataset version: $$dataset_ts" && \
	aws sagemaker create-training-job \
		--region $(AWS_REGION) \
		--training-job-name $(PROJECT_NAME)-training-job-$(TIMESTAMP) \
		--role-arn arn:aws:iam::$(AWS_ACCOUNT_ID):role/SageMakerExecutionRole \
		--algorithm-specification TrainingImage=$(AWS_ECR_TRAINING_REPOSITORY_URL):latest,TrainingInputMode=File \
		--resource-config InstanceType=ml.m5.large,InstanceCount=1,VolumeSizeInGB=4 \
		--stopping-condition MaxRuntimeInSeconds=3600 \
		--output-data-config S3OutputPath=s3://$(AWS_MAIN_BUCKET_NAME)/models/$(TIMESTAMP)/ \
		--input-data-config "[{\"ChannelName\":\"training\",\"DataSource\":{\"S3DataSource\":{\"S3DataType\":\"S3Prefix\",\"S3Uri\":\"s3://$(AWS_MAIN_BUCKET_NAME)/data/training/$$dataset_ts/\",\"S3DataDistributionType\":\"FullyReplicated\"}},\"ContentType\":\"text/csv\",\"InputMode\":\"File\"}]" && \
	aws s3 cp s3://$(AWS_MAIN_BUCKET_NAME)/data/training/$$dataset_ts/data.csv \
	s3://$(AWS_MAIN_BUCKET_NAME)/models/$(TIMESTAMP)/$(PROJECT_NAME)-training-job-$(TIMESTAMP)/input/data.csv --region $(AWS_REGION) && \
	echo "$$dataset_ts" | aws s3 cp - \
	s3://$(AWS_MAIN_BUCKET_NAME)/models/$(TIMESTAMP)/$(PROJECT_NAME)-training-job-$(TIMESTAMP)/input/version.txt --region $(AWS_REGION) && \
	echo "✅ Training job launched using dataset version: $$dataset_ts" && \
	echo "📦 Dataset copied to model input folder" && \
	echo "🔗 https://$(AWS_REGION).console.aws.amazon.com/sagemaker/home?region=$(AWS_REGION)#/jobs/$(PROJECT_NAME)-training-job-$(TIMESTAMP)"

sagemaker-register-model:  ## Create a SageMaker model from training output (TIMESTAMP must be provided)
	if [ -z "$(TIMESTAMP)" ]; then \
	  echo "❌ TIMESTAMP not provided"; \
	  echo "Usage: make sagemaker-create-model TIMESTAMP=2025-11-11-12-12-51"; \
	  exit 1; \
	fi
	echo "⏳ Creating model with TIMESTAMP=$(TIMESTAMP)"
	aws sagemaker create-model \
	  --region $(AWS_REGION) \
	  --model-name $(PROJECT_NAME)-model-api \
	  --primary-container Image=$(AWS_ECR_INFERENCE_REPOSITORY_URL):latest,ModelDataUrl="s3://$(AWS_MAIN_BUCKET_NAME)/models/$(TIMESTAMP)/$(PROJECT_NAME)-training-job-$(TIMESTAMP)/output/model.tar.gz" \
	  --execution-role-arn arn:aws:iam::$(AWS_ACCOUNT_ID):role/SageMakerExecutionRole
	echo "✅ Model created: $(PROJECT_NAME)-model-api"
	echo "🔗 https://$(AWS_REGION).console.aws.amazon.com/sagemaker/home?region=$(AWS_REGION)#/models"


# ====================================================================================================================================
#  Real-time Endpoints (Inference)
# ====================================================================================================================================

sagemaker-create-endpoint-config:
	if aws sagemaker describe-endpoint-config \
		--endpoint-config-name $(PROJECT_NAME)-endpoint-config \
		--region $(AWS_REGION) >/dev/null 2>&1; then \
			echo "ℹ️  Endpoint config already exists: $(PROJECT_NAME)-endpoint-config"; \
	else \
		echo "⏳ Creating endpoint config: $(PROJECT_NAME)-endpoint-config..."; \
		aws sagemaker create-endpoint-config \
		  --region $(AWS_REGION) \
		  --endpoint-config-name $(PROJECT_NAME)-endpoint-config \
		  --production-variants VariantName=AllTraffic,ModelName=$(PROJECT_NAME)-model-api,InitialInstanceCount=1,InstanceType=ml.m5.large \
		  --tags Key=Project,Value=$(PROJECT_NAME); \
		echo "✅ Endpoint config created: $(PROJECT_NAME)-endpoint-config"; \
	fi
	echo "🔗 https://$(AWS_REGION).console.aws.amazon.com/sagemaker/home?region=$(AWS_REGION)#/endpointConfig"

sagemaker-create-endpoint:  ## Deploy the real-time endpoint
	if aws sagemaker describe-endpoint \
		--endpoint-name $(PROJECT_NAME)-endpoint \
		--region $(AWS_REGION) >/dev/null 2>&1; then \
			echo "ℹ️  Endpoint already exists: $(PROJECT_NAME)-endpoint"; \
	else \
			echo "⏳ Creating endpoint: $(PROJECT_NAME)-endpoint..."; \
			aws sagemaker create-endpoint \
			  --region $(AWS_REGION) \
			  --endpoint-name $(PROJECT_NAME)-endpoint \
			  --endpoint-config-name $(PROJECT_NAME)-endpoint-config; \
			echo "✅ Endpoint creation initiated: $(PROJECT_NAME)-endpoint"; \
	fi
	echo "🔗 https://$(AWS_REGION).console.aws.amazon.com/sagemaker/home?region=$(AWS_REGION)#/endpoints"


# ====================================================================================================================================
#  Batch Transform (Inference)
# ====================================================================================================================================

sagemaker-run-batch-transform:
	aws sagemaker create-transform-job \
	  --region $(AWS_REGION) \
	  --transform-job-name $(PROJECT_NAME)-inference-job-$(shell date +%Y-%m-%d-%H-%M-%S) \
	  --model-name $(PROJECT_NAME)-model-api \
	  --batch-strategy MultiRecord \
	  --transform-input "DataSource={S3DataSource={S3DataType=S3Prefix,S3Uri=s3://$(AWS_MAIN_BUCKET_NAME)/inference/inputs/}}" \
	  --transform-output S3OutputPath="s3://$(AWS_MAIN_BUCKET_NAME)/inference/predictions/" \
	  --transform-resources InstanceType=ml.m5.large,InstanceCount=1
	echo "✅ Batch transform job launched"
	echo "🔗 https://$(AWS_REGION).console.aws.amazon.com/sagemaker/home?region=$(AWS_REGION)#/transform-jobs"


# ====================================================================================================================================
#  Pipelines
# ====================================================================================================================================

pipeline-local-training: build-training-arm64 run-training-arm64

pipeline-sagemaker-training: build-training-amd64 authenticate-aws create-bucket upload-data-to-bucket create-ecr-training-repository tag-training-image-amd64 push-training-image-amd64 sagemaker-deploy-training

pipeline-local-inference: build-inference-arm64 run-inference-arm64

pipeline-sagemaker-inference: build-inference-amd64 authenticate-aws create-ecr-inference-repository tag-inference-image-amd64 push-inference-image-amd64


generate-example:
	