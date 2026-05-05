#!/usr/bin/env bash
# =============================================================================
# Start PostgreSQL databases for Smart Redact
# =============================================================================
set -euo pipefail

NETWORK="smart-redact-network"

# Create network if it doesn't exist
docker network inspect "$NETWORK" >/dev/null 2>&1 || \
  docker network create "$NETWORK"

echo "Starting Manager database..."
docker run -d \
  --name smart-redact-manager-db \
  --network "$NETWORK" \
  --restart unless-stopped \
  -e POSTGRES_USER=smartredact \
  -e POSTGRES_PASSWORD=smartredact \
  -e POSTGRES_DB=smartredact \
  -e TZ=UTC \
  -v smart-redact-pgdata-manager:/var/lib/postgresql/data \
  --health-cmd "pg_isready -U smartredact" \
  --health-interval 5s \
  --health-timeout 5s \
  --health-retries 5 \
  postgres:15-alpine

echo "Starting Orchestrator database..."
docker run -d \
  --name smart-redact-orchestrator-db \
  --network "$NETWORK" \
  --restart unless-stopped \
  -e POSTGRES_USER=smartredact \
  -e POSTGRES_PASSWORD=smartredact \
  -e POSTGRES_DB=smartredact \
  -e TZ=UTC \
  -v smart-redact-pgdata-orchestrator:/var/lib/postgresql/data \
  --health-cmd "pg_isready -U smartredact" \
  --health-interval 5s \
  --health-timeout 5s \
  --health-retries 5 \
  postgres:15-alpine

echo "Databases started. Waiting for health checks..."
until docker inspect --format='{{.State.Health.Status}}' smart-redact-manager-db 2>/dev/null | grep -q healthy; do sleep 1; done
until docker inspect --format='{{.State.Health.Status}}' smart-redact-orchestrator-db 2>/dev/null | grep -q healthy; do sleep 1; done
echo "Databases are ready."
