"""
Detect PII in a PDF using the Smart Redact Manager API.

Uploads a PDF file and runs Sensitive Information Detection.
The sample requests synchronous processing and falls back to polling if
the service returns an asynchronous response.

Usage:
    python detect_pii.py <path-to-pdf>

Environment variables:
    MANAGER_URL                        - Smart Redact Manager base URL
                                         (default: http://localhost:9982)
    SMART_REDACT_HTTP_TIMEOUT_SECONDS  - Timeout for upload/download/poll requests
                                         (default: 120)
    SMART_REDACT_JOB_TIMEOUT_SECONDS   - Timeout for synchronous detection/redaction
                                         requests (default: 3600)

See SMART_REDACT_DOCS_URL for full API documentation.
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


def get_manager_url():
    """Return the Manager API base URL from env or default."""
    return os.environ.get("MANAGER_URL", DEFAULT_MANAGER_URL).rstrip("/")


def upload_file(base_url, file_path):
    """Upload a local PDF file and return the file metadata."""
    url = f"{base_url}/v1/files/upload/fromLocal"
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
    url = f"{base_url}/v1/jobs/SIDetection"
    payload = {
        "pdfFileId": pdf_file_id,
        "dekToken": dek_token,
        "processingMode": "sync",
    }
    response = requests.post(url, json=payload, timeout=JOB_REQUEST_TIMEOUT_SECONDS)
    if response.status_code not in (200, 202):
        response.raise_for_status()
    return response.json()


def poll_job_result(base_url, job_type, job_id):
    """Poll a job result endpoint until it completes."""
    url = f"{base_url}/v1/jobs/{job_type}/{job_id}/result"
    while True:
        response = requests.get(url, timeout=HTTP_REQUEST_TIMEOUT_SECONDS)
        if response.status_code == 200:
            return response.json()
        if response.status_code == 202:
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


def main():
    parser = argparse.ArgumentParser(
        description="Detect PII in a PDF using the Smart Redact Manager API."
    )
    parser.add_argument("pdf", help="Path to the PDF file to analyze.")
    args = parser.parse_args()

    if not os.path.isfile(args.pdf):
        print(f"Error: File not found: {args.pdf}", file=sys.stderr)
        sys.exit(1)

    base_url = get_manager_url()

    print(f"Uploading {args.pdf} ...")
    upload_result = upload_file(base_url, args.pdf)
    pdf_file_id = upload_result["fileId"]
    pdf_dek_token = upload_result["dekToken"]
    print(f"Upload complete. pdfFileId={pdf_file_id}")

    print("Starting PII detection ...")
    detection_start = start_detection(base_url, pdf_file_id, pdf_dek_token)
    detection_result = resolve_job_response(base_url, "SIDetection", detection_start)
    ensure_job_succeeded(detection_result, "Detection")
    print("Detection complete.\n")

    fdf_file = get_output_file(detection_start, "fdf") or get_output_file(detection_result, "fdf")
    if fdf_file:
        print(f"FDF output fileId: {fdf_file.get('fileId')}")
        if fdf_file.get("dekToken"):
            print("FDF dekToken: present")
        print()

    print(json.dumps(detection_result, indent=2))


if __name__ == "__main__":
    try:
        main()
    except (requests.RequestException, RuntimeError, ValueError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        sys.exit(1)
