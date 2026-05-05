#!/usr/bin/env bash
# =============================================================================
# Start Smart Redact HITL Web UI
# =============================================================================
set -euo pipefail

VERSION="${VERSION:-latest}"
NETWORK="smart-redact-network"
HITL_WEB_PORT="${HITL_WEB_PORT:-3000}"
HITL_ORCHESTRATOR_URL="${HITL_ORCHESTRATOR_URL:-http://localhost:9983}"

docker network inspect "$NETWORK" >/dev/null 2>&1 || \
  docker network create "$NETWORK"

echo "Starting Smart Redact HITL Web UI..."
docker run -d \
  --name smart-redact-hitl-web \
  --network "$NETWORK" \
  --restart unless-stopped \
  -p "${HITL_WEB_PORT}:8080" \
  -e "ORCHESTRATOR_HOST=smart-redact-orchestrator" \
  -e "VITE_API_URL=${HITL_ORCHESTRATOR_URL}" \
  --health-cmd 'wget -qO- http://127.0.0.1:8080/ > /dev/null || exit 1' \
  --health-interval 10s \
  --health-timeout 10s \
  --health-start-period 20s \
  --health-retries 12 \
  "pdftoolsag/smart-redact-hitl-web:${VERSION}"

echo "HITL Web UI started at http://localhost:${HITL_WEB_PORT}"
