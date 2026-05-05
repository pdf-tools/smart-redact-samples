# API Examples

Usage examples for the Smart Redact Manager API.

> For the full API reference, see [Smart Redact API Documentation](https://www.pdf-tools.com/docs/smart-redact/api-reference).

## Available Examples

| Language   | Directory          | Description                         |
| ---------- | ------------------ | ----------------------------------- |
| **curl**   | [curl/](curl/)     | Shell scripts for each API step     |
| **C#**     | [csharp/](csharp/) | .NET console app using `HttpClient` |
| **Python** | [python/](python/) | Python scripts using `requests`     |

## Typical Workflow

A standard PII detection and redaction workflow:

```
1. Upload a PDF file           POST /v1/files/upload/fromLocal
2. Start PII detection         POST /v1/jobs/detection
3. Save FDF output + redactions from the detection response
4. Start PII redaction         POST /v1/jobs/redaction
5. Download the redacted PDF   POST /v1/files/download
```

For asynchronous jobs:

```
1. Create the job with "processingMode": "async"
2. Save the output file reference and DEK token from the initial response
3. Poll GET /v1/jobs/.../{jobId}/result until "jobStatus" becomes "finished"
4. Keep using the DEK token from the initial async response for downloads
```

## API Endpoints

**Manager API** (default: http://localhost:9982):

| Method   | Endpoint                              | Description           |
| -------- | ------------------------------------- | --------------------- |
| `POST`   | `/v1/files/upload/fromLocal`          | Upload a PDF file     |
| `POST`   | `/v1/files/upload/fromUrl`            | Upload a PDF from URL |
| `GET`    | `/v1/files`                           | List uploaded files   |
| `GET`    | `/v1/files/{fileId}`                  | Get file metadata     |
| `POST`   | `/v1/files/download`                  | Download a file       |
| `DELETE` | `/v1/files/{fileId}`                  | Delete a file         |
| `POST`   | `/v1/jobs/detection`                | Start a detection job |
| `GET`    | `/v1/jobs/detection/{jobId}/result` | Get detection result  |
| `POST`   | `/v1/jobs/redaction`                | Start a redaction job |
| `GET`    | `/v1/jobs/redaction/{jobId}/result` | Get redaction result  |

**Swagger UI:** http://localhost:9982/swagger

## Orchestrator API

If you're using the Orchestrator (web UI backend), it has its own API with authentication:

- **Default credentials:** `admin@example.com` / `Admin@1234!Tmp` (password reset required on first login)
- **Swagger UI:** http://localhost:9983/swagger

> See [Orchestrator Authentication Guide](https://www.pdf-tools.com/docs/smart-redact/authentication) for details.
