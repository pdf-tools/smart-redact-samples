#!/usr/bin/env bash
# =============================================================================
# Check health of Smart Redact services that are reachable from the host
# =============================================================================
# Usage:
#   ./health-check.sh                               # full Docker samples
#   CHECK_ORCHESTRATOR=0 ./health-check.sh          # minimal deployment
#   CHECK_WORKER=1 WORKER_URL=http://localhost:4885 ./health-check.sh
#   CHECK_WORKER=0 ./health-check.sh                # skip worker verification explicitly
# =============================================================================
set -euo pipefail

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

check_http_health() {
  local name="$1"
  local url="$2"

  local status
  status=$(http_health_status "$url")

  if [ "$status" = "200" ]; then
    echo "  $name: HEALTHY"
    return 0
  else
    echo "  $name: UNHEALTHY (HTTP $status)"
    return 1
  fi
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

check_worker_health() {
  if [ "$CHECK_WORKER" = "1" ]; then
    check_http_health "Worker       (${WORKER_URL})" "$WORKER_URL"
    return $?
  fi

  local http_status
  http_status=$(http_health_status "$WORKER_URL")
  if [ "$http_status" = "200" ]; then
    echo "  Worker       (${WORKER_URL}): HEALTHY"
    return 0
  fi

  local container_status
  container_status=$(get_worker_container_health)
  case "$container_status" in
    healthy)
      echo "  Worker       (container ${WORKER_CONTAINER_NAME}): HEALTHY"
      return 0
      ;;
    starting)
      echo "  Worker       (container ${WORKER_CONTAINER_NAME}): STARTING"
      return 1
      ;;
    unhealthy)
      echo "  Worker       (container ${WORKER_CONTAINER_NAME}): UNHEALTHY"
      return 1
      ;;
    running)
      echo "  Worker       (container ${WORKER_CONTAINER_NAME}): RUNNING (no health status)"
      return 1
      ;;
    docker-unavailable)
      echo "  Worker       (${WORKER_URL} / container ${WORKER_CONTAINER_NAME}): UNVERIFIED"
      echo "    Docker is unavailable and the Worker API is not reachable on the host."
      return 1
      ;;
    *)
      echo "  Worker       (${WORKER_URL} / container ${WORKER_CONTAINER_NAME}): UNVERIFIED"
      echo "    Expose port 4885 or keep the default container name for Docker-based verification."
      return 1
      ;;
  esac
}

validate_binary_toggle "$CHECK_MANAGER"
validate_binary_toggle "$CHECK_ORCHESTRATOR"
validate_worker_toggle "$CHECK_WORKER"

echo "Smart Redact Health Check"
echo "========================="
echo ""

failed=0
checked=0

if [ "$CHECK_MANAGER" = "1" ]; then
  checked=$((checked + 1))
  check_http_health "Manager      (${MANAGER_URL})" "$MANAGER_URL" || failed=$((failed + 1))
fi

if [ "$CHECK_WORKER" != "0" ]; then
  checked=$((checked + 1))
  check_worker_health || failed=$((failed + 1))
fi

if [ "$CHECK_ORCHESTRATOR" = "1" ]; then
  checked=$((checked + 1))
  check_http_health "Orchestrator (${ORCHESTRATOR_URL})" "$ORCHESTRATOR_URL" || failed=$((failed + 1))
fi

echo ""
if [ "$checked" -eq 0 ]; then
  echo "No services selected for health checking."
  exit 1
elif [ "$failed" -eq 0 ]; then
  echo "All selected services are healthy."
else
  echo "$failed service(s) unhealthy."
  exit 1
fi
