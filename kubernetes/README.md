# Kubernetes Deployment

Kubernetes deployment configurations for Smart Redact.

> For detailed deployment documentation, see [Smart Redact Deployment Guide](SMART_REDACT_DOCS_URL/deployment).

## Options

| Option | Description | Best For |
|--------|-------------|----------|
| [Helm Chart](helm/) | Configurable Helm chart with values overrides | Production, teams using Helm |
| [Plain Manifests](plain-manifests/) | Raw YAML + Kustomize | Teams not using Helm |

## Storage Requirement

The provided Kubernetes samples expect shared persistent storage for `/app/storage_folder`.
Your cluster must provide a storage class that supports `ReadWriteMany` access mode, or you must adapt the manifests/chart to your storage model.

If the Docker Hub images are private, configure image pull access for your cluster before applying these samples.

## Helm Chart Quick Start

```bash
# Create namespace
kubectl create namespace smart-redact

# Create secrets
kubectl create secret generic smart-redact-secrets \
  --namespace smart-redact \
  --from-literal=license-key="<your-license-key>" \
  --from-literal=encryption-key="$(openssl rand -base64 32)" \
  --from-literal=jwt-secret="$(openssl rand -base64 64 | tr -d '\n')" \
  --from-literal=postgres-password="$(openssl rand -base64 32 | tr -d '=+/' | head -c 32)"

# Install with Helm
helm install smart-redact ./helm/smart-redact \
  --namespace smart-redact

# GPU variant
helm install smart-redact ./helm/smart-redact \
  --namespace smart-redact \
  -f ./helm/smart-redact/values-gpu.yaml

# Minimal (no Orchestrator)
helm install smart-redact ./helm/smart-redact \
  --namespace smart-redact \
  -f ./helm/smart-redact/values-minimal.yaml
```

## Verifying

```bash
# Check pods
kubectl get pods -n smart-redact

# Check services
kubectl get svc -n smart-redact

# Check health
kubectl exec -n smart-redact deploy/smart-redact-manager -- curl -s http://localhost:9982/healthz/ready

# Access the HITL Web UI locally
kubectl port-forward -n smart-redact svc/smart-redact-hitl-web 3000:3000
```

## Architecture on Kubernetes

```
                    ┌──────────────┐
                    │   Ingress    │
                    └──────┬───────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
    ┌─────────▼──┐  ┌──────▼─────┐  ┌────▼──────┐  ┌──▼──────────┐
    │  Manager   │  │Orchestrator│  │ HITL Web  │  │   Worker     │
    │  Service   │  │  Service   │  │  Service  │  │   Service    │
    │  (9982)    │  │  (9983)    │  │  (3000)   │  │   (4885)     │
    └─────┬──────┘  └─────┬──────┘  └───────────┘  └──────────────┘
          │               │
    ┌─────▼──────┐  ┌─────▼──────┐
    │ PostgreSQL │  │ PostgreSQL │
    │ (Manager)  │  │(Orchestr.) │
    │ StatefulSet│  │ StatefulSet│
    └────────────┘  └────────────┘
```
