#!/usr/bin/env bash
set -euo pipefail
REGION=us-west-2
REPOSITORY=skills-sqs-worker
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$REGISTRY"
docker build --platform linux/amd64 -t "${REGISTRY}/${REPOSITORY}:latest" addons/workloads/assets
docker push "${REGISTRY}/${REPOSITORY}:latest"
