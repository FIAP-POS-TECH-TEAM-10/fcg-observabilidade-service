#!/usr/bin/env bash
set -euo pipefail

: "${AWS_REGION:=sa-east-1}"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

sed \
  -e "s|<ACCOUNT_ID>|$ACCOUNT_ID|g" \
  -e "s|<AWS_REGION>|$AWS_REGION|g" \
  ecs/prometheus-task-definition.json > "$TMP_DIR/prometheus.json"

sed \
  -e "s|<ACCOUNT_ID>|$ACCOUNT_ID|g" \
  -e "s|<AWS_REGION>|$AWS_REGION|g" \
  -e "s|<GRAFANA_SECRET_NAME>|fcgames/grafana|g" \
  ecs/grafana-task-definition.json > "$TMP_DIR/grafana.json"

aws ecs register-task-definition --cli-input-json "file://$TMP_DIR/prometheus.json" --region "$AWS_REGION" >/tmp/fcg-prometheus-task.json
aws ecs register-task-definition --cli-input-json "file://$TMP_DIR/grafana.json" --region "$AWS_REGION" >/tmp/fcg-grafana-task.json

echo "Task definitions registradas."
