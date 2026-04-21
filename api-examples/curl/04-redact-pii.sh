#!/usr/bin/env bash
# =============================================================================
# Step 4: Start a PII redaction job
# =============================================================================
# Usage:
#   ./04-redact-pii.sh <pdfFileId> <fdfFileId> <pdfDekToken> <fdfDekToken> <redactions-json-file> [sync|async]
#
# The redactions JSON file may contain either:
#   - the full SI Detection response object, or
#   - only the redactions array
# =============================================================================
set -euo pipefail

MANAGER_URL="${MANAGER_URL:-http://localhost:9982}"
PDF_FILE_ID="${1:?Usage: $0 <pdfFileId> <fdfFileId> <pdfDekToken> <fdfDekToken> <redactions-json-file> [sync|async]}"
FDF_FILE_ID="${2:?Usage: $0 <pdfFileId> <fdfFileId> <pdfDekToken> <fdfDekToken> <redactions-json-file> [sync|async]}"
PDF_DEK_TOKEN="${3:?Usage: $0 <pdfFileId> <fdfFileId> <pdfDekToken> <fdfDekToken> <redactions-json-file> [sync|async]}"
FDF_DEK_TOKEN="${4:?Usage: $0 <pdfFileId> <fdfFileId> <pdfDekToken> <fdfDekToken> <redactions-json-file> [sync|async]}"
REDACTIONS_FILE="${5:?Usage: $0 <pdfFileId> <fdfFileId> <pdfDekToken> <fdfDekToken> <redactions-json-file> [sync|async]}"
PROCESSING_MODE="${6:-async}"

case "$PROCESSING_MODE" in
  sync|async) ;;
  *)
    echo "Error: processing mode must be 'sync' or 'async'."
    exit 1
    ;;
esac

if [ ! -f "$REDACTIONS_FILE" ]; then
  echo "Error: Redactions file not found: $REDACTIONS_FILE"
  exit 1
fi

payload=$(python3 - "$PDF_FILE_ID" "$FDF_FILE_ID" "$PDF_DEK_TOKEN" "$FDF_DEK_TOKEN" "$REDACTIONS_FILE" "$PROCESSING_MODE" <<'PY'
import json
import sys

pdf_file_id, fdf_file_id, pdf_dek_token, fdf_dek_token, redactions_file, processing_mode = sys.argv[1:7]

with open(redactions_file, "r", encoding="utf-8") as handle:
    data = json.load(handle)

if isinstance(data, dict):
    redactions = data.get("result", {}).get("redactions")
    if redactions is None:
        redactions = data.get("redactions")
else:
    redactions = data

if not isinstance(redactions, list):
    raise SystemExit("Redactions file must contain either a detection response object or a redactions array.")

payload = {
    "pdfFileId": pdf_file_id,
    "fdfFileId": fdf_file_id,
    "pdfDekToken": pdf_dek_token,
    "fdfDekToken": fdf_dek_token,
    "redactionInput": {
        "redactions": redactions,
    },
    "processingMode": processing_mode,
}

print(json.dumps(payload))
PY
)

echo "Starting PII redaction for PDF: $PDF_FILE_ID"
echo ""

response=$(curl -s -w "\n%{http_code}" \
  -X POST "${MANAGER_URL}/v1/jobs/SIRedaction" \
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
    if output_file.get("fileCode") == "pdf":
        print("  redactedPdfFileId:", output_file.get("fileId"))
        if output_file.get("dekToken"):
            print("  redactedPdfDekToken: present")
' 2>/dev/null || true

echo ""
job_status=$(printf '%s' "$body" | python3 -c 'import json,sys; data=json.load(sys.stdin); print(data.get("jobStatus", ""))' 2>/dev/null || echo "")
job_error_title=$(printf '%s' "$body" | python3 -c 'import json,sys; data=json.load(sys.stdin); print((data.get("error") or {}).get("title", ""))' 2>/dev/null || echo "")
job_error_detail=$(printf '%s' "$body" | python3 -c 'import json,sys; data=json.load(sys.stdin); print((data.get("error") or {}).get("detail", ""))' 2>/dev/null || echo "")
job_error_trace_id=$(printf '%s' "$body" | python3 -c 'import json,sys; data=json.load(sys.stdin); print((data.get("error") or {}).get("traceId", ""))' 2>/dev/null || echo "")

if [ "$http_code" = "202" ]; then
  echo "Redaction job accepted asynchronously."
  echo "Save the 'jobId', 'redactedPdfFileId', and 'redactedPdfDekToken' from this response."
  echo "Use step 5 to poll for completion."
elif [ "$http_code" = "200" ] && { [ "$job_status" = "error" ] || [ -n "$job_error_title" ] || [ -n "$job_error_detail" ] || [ -n "$job_error_trace_id" ]; }; then
  echo "Redaction failed."
  [ -n "$job_error_title" ] && echo "  Title: $job_error_title"
  [ -n "$job_error_detail" ] && echo "  Detail: $job_error_detail"
  [ -n "$job_error_trace_id" ] && echo "  TraceId: $job_error_trace_id"
  exit 1
elif [ "$http_code" = "200" ]; then
  echo "Redaction completed synchronously."
  echo "Use the returned redacted PDF file reference for download."
else
  echo "Unexpected status code: $http_code"
  exit 1
fi
