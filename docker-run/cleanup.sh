#!/usr/bin/env bash
# =============================================================================
# Clean up Smart Redact containers, volumes, and network
# =============================================================================
# Usage:
#   ./cleanup.sh           # remove containers and network (keep data)
#   ./cleanup.sh --all     # also remove volumes (DELETES ALL DATA)
# =============================================================================
set -euo pipefail

CONTAINERS=(
  smart-redact-manager
  smart-redact-worker
  smart-redact-orchestrator
  smart-redact-hitl-web
  smart-redact-manager-db
  smart-redact-orchestrator-db
)

VOLUMES=(
  smart-redact-storage
  smart-redact-logs
  smart-redact-pgdata-manager
  smart-redact-pgdata-orchestrator
)

NETWORK="smart-redact-network"

echo "Stopping and removing Smart Redact containers..."
for container in "${CONTAINERS[@]}"; do
  if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
    docker stop "$container" 2>/dev/null || true
    docker rm "$container" 2>/dev/null || true
    echo "  Removed: $container"
  fi
done

if [ "${1:-}" = "--all" ]; then
  echo ""
  echo "Removing volumes (ALL DATA WILL BE LOST)..."
  for volume in "${VOLUMES[@]}"; do
    if docker volume ls --format '{{.Name}}' | grep -q "^${volume}$"; then
      docker volume rm "$volume" 2>/dev/null || true
      echo "  Removed: $volume"
    fi
  done
fi

echo ""
echo "Removing network..."
docker network rm "$NETWORK" 2>/dev/null || true

echo ""
echo "Cleanup complete."
