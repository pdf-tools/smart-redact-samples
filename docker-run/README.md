# Docker Run Scripts

Individual `docker run` scripts for each Smart Redact service. Use these when you need full control over each container, or when Docker Compose is not available.

> For most use cases, [Docker Compose](../docker-compose/) is the easier option.

## Prerequisites

1. Create a Docker network:
   ```bash
   docker network create smart-redact-network
   ```

2. Set required environment variables:
   ```bash
   export PII_SERVICE_LICENSE_KEY="<your-license-key>"
   export ENCRYPTION_KEY=$(../scripts/generate-encryption-key.sh)
   export ORCHESTRATOR_JWT_SECRET=$(openssl rand -base64 64 | tr -d '\n')
   ```

## Usage

### Start all services at once

```bash
./run-all.sh
```

### Start services individually (in order)

```bash
# 1. Initialize shared volumes (chowns to app user UID/GID 1654)
./run-storage-init.sh

# 2. Databases
./run-postgres.sh

# 3. Worker (wait until healthy before starting Manager)
./run-worker.sh          # CPU
# ./run-worker-gpu.sh    # or GPU variant

# Inspect worker health - wait until it reports "healthy"
docker inspect --format='{{.State.Health.Status}}' smart-redact-worker

# 4. Manager (depends on Manager DB and Worker)
./run-manager.sh

# 5. Orchestrator (depends on Orchestrator DB and Manager)
./run-orchestrator.sh
```

## Stopping Services

```bash
docker stop smart-redact-manager smart-redact-worker smart-redact-orchestrator \
           smart-redact-manager-db smart-redact-orchestrator-db

docker rm smart-redact-manager smart-redact-worker smart-redact-orchestrator \
         smart-redact-manager-db smart-redact-orchestrator-db
```

Or use the cleanup script (covers docker-run naming only):
```bash
./cleanup.sh          # remove containers + network (keep volumes)
./cleanup.sh --all    # also remove volumes (DELETES ALL DATA)
```

> For Docker Compose deployments, use `docker compose down` (optionally `-v`) instead.
