# Security policy

We take the security of Smart Redact and these sample configurations seriously. If you believe you have found a security vulnerability, please report it privately as described below.

## Reporting a vulnerability

**Please do not file public GitHub issues for security vulnerabilities.**

Email security reports to **security@pdftools.com**.

If you would like to encrypt your report, please request our PGP key in your initial (low-detail) email and we will respond with one.

To help us triage and reproduce the issue quickly, please include as much of the following as you can:

- A description of the vulnerability and its potential impact
- Steps to reproduce, including affected versions, image tags, or configuration
- Any proof-of-concept code, request payloads, or sample inputs
- Your name and affiliation (optional)

## Scope

This policy covers:

- The sample configurations, scripts, and example code in this repository (`smart-redact-samples`).
- The Smart Redact product itself (Manager, Worker, Orchestrator, and HITL Web UI), including the published Docker images under the `pdftoolsag/` namespace on Docker Hub.

The same address (`security@pdftools.com`) handles reports for both. You do not need to determine whether an issue is in the samples or the product before reporting it — we will route it internally.

## Response process

After you submit a report, you can expect the following:

1. **Acknowledgment** — within **5 business days**, confirming we received the report and have begun triage.
2. **Initial assessment** — a follow-up with our preliminary severity assessment and any clarifying questions.
3. **Remediation** — we will keep you informed as we develop, test, and release a fix. Timelines depend on severity and complexity.
4. **Disclosure** — we prefer coordinated disclosure: please give us a reasonable window to release a fix before any public discussion.
