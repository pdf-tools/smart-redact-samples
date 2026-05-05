"""
Full Smart Redact workflow with verbose output.

Walks through every step of the Smart Redact Manager API:
  1. Upload a PDF
  2. Run Sensitive Information Detection
  3. Run Sensitive Information Redaction
  4. Download the redacted PDF

Each step prints detailed information, making this script ideal for
learning and demos.

Usage:
    python full_workflow.py <input-pdf> [<output-pdf>]

If no output path is given, the redacted file is saved as
"<input-basename>_redacted.pdf" in the current directory.

Environment variables:
    MANAGER_URL                        - Smart Redact Manager base URL
                                         (default: http://localhost:9982)
    SMART_REDACT_HTTP_TIMEOUT_SECONDS  - Timeout for upload/download/poll requests
                                         (default: 120)
    SMART_REDACT_JOB_TIMEOUT_SECONDS   - Timeout for synchronous detection/redaction
                                         requests (default: 3600)

See https://www.pdf-tools.com/docs/smart-redact for full API documentation.
"""

import argparse
import json
import os
import sys
import time

import requests

DEFAULT_MANAGER_URL = "http://localhost:9982"
POLL_INTERVAL_SECONDS = 2
HTTP_REQUEST_TIMEOUT_SECONDS = int(os.environ.get("SMART_REDACT_HTTP_TIMEOUT_SECONDS", "120"))
JOB_REQUEST_TIMEOUT_SECONDS = int(os.environ.get("SMART_REDACT_JOB_TIMEOUT_SECONDS", "3600"))
SEPARATOR = "-" * 60


def get_manager_url():
    """Return the Manager API base URL from env or default."""
    return os.environ.get("MANAGER_URL", DEFAULT_MANAGER_URL).rstrip("/")


def print_step(number, title):
    """Print a formatted step header."""
    print(f"\n{SEPARATOR}")
    print(f"  Step {number}: {title}")
    print(SEPARATOR)


def print_json(label, data):
    """Pretty-print a JSON response with a label."""
    print(f"\n{label}:")
    print(json.dumps(data, indent=2))


def upload_file(base_url, file_path):
    """Upload a local PDF file and return the response JSON."""
    url = f"{base_url}/v1/files/upload/fromLocal"
    print(f"  POST {url}")
    with open(file_path, "rb") as handle:
        response = requests.post(
            url,
            files={"file": handle},
            timeout=HTTP_REQUEST_TIMEOUT_SECONDS,
        )
    response.raise_for_status()
    return response.json()


def start_detection(base_url, pdf_file_id, dek_token):
    """Start a Sensitive Information Detection job."""
    url = f"{base_url}/v1/jobs/detection"
    payload = {
        "pdfFileId": pdf_file_id,
        "dekToken": dek_token,
        "processingMode": "sync",
    }
    print(f"  POST {url}")
    print(f"  Payload: {json.dumps(payload)}")
    response = requests.post(url, json=payload, timeout=JOB_REQUEST_TIMEOUT_SECONDS)
    if response.status_code not in (200, 202):
        response.raise_for_status()
    return response.json()


def start_redaction(base_url, pdf_file_id, fdf_file_id, pdf_dek_token, fdf_dek_token, redactions):
    """Start a Sensitive Information Redaction job."""
    url = f"{base_url}/v1/jobs/redaction"
    payload = {
        "pdfFileId": pdf_file_id,
        "fdfFileId": fdf_file_id,
        "pdfDekToken": pdf_dek_token,
        "fdfDekToken": fdf_dek_token,
        "redactionInput": {
            "redactions": redactions,
        },
        "processingMode": "sync",
    }
    print(f"  POST {url}")
    print(f"  Payload: {json.dumps(payload)}")
    response = requests.post(url, json=payload, timeout=JOB_REQUEST_TIMEOUT_SECONDS)
    if response.status_code not in (200, 202):
        response.raise_for_status()
    return response.json()


def poll_job_result(base_url, job_type, job_id):
    """Poll a job result endpoint until it completes."""
    url = f"{base_url}/v1/jobs/{job_type}/{job_id}/result"
    print(f"  Polling GET {url} ...")
    attempts = 0
    while True:
        response = requests.get(url, timeout=HTTP_REQUEST_TIMEOUT_SECONDS)
        attempts += 1
        if response.status_code == 200:
            print(f"  Job finished after {attempts} poll(s).")
            return response.json()
        if response.status_code == 202:
            print(f"  Poll {attempts}: still in progress ...")
            time.sleep(POLL_INTERVAL_SECONDS)
            continue
        response.raise_for_status()


def resolve_job_response(base_url, job_type, initial_response):
    """Return the final response, polling if the job is still in progress."""
    if initial_response.get("jobStatus") == "inProgress":
        return poll_job_result(base_url, job_type, initial_response["jobId"])
    return initial_response


def get_output_file(job_response, file_code):
    """Return the first output file matching the requested file code."""
    for output_file in job_response.get("outputFiles") or []:
        if output_file.get("fileCode") == file_code:
            return output_file
    return None


def get_redactions(detection_result):
    """Extract the detected redactions array from a detection response."""
    result = detection_result.get("result") or {}
    redactions = result.get("redactions")
    if redactions is None:
        raise ValueError("Detection result did not include a redactions array.")
    return redactions


def format_job_error(job_response, stage_name):
    """Build a readable error message from a failed job response."""
    error = job_response.get("error") or {}
    title = error.get("title") or f"{stage_name} job failed."
    detail = error.get("detail")
    trace_id = error.get("traceId")

    parts = [title]
    if detail:
        parts.append(f"Detail: {detail}")
    if trace_id:
        parts.append(f"TraceId: {trace_id}")
    return " ".join(parts)


def ensure_job_succeeded(job_response, stage_name):
    """Raise when the Manager reports a finished job error."""
    error = job_response.get("error") or {}
    if job_response.get("jobStatus") == "error" or error:
        raise RuntimeError(format_job_error(job_response, stage_name))


def download_file(base_url, file_id, dek_token, output_path):
    """Download a file from the Manager and save it to disk."""
    url = f"{base_url}/v1/files/download"
    payload = {"fileId": file_id, "dekToken": dek_token}
    print(f"  POST {url}")
    print(f"  Payload: {json.dumps(payload)}")
    response = requests.post(url, json=payload, timeout=HTTP_REQUEST_TIMEOUT_SECONDS)
    response.raise_for_status()
    with open(output_path, "wb") as handle:
        handle.write(response.content)
    print(f"  Wrote {len(response.content)} bytes to {output_path}")


def default_output_path(input_path):
    """Derive a default output path from the input filename."""
    base, ext = os.path.splitext(os.path.basename(input_path))
    return f"{base}_redacted{ext}"


def main():
    parser = argparse.ArgumentParser(
        description="Full Smart Redact workflow with verbose output."
    )
    parser.add_argument("input_pdf", help="Path to the input PDF file.")
    parser.add_argument(
        "output_pdf",
        nargs="?",
        default=None,
        help="Path for the redacted output PDF (default: <input>_redacted.pdf).",
    )
    args = parser.parse_args()

    if not os.path.isfile(args.input_pdf):
        print(f"Error: File not found: {args.input_pdf}", file=sys.stderr)
        sys.exit(1)

    output_path = args.output_pdf or default_output_path(args.input_pdf)
    base_url = get_manager_url()

    print(f"Smart Redact Manager URL: {base_url}")
    print(f"Input file:               {args.input_pdf}")
    print(f"Output file:              {output_path}")

    print_step(1, "Upload PDF")
    upload_result = upload_file(base_url, args.input_pdf)
    pdf_file_id = upload_result["fileId"]
    pdf_dek_token = upload_result["dekToken"]
    print_json("Upload response", upload_result)

    print_step(2, "Sensitive Information Detection")
    detection_start = start_detection(base_url, pdf_file_id, pdf_dek_token)
    print_json("Detection start response", detection_start)

    detection_result = resolve_job_response(base_url, "detection", detection_start)
    if detection_result is not detection_start:
        print_json("Detection result", detection_result)
    ensure_job_succeeded(detection_result, "Detection")

    fdf_file = get_output_file(detection_start, "fdf") or get_output_file(detection_result, "fdf")
    if not fdf_file or not fdf_file.get("fileId") or not fdf_file.get("dekToken"):
        print("Error: Detection did not return an FDF output file with a DEK token.", file=sys.stderr)
        sys.exit(1)

    redactions = get_redactions(detection_result)
    print(f"\nFDF fileId: {fdf_file['fileId']}")
    print(f"Redactions: {len(redactions)}")

    print_step(3, "Sensitive Information Redaction")
    redaction_start = start_redaction(
        base_url,
        pdf_file_id,
        fdf_file["fileId"],
        pdf_dek_token,
        fdf_file["dekToken"],
        redactions,
    )
    print_json("Redaction start response", redaction_start)

    redaction_result = resolve_job_response(base_url, "redaction", redaction_start)
    if redaction_result is not redaction_start:
        print_json("Redaction result", redaction_result)
    ensure_job_succeeded(redaction_result, "Redaction")

    redacted_pdf = get_output_file(redaction_start, "pdf") or get_output_file(redaction_result, "pdf")
    if not redacted_pdf or not redacted_pdf.get("fileId") or not redacted_pdf.get("dekToken"):
        print("Error: Redaction did not return a downloadable PDF output.", file=sys.stderr)
        sys.exit(1)

    print_step(4, "Download Redacted PDF")
    download_file(base_url, redacted_pdf["fileId"], redacted_pdf["dekToken"], output_path)

    print(f"\n{SEPARATOR}")
    print("  Workflow complete!")
    print(f"  Redacted PDF saved to: {output_path}")
    print(SEPARATOR)


if __name__ == "__main__":
    try:
        main()
    except (requests.RequestException, RuntimeError, ValueError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)
