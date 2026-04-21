#!/usr/bin/env bash
# =============================================================================
# Step 5: Poll for PII redaction result
# =============================================================================
# Usage: ./05-get-redaction-result.sh <jobId> [output-json-file]
# =============================================================================
set -euo pipefail

MANAGER_URL="${MANAGER_URL:-http://localhost:9982}"
JOB_ID="${1:?Usage: $0 <jobId> [output-json-file]}"
OUTPUT_FILE="${2:-}"

echo "Polling redaction result for job: $JOB_ID"
echo ""

response=$(curl -s -w "\n%{http_code}" \
  -X GET "${MANAGER_URL}/v1/jobs/SIRedaction/${JOB_ID}/result")

http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

echo "HTTP Status: $http_code"
echo "Response:"
echo "$body" | python3 -m json.tool 2>/dev/null || echo "$body"

echo ""
if [ -n "$OUTPUT_FILE" ]; then
  printf '%s' "$body" > "$OUTPUT_FILE"
  echo "Saved response JSON to: $OUTPUT_FILE"
  echo ""
fi

echo "Summary:"
printf '%s' "$body" | python3 -c '
import json
import sys

data = json.load(sys.stdin)
job_status = data.get("jobStatus")
error = data.get("error") or {}
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
' 2>/dev/null || true

echo ""
job_status=$(printf '%s' "$body" | python3 -c 'import json,sys; data=json.load(sys.stdin); print(data.get("jobStatus", ""))' 2>/dev/null || echo "")
job_error_title=$(printf '%s' "$body" | python3 -c 'import json,sys; data=json.load(sys.stdin); print((data.get("error") or {}).get("title", ""))' 2>/dev/null || echo "")
job_error_detail=$(printf '%s' "$body" | python3 -c 'import json,sys; data=json.load(sys.stdin); print((data.get("error") or {}).get("detail", ""))' 2>/dev/null || echo "")
job_error_trace_id=$(printf '%s' "$body" | python3 -c 'import json,sys; data=json.load(sys.stdin); print((data.get("error") or {}).get("traceId", ""))' 2>/dev/null || echo "")

if [ "$http_code" = "202" ]; then
  echo "The job is still in progress. Wait a few seconds and run this script again."
elif [ "$http_code" = "200" ] && { [ "$job_status" = "error" ] || [ -n "$job_error_title" ] || [ -n "$job_error_detail" ] || [ -n "$job_error_trace_id" ]; }; then
  echo "Redaction failed."
  [ -n "$job_error_title" ] && echo "  Title: $job_error_title"
  [ -n "$job_error_detail" ] && echo "  Detail: $job_error_detail"
  [ -n "$job_error_trace_id" ] && echo "  TraceId: $job_error_trace_id"
  exit 1
elif [ "$http_code" = "200" ]; then
  echo "Redaction is complete."
  echo "If this job was started asynchronously, keep using the redactedPdfDekToken from step 4."
else
  echo "Unexpected status code: $http_code"
  exit 1
fi
