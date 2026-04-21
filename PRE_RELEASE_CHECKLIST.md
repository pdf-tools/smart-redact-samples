# Pre-Release Checklist

Internal checklist to complete before making `smart-redact-samples` public on GitHub / Docker Hub.
Delete this file before publishing.

## Secrets and credentials

- [ ] Rotate `PII_SERVICE_LICENSE_KEY`, `ENCRYPTION_KEY`, and `ORCHESTRATOR_JWT_SECRET` that were used during local testing (they passed through developer tooling and should not be reused in production).
- [ ] Delete local `.env` file(s) that contain real license/encryption/JWT values: `rm docker-compose/cpu/.env` (and any other `.env` under `docker-compose/*/`).
- [ ] Verify no secrets are present in tracked files: `git grep -E "RDCTSRV|BEGIN (RSA|EC) PRIVATE|eyJhbGci"` must return empty.
- [ ] Confirm `.gitignore` still covers `.env`, `*.env`, `*.key`, `*.pem`, `secrets/`, `bin/`, `obj/`, `__pycache__/`.

## Docker image references

- [ ] Finalize public Docker Hub image names and global-replace across the repo (currently `pdftoolsag/smart-redact-manager`, `pdftoolsag/smart-redact-worker`, `pdftoolsag/smart-redact-worker:*-cuda`, `pdftoolsag/smart-redact-orchestrator` — 21 references across 15 files).
- [ ] Publish the three images to Docker Hub as public (Manager, Worker CPU + CUDA, Orchestrator).
- [ ] Smoke-test `docker pull` of each final image tag from a machine that is not logged in to any registry.

## Documentation placeholders

- [ ] Replace all `SMART_REDACT_DOCS_URL` occurrences (23 instances across 19 files) with the final public documentation base URL. Affected:
  - `README.md` (11 occurrences)
  - `.env.example`
  - `api-examples/README.md`, `api-examples/csharp/README.md`, `api-examples/csharp/Program.cs`
  - `api-examples/python/detect_pii.py`, `api-examples/python/redact_pii.py`, `api-examples/python/full_workflow.py`
  - `ci-cd/README.md`
  - `docker-compose/README.md`
  - `kubernetes/README.md`
  - `opentelemetry/README.md`
- [ ] Replace `<repo-url>` in `README.md` (`git clone <repo-url>`) with the final public Git URL.
- [ ] Replace `nicerhugs` placeholder in `kubernetes/helm/smart-redact/Chart.yaml` `sources:` field with the final public repo URL.

## Content fixes

- [ ] Remove hardcoded `postgres-password="smartredact"` example in `ci-cd/github-actions/deploy.yml`, `ci-cd/gitlab-ci/.gitlab-ci.yml`, and `kubernetes/README.md`. Align with the secure pattern already used in `kubernetes/helm/smart-redact/templates/NOTES.txt` and `kubernetes/plain-manifests/secrets.yaml` (`openssl rand -base64 32 | tr -d '=+/' | head -c 32`).
- [ ] Add a short note in `docker-compose/README.md` explaining that the default postgres password `smartredact` in `docker-compose/*/docker-compose.yml` is for local demonstration only and must be changed for production.
- [ ] Align documented HTTP timeout default with the code (code uses 120s, docs/README say 30s). Update:
  - `api-examples/python/detect_pii.py` docstring
  - `api-examples/python/redact_pii.py` docstring
  - `api-examples/python/full_workflow.py` docstring
  - `api-examples/csharp/README.md` timeout table
- [ ] Add a timeout guard to the worker health wait loop in `docker-run/run-all.sh` so that it does not loop forever if the worker never becomes healthy.
- [ ] Soften Postman demo passwords in `api-examples/postman/Smart-Redact-Orchestrator.postman_collection.json` (`MySecurePassword1!`, `UserPassword1!`, `NewPassword1!`, `ResetPassword1!`) — replace with placeholder strings like `<choose-a-strong-password>` to avoid looking like a recommended copy-paste value. Keep the default `admin / Admin1234` as-is since that is the actual bootstrap credential.

## Repository hygiene

- [ ] Stage and commit the three currently untracked files:
  - `.gitignore`
  - `docker-run/run-storage-init.sh` (critical — `run-all.sh` fails without it)
  - `kubernetes/helm/smart-redact/templates/NOTES.txt`
- [ ] Run `dotnet clean` in `api-examples/csharp/` and remove `api-examples/python/__pycache__/` before the final commit (they are gitignored but should not exist in the tree for cleanliness).
- [ ] Remove any other local experimentation artifacts (backup files, test PDFs, downloaded outputs).
- [ ] Clean up git history — squash or reorganize commits so the public history does not expose internal work-in-progress, personal notes, or the license key that passed through developer tooling. Two options:
  - Option A: orphan branch with a single `Initial public release` commit (fastest, wipes all traces).
  - Option B: logical multi-commit sequence (structure / API examples / Kubernetes / CI-CD / OpenTelemetry) for a cleaner-looking first public history.

## Licensing and policies

- [ ] Add a top-level `LICENSE` file. Decide between MIT / Apache-2.0 / proprietary sample license (consult Legal). The repo currently has no license file.
- [ ] Add `SECURITY.md` with instructions for reporting security vulnerabilities (private disclosure address, expected response time).
- [ ] Confirm that publishing these sample configurations as open source is approved (contracts, product, legal).
- [ ] Confirm trademark usage of `PDF Tools` / `Smart Redact` in the README / Chart.yaml metadata.

## Final verification

- [ ] Clone the repo into a clean directory as if a first-time customer would, fill in `.env` with a fresh license key, and run `docker compose -f docker-compose/cpu/docker-compose.yml up -d` end-to-end.
- [ ] Run `bash scripts/wait-for-services.sh` and `bash scripts/health-check.sh` — both must pass.
- [ ] Run `bash api-examples/curl/full-workflow.sh <some.pdf>` end-to-end against a pristine stack.
- [ ] Run `python3 api-examples/python/full_workflow.py <some.pdf>` end-to-end.
- [ ] Run `dotnet run --project api-examples/csharp/ -- <some.pdf>` end-to-end.
- [ ] `helm lint kubernetes/helm/smart-redact` clean.
- [ ] `helm template smart-redact kubernetes/helm/smart-redact --values kubernetes/helm/smart-redact/values.yaml` renders without errors for default, GPU, and minimal values files.
- [ ] `kubectl kustomize kubernetes/plain-manifests` renders without errors.
- [ ] `docker run --rm otel/opentelemetry-collector-contrib:<pinned-version> validate --config=/cfg/config.yaml` passes for `opentelemetry/otel-collector-config.yaml` and each `opentelemetry/examples/*.yaml`.
- [ ] Smoke-test the quick start on a Windows machine using Git Bash (or at minimum WSL2). Verify `scripts/generate-encryption-key.ps1` runs from PowerShell and produces a valid 32-byte base64 key.

## Publishing

- [ ] Create the public GitHub repository under the correct organization (kept private until launch).
- [ ] Push the cleaned history.
- [ ] Enable branch protection on `main` (required reviews, no force push, signed commits if org policy).
- [ ] Configure GitHub repo description, topics, and website link (documentation URL).
- [ ] Add `CODEOWNERS` if internal review routing is desired.
- [ ] Update the product landing page / marketing site to link to this repo once it is public.
- [ ] Delete this `PRE_RELEASE_CHECKLIST.md` file in the same PR that flips the repo to public.
