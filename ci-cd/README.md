# CI/CD Examples

Example CI/CD pipeline configurations for deploying Smart Redact.

These examples cover pulling pre-built Docker images and deploying to a Docker Compose or Kubernetes environment. Adapt them to your specific infrastructure.

## Available Examples

| Platform | File | Description |
|----------|------|-------------|
| GitHub Actions | [github-actions/deploy.yml](github-actions/deploy.yml) | Deploy to Docker Compose or Kubernetes |
| GitLab CI | [gitlab-ci/.gitlab-ci.yml](gitlab-ci/.gitlab-ci.yml) | Deploy to Docker Compose or Kubernetes |

## Required Secrets

Both examples expect these secrets/variables configured in your CI platform:

| Secret | Description |
|--------|-------------|
| `PII_SERVICE_LICENSE_KEY` | Smart Redact license key |
| `ENCRYPTION_KEY` | AES-256-GCM encryption key |
| `ORCHESTRATOR_JWT_SECRET` | JWT signing secret |
| `POSTGRES_PASSWORD` | PostgreSQL password (generate per environment, e.g. `openssl rand -base64 32 \| tr -d '=+/' \| head -c 32`) |
| `DEPLOY_HOST` | Target server hostname/IP (for Docker Compose) |
| `DEPLOY_SSH_KEY` | SSH private key for deployment |
| `KUBE_CONFIG` | Base64-encoded kubeconfig file content (for the GitHub Actions example) |

> See [Smart Redact Deployment Guide](SMART_REDACT_DOCS_URL/deployment) for details.
