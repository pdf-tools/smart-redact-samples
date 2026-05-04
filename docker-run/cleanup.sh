#!/usr/bin/env bash
# =============================================================================
# Clean up Smart Redact containers, volumes, network, and images
# =============================================================================
# Usage:
#   ./cleanup.sh                    # remove containers and network (keep data and images)
#   ./cleanup.sh --volumes          # also remove volumes (DELETES ALL DATA)
#   ./cleanup.sh --images           # also remove Smart Redact images
#   ./cleanup.sh --all              # remove volumes AND images (shorthand)
#
# Note: base images (postgres, alpine) are intentionally left in place since
# they are commonly shared with other projects and cheap to re-pull.
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

IMAGE_REPOS=(
  pdftoolsag/smart-redact-manager
  pdftoolsag/smart-redact-worker
  pdftoolsag/smart-redact-orchestrator
  pdftoolsag/smart-redact-hitl-web
)

NETWORK="smart-redact-network"

REMOVE_VOLUMES=0
REMOVE_IMAGES=0
for arg in "$@"; do
  case "$arg" in
    --volumes) REMOVE_VOLUMES=1 ;;
    --images) REMOVE_IMAGES=1 ;;
    --all)
      REMOVE_VOLUMES=1
      REMOVE_IMAGES=1
      ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

echo "Stopping and removing Smart Redact containers..."
for container in "${CONTAINERS[@]}"; do
  if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
    docker stop "$container" 2>/dev/null || true
    docker rm "$container" 2>/dev/null || true
    echo "  Removed: $container"
  fi
done

if [ "$REMOVE_VOLUMES" -eq 1 ]; then
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

if [ "$REMOVE_IMAGES" -eq 1 ]; then
  echo ""
  echo "Removing Smart Redact images..."
  removed=0
  for repo in "${IMAGE_REPOS[@]}"; do
    images="$(docker images --format '{{.Repository}}:{{.Tag}}' | grep "^${repo}:" || true)"
    [ -n "$images" ] || continue
    while IFS= read -r image; do
      [ -n "$image" ] || continue
      if docker rmi -f "$image" >/dev/null; then
        echo "  Removed: $image"
        removed=$((removed + 1))
      else
        echo "  Failed to remove: $image" >&2
      fi
    done <<< "$images"
  done
  if [ "$removed" -eq 0 ]; then
    echo "  No Smart Redact images found."
  else
    echo "  Removed ${removed} image(s)."
  fi
fi

echo ""
echo "Cleanup complete."
