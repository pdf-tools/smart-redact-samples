#!/usr/bin/env bash
# =============================================================================
# Start RabbitMQ broker for Smart Redact Manager <-> Worker communication
# =============================================================================
set -euo pipefail

NETWORK="smart-redact-network"

docker network inspect "$NETWORK" >/dev/null 2>&1 || \
  docker network create "$NETWORK"

echo "Starting RabbitMQ..."
docker run -d \
  --name smart-redact-rabbitmq \
  --network "$NETWORK" \
  --restart unless-stopped \
  -e RABBITMQ_DEFAULT_USER=guest \
  -e RABBITMQ_DEFAULT_PASS=guest \
  --health-cmd "rabbitmq-diagnostics -q check_port_connectivity" \
  --health-interval 10s \
  --health-timeout 10s \
  --health-start-period 30s \
  --health-retries 5 \
  rabbitmq:4-management-alpine

echo "RabbitMQ started. Waiting for health check..."
until docker inspect --format='{{.State.Health.Status}}' smart-redact-rabbitmq 2>/dev/null | grep -q healthy; do sleep 1; done
echo "RabbitMQ is ready."
