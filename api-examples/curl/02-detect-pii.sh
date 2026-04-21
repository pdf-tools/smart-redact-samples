#!/usr/bin/env bash
# =============================================================================
# Step 2: Start a PII detection job
# =============================================================================
# Usage: ./02-detect-pii.sh <pdfFileId> <pdfDekToken> [sync|async] [detection-config-json-file]
# =============================================================================
set -euo pipefail

MANAGER_URL="${MANAGER_URL:-http://localhost:9982}"
PDF_FILE_ID="${1:?Usage: $0 <pdfFileId> <pdfDekToken> [sync|async] [detection-config-json-file]}"
PDF_DEK_TOKEN="${2:?Usage: $0 <pdfFileId> <pdfDekToken> [sync|async] [detection-config-json-file]}"
PROCESSING_MODE="${3:-async}"
CONFIG_FILE="${4:-}"

case "$PROCESSING_MODE" in
  sync|async) ;;
  *)
    echo "Error: processing mode must be 'sync' or 'async'."
    exit 1
    ;;
esac

if [ -n "$CONFIG_FILE" ] && [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: Detection configuration file not found: $CONFIG_FILE"
  exit 1
fi

payload=$(python3 - "$PDF_FILE_ID" "$PDF_DEK_TOKEN" "$PROCESSING_MODE" "$CONFIG_FILE" <<'PY'
import json
import sys

pdf_file_id, dek_token, processing_mode, config_file = sys.argv[1:5]
payload = {
    "pdfFileId": pdf_file_id,
    "dekToken": dek_token,
    "processingMode": processing_mode,
}

if config_file:
    with open(config_file, "r", encoding="utf-8") as handle:
        payload["detectionConfiguration"] = json.load(handle)

print(json.dumps(payload))
PY
)

echo "Starting PII detection for PDF: $PDF_FILE_ID"
echo ""

response=$(curl -s -w "\n%{http_code}" \
  -X POST "${MANAGER_URL}/v1/jobs/SIDetection" \
  -H "Content-Type: application/json" \
  -d "$payload")

http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

echo "HTTP Status: $http_code"
echo "Response:"
echo "$body" | python3 -m json.tool 2>/dev/null || echo "$body"

echo ""
echo "Summary:"
printf '%s' "$body" | python3 -c '
import json
import sys

data = json.load(sys.stdin)
job_id = data.get("jobId")
job_status = data.get("jobStatus")
error = data.get("error") or {}
if job_id:
    print(f"  jobId: {job_id}")
if job_status:
    print(f"  jobStatus: {job_status}")
if error.get("title"):
    print(f"  errorTitle: {error.get('title')}")
if error.get("detail"):
    print(f"  errorDetail: {error.get('detail')}")
if error.get("traceId"):
    print(f"  errorTraceId: {error.get('traceId')}")

for output_file in data.get("outputFiles") or []:
    if output_file.get("fileCode") == "fdf":
        print("  fdfFileId:", output_file.get("fileId"))
        if output_file.get("dekToken"):
            print("  fdfDekToken: present")

redactions = (data.get("result") or {}).get("redactions") or []
if redactions:
    print(f"  redactions: {len(redactions)}")
' 2>/dev/null || true

echo ""
job_status=$(printf '%s' "$body" | python3 -c 'import json,sys; data=json.load(sys.stdin); print(data.get("jobStatus", ""))' 2>/dev/null || echo "")
job_error_title=$(printf '%s' "$body" | python3 -c 'import json,sys; data=json.load(sys.stdin); print((data.get("error") or {}).get("title", ""))' 2>/dev/null || echo "")
job_error_detail=$(printf '%s' "$body" | python3 -c 'import json,sys; data=json.load(sys.stdin); print((data.get("error") or {}).get("detail", ""))' 2>/dev/null || echo "")
job_error_trace_id=$(printf '%s' "$body" | python3 -c 'import json,sys; data=json.load(sys.stdin); print((data.get("error") or {}).get("traceId", ""))' 2>/dev/null || echo "")

if [ "$http_code" = "202" ]; then
  echo "Job accepted asynchronously."
  echo "Save the 'jobId', 'fdfFileId', and 'fdfDekToken' from this response."
  echo "Use step 3 to poll for completion."
elif [ "$http_code" = "200" ] && { [ "$job_status" = "error" ] || [ -n "$job_error_title" ] || [ -n "$job_error_detail" ] || [ -n "$job_error_trace_id" ]; }; then
  echo "Detection failed."
  [ -n "$job_error_title" ] && echo "  Title: $job_error_title"
  [ -n "$job_error_detail" ] && echo "  Detail: $job_error_detail"
  [ -n "$job_error_trace_id" ] && echo "  TraceId: $job_error_trace_id"
  exit 1
elif [ "$http_code" = "200" ]; then
  echo "Detection completed synchronously."
  echo "Use the returned FDF file reference and redactions for the redaction step."
else
  echo "Unexpected status code: $http_code"
  exit 1
fi
