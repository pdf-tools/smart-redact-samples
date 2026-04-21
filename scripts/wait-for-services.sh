#!/usr/bin/env bash
# =============================================================================
# Wait for Smart Redact services to become ready
# =============================================================================
# Usage:
#   ./wait-for-services.sh                               # default 5 minute timeout
#   ./wait-for-services.sh 120                           # custom timeout in seconds
#   CHECK_ORCHESTRATOR=0 ./wait-for-services.sh          # minimal deployment
#   CHECK_WORKER=1 WORKER_URL=http://localhost:4885 ./wait-for-services.sh
#   CHECK_WORKER=0 ./wait-for-services.sh                # skip worker verification explicitly
# =============================================================================
set -euo pipefail

TIMEOUT="${1:-300}"
INTERVAL=5

MANAGER_URL="${MANAGER_URL:-http://localhost:9982}"
WORKER_URL="${WORKER_URL:-http://localhost:4885}"
ORCHESTRATOR_URL="${ORCHESTRATOR_URL:-http://localhost:9983}"
WORKER_CONTAINER_NAME="${WORKER_CONTAINER_NAME:-smart-redact-worker}"
CHECK_MANAGER="${CHECK_MANAGER:-1}"
CHECK_WORKER="${CHECK_WORKER:-auto}"
CHECK_ORCHESTRATOR="${CHECK_ORCHESTRATOR:-1}"

validate_binary_toggle() {
  case "$1" in
    0|1) ;;
    *)
      echo "Error: toggle must be 0 or 1. Current value: $1"
      exit 1
      ;;
  esac
}

validate_worker_toggle() {
  case "$1" in
    0|1|auto) ;;
    *)
      echo "Error: CHECK_WORKER must be 0, 1, or auto. Current value: $1"
      exit 1
      ;;
  esac
}

http_health_status() {
  local url="$1"
  curl -s -o /dev/null -w "%{http_code}" "${url}/healthz/ready" 2>/dev/null || echo "000"
}

wait_for_http_service() {
  local name="$1"
  local url="$2"
  local elapsed=0

  while [ "$elapsed" -lt "$TIMEOUT" ]; do
    local status
    status=$(http_health_status "$url")
    if [ "$status" = "200" ]; then
      echo "  $name is ready. (${elapsed}s)"
      return 0
    fi
    sleep "$INTERVAL"
    elapsed=$((elapsed + INTERVAL))
  done

  echo "  $name did not become ready within ${TIMEOUT}s."
  return 1
}

get_worker_container_health() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "docker-unavailable"
    return 1
  fi

  local status
  status=$(docker inspect \
    --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' \
    "$WORKER_CONTAINER_NAME" 2>/dev/null || true)

  if [ -z "$status" ]; then
    echo "not-found"
    return 1
  fi

  echo "$status"
}

wait_for_worker_service() {
  local elapsed=0

  while [ "$elapsed" -lt "$TIMEOUT" ]; do
    if [ "$CHECK_WORKER" = "1" ]; then
      local explicit_status
      explicit_status=$(http_health_status "$WORKER_URL")
      if [ "$explicit_status" = "200" ]; then
        echo "  Worker        is ready via ${WORKER_URL}. (${elapsed}s)"
        return 0
      fi
    else
      local host_status
      host_status=$(http_health_status "$WORKER_URL")
      if [ "$host_status" = "200" ]; then
        echo "  Worker        is ready via ${WORKER_URL}. (${elapsed}s)"
        return 0
      fi

      local container_status
      container_status=$(get_worker_container_health)
      if [ "$container_status" = "healthy" ]; then
        echo "  Worker        is ready via container ${WORKER_CONTAINER_NAME}. (${elapsed}s)"
        return 0
      fi
    fi

    sleep "$INTERVAL"
    elapsed=$((elapsed + INTERVAL))
  done

  echo "  Worker        did not become ready within ${TIMEOUT}s."
  return 1
}

validate_binary_toggle "$CHECK_MANAGER"
validate_binary_toggle "$CHECK_ORCHESTRATOR"
validate_worker_toggle "$CHECK_WORKER"

echo "Waiting for Smart Redact services (timeout: ${TIMEOUT}s)..."
echo ""

failed=0
checked=0

if [ "$CHECK_MANAGER" = "1" ]; then
  checked=$((checked + 1))
  wait_for_http_service "Manager      " "$MANAGER_URL" || failed=$((failed + 1))
fi

if [ "$CHECK_WORKER" != "0" ]; then
  checked=$((checked + 1))
  wait_for_worker_service || failed=$((failed + 1))
fi

if [ "$CHECK_ORCHESTRATOR" = "1" ]; then
  checked=$((checked + 1))
  wait_for_http_service "Orchestrator " "$ORCHESTRATOR_URL" || failed=$((failed + 1))
fi

echo ""
if [ "$checked" -eq 0 ]; then
  echo "No services selected to wait for."
  exit 1
elif [ "$failed" -eq 0 ]; then
  echo "All selected services are ready."
else
  echo "$failed service(s) failed to start. Check logs with: docker compose logs"
  exit 1
fi
