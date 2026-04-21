#!/usr/bin/env bash
# =============================================================================
# Initialize Smart Redact shared volumes
# =============================================================================
# Creates the smart-redact-storage and smart-redact-logs named volumes (if
# missing) and sets ownership to the non-root app user (UID/GID 1654) used
# by the Manager and Worker images. Run this BEFORE starting the Manager and
# Worker so that their first write does not fail with "Permission denied".
# =============================================================================
set -euo pipefail

echo "Initializing Smart Redact shared volumes..."
docker run --rm \
  --user 0:0 \
  -v smart-redact-storage:/app/storage_folder \
  -v smart-redact-logs:/app/logs \
  alpine:3 \
  sh -c "chown -R 1654:1654 /app/storage_folder /app/logs && chmod -R u+rwX,g+rwX /app/storage_folder /app/logs"

echo "Volumes initialized: smart-redact-storage, smart-redact-logs"
