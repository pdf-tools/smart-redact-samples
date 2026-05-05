# Docker Compose Deployments

Three Docker Compose configurations for different use cases.

> For detailed configuration options, see [Smart Redact Configuration Guide](https://www.pdf-tools.com/docs/smart-redact/configuration).

## Variants

From this directory, use the root helper script:

```bash
../smart-redact.sh setup --license-key "<RDCTSRV,...>"
../smart-redact.sh up
../smart-redact.sh health
```

It creates the `.env` file, generates required secrets, and starts Compose with Docker's native health/wait support.

### CPU (Full Stack)

All services with CPU-based inference. Best for evaluation, development, and environments without a GPU.

```bash
cd cpu
cp .env.example .env
# Edit .env with your license key and generated secrets
docker compose up -d --wait
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
docker compose up -d --wait
```

**Services started:** Manager (9982), Worker/GPU (4885), Orchestrator (9983), HITL Web UI (3000), 2x PostgreSQL

### Minimal (API Only)

Manager and Worker only, without the Orchestrator or HITL Web UI. Use this if you only need the REST API and don't need the Web UI or user management features.

```bash
cd minimal
cp .env.example .env
# Edit .env with your license key and generated secrets
docker compose up -d --wait
```

**Services started:** Manager (9982), Worker (4885), 1x PostgreSQL

## Required Environment Variables

| Variable | How to generate | Description |
|----------|----------------|-------------|
| `PDFTOOLS_LICENSE_KEY` | From your [PDF Tools account](https://www.pdf-tools.com/docs/smart-redact/licensing) | License key |
| `ENCRYPTION_KEY` | `../../scripts/generate-encryption-key.sh` | AES-256-GCM file encryption key |
| `ORCHESTRATOR_JWT_SECRET` | `openssl rand -base64 64 \| tr -d '\n'` | JWT signing secret (not needed for minimal) |

If the Docker Hub images are private, run `docker login` with an account that can pull from `pdftoolsag` before starting the stack.

## HITL Web UI

The CPU and GPU full-stack variants start the human-in-the-loop review UI at `http://localhost:3000`.

| Variable | Default | Description |
|----------|---------|-------------|
| `HITL_WEB_PORT` | `3000` | Host port mapped to the HITL Web UI container |
| `HITL_ORCHESTRATOR_URL` | `http://localhost:9983` | Browser-facing Orchestrator API URL |

When the stack is exposed through a remote host or reverse proxy, set `HITL_ORCHESTRATOR_URL` to the externally reachable Orchestrator URL. The HITL Web UI talks to the Manager only indirectly, through the Orchestrator.

> **Note:** The provided `docker-compose.yml` files hardcode default credentials for local demonstration only:
> - PostgreSQL: user/password `smartredact` / `smartredact`
> - RabbitMQ: user/password `guest` / `guest`
>
> For any non-local deployment, replace these with strong values.

## Verifying the Deployment

```bash
# Show Compose-managed service status
../smart-redact.sh status

# Same Compose status view, kept as a familiar lifecycle command
../smart-redact.sh health
```

Open `http://localhost:3000` to use the HITL Web UI.

The Worker API is internal-only in the provided Docker Compose files.
Compose readiness is driven by service `healthcheck` and `depends_on` conditions, including the internal Worker health check.

## Stopping Services

```bash
# Stop and remove containers (keeps data)
docker compose down

# Stop and remove containers AND data volumes
docker compose down -v
```
