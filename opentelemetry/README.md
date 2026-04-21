# OpenTelemetry Integration for Smart Redact

Smart Redact services export telemetry data via [OpenTelemetry](https://opentelemetry.io/) (OTel), giving you full observability into traces, metrics, and logs from every service in the stack.

## What Telemetry Is Exported

Smart Redact emits the following telemetry signals:

| Signal   | Description                                                                 |
|----------|-----------------------------------------------------------------------------|
| **Traces**  | Distributed traces covering API requests, PII detection, redaction jobs, and inter-service calls. |
| **Metrics** | Runtime and application metrics (request counts, durations, queue depths, etc.).                  |
| **Logs**    | Structured log records from all services, correlated with trace context.                          |

The following services export telemetry:

- `PIIExtractor.Manager` - Client-facing API for files and jobs
- `PIIExtractor.Worker` - PII detection and redaction engine
- `PIIExtractor.Orchestrator` - Web UI backend, user management, and auth

## How to Enable Telemetry

Telemetry export is controlled by **two environment variables** on each Smart Redact service container:

| Variable                         | Description                                      | Example                         |
|----------------------------------|--------------------------------------------------|---------------------------------|
| `OTEL_EXPORTER_OTLP_ENDPOINT`   | The URL of your OpenTelemetry Collector endpoint | `http://otel-collector:4317`    |
| `OTEL_EXPORTER_OTLP_PROTOCOL`   | The OTLP transport protocol                      | `grpc` or `http/protobuf`      |

When these variables are **not set or empty**, telemetry export is disabled and there is no performance impact.

## Quick Start with Docker Compose Overlay

The easiest way to get started is to use the provided Docker Compose overlay file, which adds an OpenTelemetry Collector to the Smart Redact stack and wires up all the environment variables automatically.

```bash
# Start Smart Redact with the OTel Collector sidecar
docker compose \
  -f ../docker-compose/cpu/docker-compose.yml \
  -f docker-compose.otel.yml \
  up -d
```

This will:

1. Start an OpenTelemetry Collector container on the same network as Smart Redact
2. Set `OTEL_EXPORTER_OTLP_ENDPOINT` and `OTEL_EXPORTER_OTLP_PROTOCOL` on all three services
3. Begin exporting telemetry to the collector's debug/console output by default

To send telemetry to a real backend, replace `otel-collector-config.yaml` with one of the backend-specific examples below or edit it to add your preferred exporter.

## Collector Configuration

The default `otel-collector-config.yaml` in this directory configures the collector to:

- Receive OTLP data on port **4317** (gRPC) and **4318** (HTTP)
- Batch telemetry for efficient processing
- Export everything to **debug/console** output (for testing and learning)

It includes commented-out sections showing how to add exporters for production backends.

## Backend-Specific Examples

Ready-to-use collector configuration snippets for popular observability platforms:

| Backend                    | File                                                              | Notes                                          |
|----------------------------|-------------------------------------------------------------------|------------------------------------------------|
| **Datadog**                | [`examples/datadog.yaml`](examples/datadog.yaml)                 | Exporter and pipeline config for Datadog       |
| **Grafana Cloud**          | [`examples/grafana-cloud.yaml`](examples/grafana-cloud.yaml)     | OTLP HTTP exporter with authentication headers |
| **New Relic**              | [`examples/new-relic.yaml`](examples/new-relic.yaml)             | OTLP exporter with New Relic API key           |
| **Self-Hosted Grafana (LGTM)** | [`examples/self-hosted-grafana.yaml`](examples/self-hosted-grafana.yaml) | Full config for Loki + Tempo + Prometheus |

To use a snippet, merge the relevant exporter and pipeline sections into your `otel-collector-config.yaml`, or replace the file entirely (for the self-hosted Grafana example which is a complete configuration).

## Further Reading

- [Smart Redact Documentation](SMART_REDACT_DOCS_URL)
- [Smart Redact Deployment Guide](SMART_REDACT_DOCS_URL/deployment)
- [OpenTelemetry Collector Documentation](https://opentelemetry.io/docs/collector/)
- [OTLP Exporter Configuration](https://opentelemetry.io/docs/collector/configuration/)
