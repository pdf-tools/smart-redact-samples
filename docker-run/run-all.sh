#!/usr/bin/env bash
# =============================================================================
# Start all Smart Redact services (CPU mode)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

: "${PII_SERVICE_LICENSE_KEY:?Error: PII_SERVICE_LICENSE_KEY is not set}"
: "${ENCRYPTION_KEY:?Error: ENCRYPTION_KEY is not set}"
: "${ORCHESTRATOR_JWT_SECRET:?Error: ORCHESTRATOR_JWT_SECRET is not set}"

echo "=== Starting Smart Redact ==="
echo ""

echo "[1/5] Initializing shared volumes..."
"${SCRIPT_DIR}/run-storage-init.sh"
echo ""

echo "[2/5] Starting databases..."
"${SCRIPT_DIR}/run-postgres.sh"
echo ""

echo "[3/5] Starting Worker..."
"${SCRIPT_DIR}/run-worker.sh"
echo "Waiting for Worker to become healthy..."
WORKER_HEALTH_TIMEOUT_SECONDS="${WORKER_HEALTH_TIMEOUT_SECONDS:-300}"
worker_wait_start=$(date +%s)
until docker inspect --format='{{.State.Health.Status}}' smart-redact-worker 2>/dev/null | grep -q healthy; do
  if (( $(date +%s) - worker_wait_start > WORKER_HEALTH_TIMEOUT_SECONDS )); then
    echo "Error: Worker did not become healthy within ${WORKER_HEALTH_TIMEOUT_SECONDS}s." >&2
    echo "Recent Worker logs:" >&2
    docker logs --tail 50 smart-redact-worker >&2 || true
    exit 1
  fi
  sleep 2
done
echo "Worker is ready."
echo ""

echo "[4/5] Starting Manager..."
"${SCRIPT_DIR}/run-manager.sh"
echo ""

echo "[5/5] Starting Orchestrator..."
"${SCRIPT_DIR}/run-orchestrator.sh"
echo ""

echo "=== All services started ==="
echo ""
echo "Waiting for services to become ready..."
"${SCRIPT_DIR}/../scripts/wait-for-services.sh"
echo ""
echo "Services:"
echo "  Manager API:      http://localhost:9982/swagger"
echo "  Orchestrator API: http://localhost:9983/swagger"
echo ""
echo "Default Orchestrator login: admin / Admin1234"
