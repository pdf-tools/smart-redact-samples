#!/usr/bin/env bash
# =============================================================================
# Start Smart Redact Orchestrator
# =============================================================================
set -euo pipefail

: "${PDFTOOLS_LICENSE_KEY:?Error: PDFTOOLS_LICENSE_KEY is not set}"
: "${ORCHESTRATOR_JWT_SECRET:?Error: ORCHESTRATOR_JWT_SECRET is not set}"

VERSION="${VERSION:-latest}"
NETWORK="smart-redact-network"

docker network inspect "$NETWORK" >/dev/null 2>&1 || \
  docker network create "$NETWORK"

echo "Starting Smart Redact Orchestrator..."
docker run -d \
  --name smart-redact-orchestrator \
  --network "$NETWORK" \
  --restart unless-stopped \
  -p 9983:9983 \
  -e "ManagerApi__BaseUrl=http://smart-redact-manager:9982/" \
  -e "ManagerApi__PollingIntervalSeconds=3" \
  -e "Database__DatabaseType=PostgreSql" \
  -e "Database__ConnectionString=User ID=smartredact;Password=smartredact;Server=smart-redact-orchestrator-db;Port=5432;Database=smartredact;Maximum Pool Size=50;Timeout=30;" \
  -e "Jwt__SecretKey=${ORCHESTRATOR_JWT_SECRET}" \
  -e "Licensing__LicenseKey=${PDFTOOLS_LICENSE_KEY}" \
  -v smart-redact-logs:/app/logs \
  --health-cmd "curl -f http://localhost:9983/healthz/ready || exit 1" \
  --health-interval 10s \
  --health-timeout 15s \
  --health-start-period 30s \
  --health-retries 30 \
  "pdftoolsag/smart-redact-orchestrator:${VERSION}"

echo "Orchestrator started at http://localhost:9983"
echo "Swagger UI: http://localhost:9983/swagger"
echo ""
echo "Default login: admin@example.com / Admin1234 (password reset required on first login)"
