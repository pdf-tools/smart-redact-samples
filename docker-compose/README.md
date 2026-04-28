# Docker Compose Deployments

Three Docker Compose configurations for different use cases.

> For detailed configuration options, see [Smart Redact Configuration Guide](SMART_REDACT_DOCS_URL/configuration).

## Variants

### CPU (Full Stack)

All services with CPU-based inference. Best for evaluation, development, and environments without a GPU.

```bash
cd cpu
cp .env.example .env
# Edit .env with your license key and generated secrets
docker compose up -d
```

**Services started:** Manager (9982), Worker (4885), Orchestrator (9983), HITL Web UI (3000), 2x PostgreSQL

### GPU (Full Stack)

All services with GPU-accelerated inference using NVIDIA CUDA. Best for production workloads.

**Requirements:**
- NVIDIA GPU
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) installed

```bash
cd gpu
cp .env.example .env
# Edit .env with your license key and generated secrets
docker compose up -d
```

**Services started:** Manager (9982), Worker/GPU (4885), Orchestrator (9983), HITL Web UI (3000), 2x PostgreSQL

### Minimal (API Only)

Manager and Worker only, without the Orchestrator or HITL Web UI. Use this if you only need the REST API and don't need the Web UI or user management features.

```bash
cd minimal
cp .env.example .env
# Edit .env with your license key and generated secrets
docker compose up -d
```

**Services started:** Manager (9982), Worker (4885), 1x PostgreSQL

## Required Environment Variables

| Variable | How to generate | Description |
|----------|----------------|-------------|
| `PII_SERVICE_LICENSE_KEY` | From your [PDF Tools account](SMART_REDACT_DOCS_URL/licensing) | License key |
| `ENCRYPTION_KEY` | `../../scripts/generate-encryption-key.sh` | AES-256-GCM file encryption key |
| `ORCHESTRATOR_JWT_SECRET` | `openssl rand -base64 64 \| tr -d '\n'` | JWT signing secret (not needed for minimal) |

If the Docker Hub images are private, run `docker login` with an account that can pull from `pdftoolsag` before starting the stack.

## HITL Web UI

The CPU and GPU full-stack variants start the human-in-the-loop review UI at `http://localhost:3000`.

| Variable | Default | Description |
|----------|---------|-------------|
| `HITL_WEB_PORT` | `3000` | Host port mapped to the HITL Web UI container |
| `HITL_ORCHESTRATOR_URL` | `http://localhost:9983` | Browser-facing Orchestrator API URL |
| `HITL_MANAGER_URL` | `http://localhost:9982` | Browser-facing Manager API URL |

When the stack is exposed through a remote host or reverse proxy, set the two URL variables to the externally reachable API URLs.

> **Note:** The provided `docker-compose.yml` files hardcode the PostgreSQL password as `smartredact` for local demonstration only. For any non-local deployment, replace it with a strong, per-environment value (e.g. `openssl rand -base64 32 | tr -d '=+/' | head -c 32`) and inject it via your secret store rather than committing it.

## Verifying the Deployment

```bash
# Full stack (Manager + Worker + Orchestrator)
../../scripts/health-check.sh

# Minimal stack (Manager + internal Worker)
CHECK_ORCHESTRATOR=0 ../../scripts/health-check.sh

# Or check individually
curl -s http://localhost:9982/healthz/ready    # Manager
curl -s http://localhost:9983/healthz/ready    # Orchestrator
```

Open `http://localhost:3000` to use the HITL Web UI.

The Worker API is internal-only in the provided Docker Compose files.
`health-check.sh` verifies the Worker via Docker container health by default, and only uses `WORKER_URL` directly if you intentionally expose port `4885`.

## Stopping Services

```bash
# Stop and remove containers (keeps data)
docker compose down

# Stop and remove containers AND data volumes
docker compose down -v
```
