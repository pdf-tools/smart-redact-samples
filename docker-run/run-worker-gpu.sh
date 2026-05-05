#!/usr/bin/env bash
# =============================================================================
# Start Smart Redact Worker (GPU / NVIDIA CUDA)
# =============================================================================
# Requirements:
#   - NVIDIA GPU
#   - NVIDIA Container Toolkit installed
# =============================================================================
set -euo pipefail

: "${PDFTOOLS_LICENSE_KEY:?Error: PDFTOOLS_LICENSE_KEY is not set}"
: "${ENCRYPTION_KEY:?Error: ENCRYPTION_KEY is not set}"

VERSION="${VERSION:-latest}"
NETWORK="smart-redact-network"

docker network inspect "$NETWORK" >/dev/null 2>&1 || \
  docker network create "$NETWORK"

echo "Starting Smart Redact Worker (GPU)..."
docker run -d \
  --name smart-redact-worker \
  --network "$NETWORK" \
  --restart unless-stopped \
  --gpus all \
  -e "ServiceCommunication__ServiceCommunicationType=RabbitMQ" \
  -e "ServiceCommunication__Host=smart-redact-rabbitmq" \
  -e "ServiceCommunication__Username=guest" \
  -e "ServiceCommunication__Password=guest" \
  -e "Licensing__LicenseKey=${PDFTOOLS_LICENSE_KEY}" \
  -e "Encryption__EncryptionKey=${ENCRYPTION_KEY}" \
  -e "Encryption__DekTokenTtlMinutes=1440" \
  -e "FileStorage__FileStorageType=HostFileSystem" \
  -e "FileStorage__FilesDirectoryPath=/app/storage_folder" \
  -e "Inference__ExecutionProvider=Auto" \
  -e "NVIDIA_VISIBLE_DEVICES=all" \
  -e "NVIDIA_DRIVER_CAPABILITIES=compute,utility" \
  -v smart-redact-storage:/app/storage_folder \
  -v smart-redact-logs:/app/logs \
  --health-cmd "curl -f http://localhost:4885/healthz/ready || exit 1" \
  --health-interval 10s \
  --health-timeout 30s \
  --health-start-period 60s \
  --health-retries 30 \
  "pdftoolsag/smart-redact-worker:${VERSION}-cuda"

echo "Worker (GPU) started."
echo "Inspect container health with: docker inspect --format='{{.State.Health.Status}}' smart-redact-worker"
