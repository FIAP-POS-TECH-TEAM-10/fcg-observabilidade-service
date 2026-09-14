#!/usr/bin/env bash
set -euo pipefail

: "${AWS_REGION:=sa-east-1}"

for repo in fcg-prometheus fcg-grafana; do
  aws ecr describe-repositories --repository-names "$repo" --region "$AWS_REGION" >/dev/null 2>&1 || \
    aws ecr create-repository --repository-name "$repo" --region "$AWS_REGION" >/dev/null
  echo "ECR pronto: $repo"
done
