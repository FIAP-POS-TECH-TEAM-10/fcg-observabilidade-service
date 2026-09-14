#!/usr/bin/env bash
set -euo pipefail

: "${AWS_REGION:=sa-east-1}"
: "${CLUSTER_NAME:=fcgames-cluster}"
: "${NAMESPACE_NAME:=fcgames.local}"
: "${GRAFANA_SECRET_NAME:=fcgames/grafana}"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"

aws ecs create-cluster \
  --cluster-name "$CLUSTER_NAME" \
  --service-connect-defaults "namespace=$NAMESPACE_NAME" \
  >/tmp/fcgames-ecs-cluster.json

echo "Cluster criado: $CLUSTER_NAME"

echo "Namespace Service Connect: $NAMESPACE_NAME"

echo "Account: $ACCOUNT_ID"

echo

echo "Crie o secret do Grafana antes de criar o service:"
echo "aws secretsmanager create-secret --name '$GRAFANA_SECRET_NAME' --secret-string 'troque-esta-senha' --region '$AWS_REGION'"
