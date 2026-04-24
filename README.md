# Pdftools Smart Redact - Samples Repository

Sample configurations and examples for deploying and using [Smart Redact](SMART_REDACT_DOCS_URL) by Pdftools.

Smart Redact automatically detects and redacts personally identifiable information (PII) in PDF documents using pattern matching, keyword detection, and ML-based named entity recognition (GLiNER).

## Architecture

Smart Redact consists of four services:

```
                          ┌─────────────────────┐
                          │   Orchestrator API   │
                          │     (port 9983)      │
                          │  User management,    │
                          │  JWT auth, Web UI    │
                          │  backend             │
                          └──────────┬───────────┘
                                     │ HTTP
                          ┌──────────▲───────────┐
                          │      HITL Web UI      │
                          │      (port 3000)      │
                          │ Human review workflow │
                          └──────────────────────┘
                                     │ HTTP
┌──────────┐    HTTP     ┌───────────▼───────────┐    HTTP     ┌────────────────────┐
│  Client   ├───────────►│     Manager API       ├───────────►│    Worker API       │
│           │            │     (port 9982)       │            │    (port 4885)      │
│           │            │  Files, Jobs,         │            │  PII Detection,     │
│           │            │  Orchestration        │            │  Redaction,         │
│           │            │                       │            │  GLiNER ML Model    │
└──────────┘            └───────────┬───────────┘            └────────────────────┘
                                     │
                          ┌──────────▼───────────┐
                          │    PostgreSQL (x2)    │
                          │  Manager DB           │
                          │  Orchestrator DB      │
                          └──────────────────────┘
```

| Service | Port | Description |
|---------|------|-------------|
| **Manager** | 9982 | Client-facing API for file uploads and detection/redaction jobs |
| **Worker** | 4885 | Internal service that performs PII detection and redaction |
| **Orchestrator** | 9983 | Web UI backend with user management and JWT authentication |
| **HITL Web UI** | 3000 | Human-in-the-loop review interface for detection results and redaction jobs |

> For detailed architecture documentation, see [Smart Redact Architecture](SMART_REDACT_DOCS_URL/architecture).

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) and [Docker Compose](https://docs.docker.com/compose/install/) v2+
- A valid Smart Redact license key ([get one here](SMART_REDACT_DOCS_URL/licensing))
- Docker Hub access to the `pdftoolsag` images. If the images are private, run `docker login` before `docker compose up` or `docker run`.
- For GPU acceleration: NVIDIA GPU with [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)

## Windows Users

All shell scripts in this repository (`scripts/*.sh`, `docker-run/*.sh`, `api-examples/curl/*.sh`) are bash-based. On Windows, use one of:

- **WSL2** (recommended) — full Linux environment. Docker Desktop integrates with WSL2 natively, so `docker` commands just work.
- **Git Bash** — bundled with [Git for Windows](https://git-scm.com/download/win). Sufficient for all Docker-based scripts in this repo, provided Docker Desktop is running and `python3` is available on `PATH` (needed by the curl API examples).

A PowerShell equivalent is provided for the one script that runs before Docker is involved:

```powershell
# From PowerShell:
.\scripts\generate-encryption-key.ps1
```

All other scripts should be executed from WSL2 or Git Bash.

## Quick Start

The fastest way to get Smart Redact running:

```bash
# 1. Clone this repository
git clone https://github.com/pdf-tools/smart-redact-samples.git
cd smart-redact-samples

# 2. Create your .env file
cp docker-compose/cpu/.env.example docker-compose/cpu/.env

# 3. Fill in required values using the editor of your choice.
#    - PII_SERVICE_LICENSE_KEY: your license key
#    - ENCRYPTION_KEY: generate with ./scripts/generate-encryption-key.sh
#    - ORCHESTRATOR_JWT_SECRET: generate with: openssl rand -base64 64 | tr -d '\n'
vim docker-compose/cpu/.env

# 4. Start all services
cd docker-compose/cpu
docker compose up -d

# 5. Wait for services to be ready
../../scripts/wait-for-services.sh

# 6. Verify
../../scripts/health-check.sh
```

Once running:
- **Manager API (Swagger):** http://localhost:9982/swagger
- **Orchestrator API (Swagger):** http://localhost:9983/swagger
- **HITL Web UI:** http://localhost:3000

Default HITL / Orchestrator login:
- **Username:** `admin`
- **Password:** `Admin1234`

## Repository Structure

```
smart-redact-samples/
├── docker-compose/          # Docker Compose deployments
│   ├── cpu/                 #   Full stack (CPU inference)
│   ├── gpu/                 #   Full stack (GPU inference, NVIDIA CUDA)
│   └── minimal/             #   Manager + Worker only (no Orchestrator)
│
├── docker-run/              # Individual docker run scripts
│
├── kubernetes/              # Kubernetes deployments
│   ├── helm/                #   Helm chart
│   └── plain-manifests/     #   Plain YAML + Kustomize
│
├── api-examples/            # API usage examples
│   ├── curl/                #   Shell scripts (step-by-step)
│   ├── python/              #   Python examples
│   └── postman/             #   Postman collections
│
├── opentelemetry/           # OpenTelemetry integration examples
│
└── scripts/                 # Utility scripts
```

## Deployment Options

| Option | Best For | Guide |
|--------|----------|-------|
| [Docker Compose (CPU)](docker-compose/cpu/) | Quick start, development, evaluation | [Guide](docker-compose/README.md) |
| [Docker Compose (GPU)](docker-compose/gpu/) | Production with GPU acceleration | [Guide](docker-compose/README.md) |
| [Docker Compose (Minimal)](docker-compose/minimal/) | API-only usage without Orchestrator | [Guide](docker-compose/README.md) |
| [Docker Run](docker-run/) | Manual control over each container | [Guide](docker-run/README.md) |
| [Kubernetes (Helm)](kubernetes/helm/) | Production Kubernetes clusters | [Guide](kubernetes/README.md) |
| [Kubernetes (Plain YAML)](kubernetes/plain-manifests/) | Kubernetes without Helm | [Guide](kubernetes/README.md) |

## API Examples

See [api-examples/](api-examples/) for complete usage examples including:
- Uploading PDF files
- Running PII detection
- Downloading detection results
- Running PII redaction
- End-to-end workflows

> For full API reference, see [Smart Redact API Documentation](SMART_REDACT_DOCS_URL/api-reference).

## Configuration Reference

All Smart Redact services are configured via environment variables:

| Variable | Required | Description |
|----------|----------|-------------|
| `PII_SERVICE_LICENSE_KEY` | Yes | Smart Redact license key |
| `ENCRYPTION_KEY` | Yes | 32-byte Base64-encoded AES-256-GCM key |
| `ORCHESTRATOR_JWT_SECRET` | Yes* | JWT signing secret (min 32 chars). *Only for Orchestrator. |
| `VERSION` | No | Docker image tag (default: `0.99.0`) |
| `HITL_WEB_PORT` | No | Host port for the HITL Web UI (default: `3000`) |
| `HITL_ORCHESTRATOR_URL` | No | Browser-facing Orchestrator API URL used by the HITL Web UI (default: `http://localhost:9983`) |
| `HITL_MANAGER_URL` | No | Browser-facing Manager API URL used by the HITL Web UI (default: `http://localhost:9982`) |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | No | OpenTelemetry collector endpoint |
| `OTEL_EXPORTER_OTLP_PROTOCOL` | No | OpenTelemetry protocol (`grpc` or `http/protobuf`) |

> For all configuration options, see [Smart Redact Configuration Guide](SMART_REDACT_DOCS_URL/configuration).

## Documentation

- [Smart Redact Documentation](SMART_REDACT_DOCS_URL)
- [Configuration Guide](SMART_REDACT_DOCS_URL/configuration)
- [API Reference](SMART_REDACT_DOCS_URL/api-reference)
- [Architecture](SMART_REDACT_DOCS_URL/architecture)
- [Licensing](SMART_REDACT_DOCS_URL/licensing)
- [Observability / OpenTelemetry](SMART_REDACT_DOCS_URL/observability)

## License

This repository contains sample configurations for Smart Redact, a commercial product by [PDF Tools AG](https://www.pdf-tools.com). A valid license key is required to run the service.
