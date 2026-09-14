#!/usr/bin/env bash
set -euo pipefail

: "${AWS_REGION:=sa-east-1}"
: "${CLUSTER_NAME:=fcgames-cluster}"

for file in ecs/prometheus-service.json ecs/grafana-service.json; do
  tmp="$(mktemp)"
  sed \
    -e "s|<PRIVATE_SUBNET_ID_1>|$PRIVATE_SUBNET_ID_1|g" \
    -e "s|<PRIVATE_SUBNET_ID_2>|$PRIVATE_SUBNET_ID_2|g" \
    -e "s|<SG_OBSERVABILITY_ID>|$SG_OBSERVABILITY_ID|g" \
    -e "s|fcgames-cluster|$CLUSTER_NAME|g" \
    "$file" > "$tmp"

  aws ecs create-service \
    --cli-input-json "file://$tmp" \
    --region "$AWS_REGION"

  rm -f "$tmp"
done
