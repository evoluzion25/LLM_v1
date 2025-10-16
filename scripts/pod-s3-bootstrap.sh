#!/usr/bin/env bash
set -euo pipefail

SYNC_PATH=${SYNC_PATH:-/workspace}
S3_BUCKET=${S3_BUCKET:-}
S3_PREFIX=${S3_PREFIX:-backup}
S3_REGION=${S3_REGION:-us-east-1}
S3_ENDPOINT=${S3_ENDPOINT:-}
AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:-}
AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY:-}
INTERVAL_SEC=${INTERVAL_SEC:-600}

if [[ -z "$S3_BUCKET" || -z "$AWS_ACCESS_KEY_ID" || -z "$AWS_SECRET_ACCESS_KEY" ]]; then
  echo "Missing S3 config. Required: S3_BUCKET, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY" >&2
  exit 2
fi

# Install awscli if missing
if ! command -v aws >/dev/null 2>&1; then
  echo "Installing awscli via pip..."
  python3 -m pip install --no-cache-dir awscli >/dev/null
fi

# Configure env for aws
export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION=$S3_REGION

# Optional custom endpoint (e.g., R2, MinIO)
ENDPOINT_ARGS=()
if [[ -n "$S3_ENDPOINT" ]]; then
  ENDPOINT_ARGS=("--endpoint-url" "$S3_ENDPOINT")
fi

while true; do
  echo "[S3-SYNC] $(date -Iseconds) syncing $SYNC_PATH to s3://$S3_BUCKET/$S3_PREFIX/"
  aws s3 sync "$SYNC_PATH" "s3://$S3_BUCKET/$S3_PREFIX/" --delete "${ENDPOINT_ARGS[@]}" || true
  sleep "$INTERVAL_SEC"
done
