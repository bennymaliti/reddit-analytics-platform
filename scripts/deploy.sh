#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TF_DIR="$ROOT_DIR/terraform"
ENVIRONMENT="${ENVIRONMENT:-prod}"
TFVARS_FILE="$TF_DIR/environments/$ENVIRONMENT/terraform.tfvars"

echo "Deploying Reddit Analytics Platform — $ENVIRONMENT"

for tool in aws terraform python3; do
  command -v $tool &>/dev/null || { echo "ERROR: $tool not installed."; exit 1; }
done

cd "$TF_DIR"
terraform init -backend-config="region=eu-west-2" -reconfigure
terraform plan -var-file="$TFVARS_FILE" -out="$TF_DIR/.tfplan" -compact-warnings
terraform apply "$TF_DIR/.tfplan"

echo "Deployment complete!"
terraform output
