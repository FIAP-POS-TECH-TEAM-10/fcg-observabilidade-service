#!/usr/bin/env bash
set -euo pipefail

: "${AWS_REGION:=sa-east-1}"
: "${IMAGE_TAG:=1.0.0}"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
REGISTRY="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

auto_login() {
  aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$REGISTRY"
}

auto_login

docker build -t fcg-prometheus:"$IMAGE_TAG" ./prometheus
docker tag fcg-prometheus:"$IMAGE_TAG" "$REGISTRY/fcg-prometheus:$IMAGE_TAG"
docker push "$REGISTRY/fcg-prometheus:$IMAGE_TAG"

docker build -t fcg-grafana:"$IMAGE_TAG" ./grafana
docker tag fcg-grafana:"$IMAGE_TAG" "$REGISTRY/fcg-grafana:$IMAGE_TAG"
docker push "$REGISTRY/fcg-grafana:$IMAGE_TAG"

echo "Imagens enviadas para: $REGISTRY"
