#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TF_DIR="$ROOT_DIR/terraform"
ENVIRONMENT="${ENVIRONMENT:-prod}"
TFVARS_FILE="$TF_DIR/environments/$ENVIRONMENT/terraform.tfvars"

echo "WARNING: This will DESTROY all infrastructure for environment: $ENVIRONMENT"
read -rp "Type 'destroy' to confirm: " CONFIRM
[[ "$CONFIRM" != "destroy" ]] && { echo "Aborted."; exit 0; }

cd "$TF_DIR"
terraform destroy -var-file="$TFVARS_FILE" -auto-approve
echo "Teardown complete."
