# Pre-Release Checklist

Internal checklist to complete before making `smart-redact-samples` public on GitHub / Docker Hub.
Delete this file before publishing.

## Docker image references

- [x] Final public Docker Hub image names confirmed as `pdftoolsag/smart-redact-manager`, `pdftoolsag/smart-redact-worker`, `pdftoolsag/smart-redact-worker:*-cuda`, `pdftoolsag/smart-redact-orchestrator` — no rename needed.
- [x] Publish the three images to Docker Hub as public (Manager, Worker CPU + CUDA, Orchestrator).
- [x] Smoke-test `docker pull` of each final image tag from a machine that is not logged in to any registry.

## Documentation placeholders

- [x] Replace all `https://www.pdf-tools.com/docs/smart-redact` occurrences with the final public documentation base URL. Affected:
  - `README.md`
  - `.env.example`
  - `api-examples/README.md`, `api-examples/csharp/README.md`, `api-examples/csharp/Program.cs`
  - `api-examples/python/detect_pii.py`, `api-examples/python/redact_pii.py`, `api-examples/python/full_workflow.py`
  - `docker-compose/README.md`
- [x] Replace `<repo-url>` in `README.md` with `https://github.com/pdf-tools/smart-redact-samples.git`.

## Content fixes

- [x] Added a note in `docker-compose/README.md` explaining that the default postgres password `smartredact` in `docker-compose/*/docker-compose.yml` is for local demonstration only and must be changed for production.
- [x] Aligned documented HTTP timeout default with the code (now 120s in all docs):
  - `api-examples/python/detect_pii.py`
  - `api-examples/python/redact_pii.py`
  - `api-examples/python/full_workflow.py`
  - `api-examples/csharp/README.md`
- [x] Added a timeout guard (`WORKER_HEALTH_TIMEOUT_SECONDS`, default 300s) to the worker health wait loop in `docker-run/run-all.sh`.
## Repository hygiene

- [x] Committed the previously untracked files:
  - `.gitignore`
  - `docker-run/run-storage-init.sh`
- [x] Cleaned up git history — single `Add Smart Redact samples` commit via orphan branch. Any future internal work-in-progress will be squashed again before publishing.

## Licensing and policies

- [x] Add a top-level `LICENSE` file. Recommendation: **MIT** (standard for vendor sample repos, most permissive, widest downstream use). Apache-2.0 if an explicit patent grant is required. Confirm with Legal.
- [x] Confirm that publishing these sample configurations as open source is approved (contracts, product, legal).
- [x] Confirm trademark usage of `PDF Tools` / `Smart Redact` in the README metadata.
- [x] Add `SECURITY.md` with instructions for reporting security vulnerabilities (private disclosure address, expected response time).

## Final verification (to be repeated close to release)

- [ ] Clone the repo into a clean directory as if a first-time customer would, run `bash smart-redact.sh setup --license-key "<RDCTSRV,...>"`, and run `bash smart-redact.sh up` end-to-end.
- [ ] Run `bash smart-redact.sh up` and `bash smart-redact.sh health` for the Compose CPU quick start — both must pass.
- [ ] Run `bash api-examples/curl/full-workflow.sh <some.pdf>` end-to-end against a pristine stack.
- [ ] Run `python3 api-examples/python/full_workflow.py <some.pdf>` end-to-end.
- [ ] Run `dotnet run --project api-examples/csharp/ -- <some.pdf>` end-to-end.
- [ ] Smoke-test the quick start on a Windows machine using Git Bash (or at minimum WSL2).

## Publishing

- [x] Create the public GitHub repository at `https://github.com/pdf-tools/smart-redact-samples` (kept private until launch).
- [x] Configure GitHub repo description, topics, and website link (documentation URL).
- [x] Update the product landing page / marketing site to link to this repo once it is public.
- [ ] Push the cleaned history.
- [ ] Delete this `PRE_RELEASE_CHECKLIST.md` file in the same PR that flips the repo to public.
