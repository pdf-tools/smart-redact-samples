#!/usr/bin/env bash
# =============================================================================
# Start all Smart Redact services (CPU mode)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

: "${PDFTOOLS_LICENSE_KEY:?Error: PDFTOOLS_LICENSE_KEY is not set}"
: "${ENCRYPTION_KEY:?Error: ENCRYPTION_KEY is not set}"
: "${ORCHESTRATOR_JWT_SECRET:?Error: ORCHESTRATOR_JWT_SECRET is not set}"

echo "=== Starting Smart Redact ==="
echo ""

echo "[1/6] Initializing shared volumes..."
"${SCRIPT_DIR}/run-storage-init.sh"
echo ""

echo "[2/6] Starting databases..."
"${SCRIPT_DIR}/run-postgres.sh"
echo ""

echo "[3/6] Starting Worker..."
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

echo "[4/6] Starting Manager..."
"${SCRIPT_DIR}/run-manager.sh"
echo ""

echo "[5/6] Starting Orchestrator..."
"${SCRIPT_DIR}/run-orchestrator.sh"
echo ""

echo "[6/6] Starting HITL Web UI..."
"${SCRIPT_DIR}/run-hitl-web.sh"
echo ""

echo "=== All services started ==="
echo ""
echo "Waiting for services to become ready..."
"${SCRIPT_DIR}/wait-for-services.sh"
echo ""
echo "Services:"
echo "  Manager API:      http://localhost:9982/swagger"
echo "  Orchestrator API: http://localhost:9983/swagger"
echo "  HITL Web UI:      http://localhost:${HITL_WEB_PORT:-3000}"
echo ""
echo "Default HITL / Orchestrator login: admin@example.com / Admin@1234!Tmp"
