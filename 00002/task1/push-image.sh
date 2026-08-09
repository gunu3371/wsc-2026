#!/usr/bin/env bash
set -euo pipefail
region=ap-northeast-2
repo=$(terraform output -raw ecr_repository_url)
aws ecr get-login-password --region "$region" | docker login --username AWS --password-stdin "${repo%%/*}"
docker build --platform linux/amd64 -t "$repo:stable" .
docker push "$repo:stable"
echo "Pushed $repo:stable; set book_image_uri=$repo:stable before the Kubernetes apply."
