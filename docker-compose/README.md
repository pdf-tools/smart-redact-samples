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

**Services started:** Manager (9982), Worker (4885), Orchestrator (9983), 2x PostgreSQL

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

**Services started:** Manager (9982), Worker/GPU (4885), Orchestrator (9983), 2x PostgreSQL

### Minimal (API Only)

Manager and Worker only, without the Orchestrator. Use this if you only need the REST API and don't need the Web UI or user management features.

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

The Worker API is internal-only in the provided Docker Compose files.
`health-check.sh` verifies the Worker via Docker container health by default, and only uses `WORKER_URL` directly if you intentionally expose port `4885`.

## Stopping Services

```bash
# Stop and remove containers (keeps data)
docker compose down

# Stop and remove containers AND data volumes
docker compose down -v
```

## Adding OpenTelemetry

To enable telemetry export, uncomment the OTEL variables in your `.env` file:

```bash
OTEL_EXPORTER_OTLP_ENDPOINT=http://your-otel-collector:4317
OTEL_EXPORTER_OTLP_PROTOCOL=grpc
```

See [opentelemetry/](../opentelemetry/) for collector configuration examples.
