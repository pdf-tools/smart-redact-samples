#!/usr/bin/env bash
# =============================================================================
# Start Smart Redact Manager
# =============================================================================
set -euo pipefail

: "${PII_SERVICE_LICENSE_KEY:?Error: PII_SERVICE_LICENSE_KEY is not set}"
: "${ENCRYPTION_KEY:?Error: ENCRYPTION_KEY is not set}"

VERSION="${VERSION:-latest}"
NETWORK="smart-redact-network"

docker network inspect "$NETWORK" >/dev/null 2>&1 || \
  docker network create "$NETWORK"

echo "Starting Smart Redact Manager..."
docker run -d \
  --name smart-redact-manager \
  --network "$NETWORK" \
  --restart unless-stopped \
  -p 9982:9982 \
  -e "ServiceCommunication__ConnectionString=http://smart-redact-worker:4885/" \
  -e "Database__DatabaseType=PostgreSql" \
  -e "Database__ConnectionString=User ID=smartredact;Password=smartredact;Server=smart-redact-manager-db;Port=5432;Database=smartredact;Maximum Pool Size=50;Timeout=30;" \
  -e "FileStorage__FileStorageType=HostFileSystem" \
  -e "FileStorage__FilesDirectoryPath=/app/storage_folder" \
  -e "Encryption__EncryptionKey=${ENCRYPTION_KEY}" \
  -e "Encryption__DekTokenTtlMinutes=1440" \
  -e "Licensing__LicenseKey=${PII_SERVICE_LICENSE_KEY}" \
  -v smart-redact-storage:/app/storage_folder \
  -v smart-redact-logs:/app/logs \
  --health-cmd "curl -f http://localhost:9982/healthz/ready || exit 1" \
  --health-interval 10s \
  --health-timeout 15s \
  --health-start-period 30s \
  --health-retries 30 \
  "pdftoolsag/smart-redact-manager:${VERSION}"

echo "Manager started at http://localhost:9982"
echo "Swagger UI: http://localhost:9982/swagger"
