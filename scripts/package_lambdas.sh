#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
SRC_DIR="$ROOT_DIR/src/lambdas"
DIST_DIR="$ROOT_DIR/.dist"

ARTIFACTS_BUCKET="${ARTIFACTS_BUCKET:-}"
if [[ -z "$ARTIFACTS_BUCKET" ]]; then
  echo "ERROR: ARTIFACTS_BUCKET env var not set."
  echo "Usage: ARTIFACTS_BUCKET=my-bucket ./scripts/package_lambdas.sh"
  exit 1
fi

mkdir -p "$DIST_DIR"

LAMBDAS=(
  data_ingestion
  sentiment_analysis
  trending_topics
  engagement_scoring
  content_classification
  author_profiling
  api_handler
)

for lambda in "${LAMBDAS[@]}"; do
  echo "Packaging: $lambda"
  LAMBDA_DIR="$SRC_DIR/$lambda"
  ZIP_FILE="$DIST_DIR/${lambda}.zip"
  TMP_DIR=$(mktemp -d)

  pip install -r "$LAMBDA_DIR/requirements.txt" \
    --target "$TMP_DIR/python" --quiet --no-cache-dir

  cp "$LAMBDA_DIR/handler.py" "$TMP_DIR/"
  (cd "$TMP_DIR" && zip -r "$ZIP_FILE" . -x "*.pyc" -x "*/__pycache__/*" > /dev/null)
  rm -rf "$TMP_DIR"

  S3_KEY="lambda/${lambda}/${lambda}-$(md5sum "$ZIP_FILE" | cut -d' ' -f1).zip"
  aws s3 cp "$ZIP_FILE" "s3://$ARTIFACTS_BUCKET/$S3_KEY" --quiet
  echo "Uploaded → s3://$ARTIFACTS_BUCKET/$S3_KEY"
done

echo "All Lambdas packaged and uploaded."
