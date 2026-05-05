# C# API example

Standalone .NET console application demonstrating the full AI Smart Redact workflow using only `HttpClient` (no external packages).
The sample requests synchronous detection/redaction jobs and falls back to polling if the service returns an async response.

## Prerequisites

- [.NET 8 SDK](https://dotnet.microsoft.com/download) or later
- AI Smart Redact Manager running (default: `http://localhost:9982`)

## Usage

Run with an input PDF (from the repository root):

```bash
dotnet run --project api-examples/csharp -- "samples/Sample Document - AI Smart Redact.pdf"
```

Specify an output path:

```bash
dotnet run --project api-examples/csharp -- "samples/Sample Document - AI Smart Redact.pdf" redacted.pdf
```

If you don't specify an output path, the sample saves the redacted file as `<input>_redacted.pdf` in the current directory.

## Configuration

| Environment Variable                | Default                 | Description                                          |
| ----------------------------------- | ----------------------- | ---------------------------------------------------- |
| `MANAGER_URL`                       | `http://localhost:9982` | AI Smart Redact Manager base URL                     |
| `SMART_REDACT_HTTP_TIMEOUT_SECONDS` | `120`                   | Timeout for upload, download, and polling HTTP calls |
| `SMART_REDACT_JOB_TIMEOUT_SECONDS`  | `3600`                  | Timeout for synchronous detection/redaction requests |

Example:

```bash
MANAGER_URL=http://smartredact.example.com:9982 dotnet run --project api-examples/csharp -- "samples/Sample Document - AI Smart Redact.pdf"
```

## API reference

For full API documentation, refer to [AI Smart Redact API Reference](https://www.pdf-tools.com/docs/smart-redact/api-reference).
