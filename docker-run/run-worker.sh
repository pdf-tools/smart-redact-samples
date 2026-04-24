#!/usr/bin/env bash
# =============================================================================
# Start Smart Redact Worker (CPU)
# =============================================================================
set -euo pipefail

: "${PII_SERVICE_LICENSE_KEY:?Error: PII_SERVICE_LICENSE_KEY is not set}"
: "${ENCRYPTION_KEY:?Error: ENCRYPTION_KEY is not set}"

VERSION="${VERSION:-0.99.0}"
NETWORK="smart-redact-network"

docker network inspect "$NETWORK" >/dev/null 2>&1 || \
  docker network create "$NETWORK"

echo "Starting Smart Redact Worker (CPU)..."
docker run -d \
  --name smart-redact-worker \
  --network "$NETWORK" \
  --restart unless-stopped \
  -e "Licensing__LicenseKey=${PII_SERVICE_LICENSE_KEY}" \
  -e "Encryption__EncryptionKey=${ENCRYPTION_KEY}" \
  -e "Encryption__DekTokenTtlMinutes=1440" \
  -e "FileStorage__FileStorageType=HostFileSystem" \
  -e "FileStorage__FilesDirectoryPath=/app/storage_folder" \
  -e "OTEL_EXPORTER_OTLP_ENDPOINT=${OTEL_EXPORTER_OTLP_ENDPOINT:-}" \
  -e "OTEL_EXPORTER_OTLP_PROTOCOL=${OTEL_EXPORTER_OTLP_PROTOCOL:-}" \
  -v smart-redact-storage:/app/storage_folder \
  -v smart-redact-logs:/app/logs \
  --health-cmd "curl -f http://localhost:4885/healthz/ready || exit 1" \
  --health-interval 10s \
  --health-timeout 30s \
  --health-start-period 60s \
  --health-retries 30 \
  "pdftoolsag/smart-redact-worker:${VERSION}"

echo "Worker started."
echo "Inspect container health with: docker inspect --format='{{.State.Health.Status}}' smart-redact-worker"
