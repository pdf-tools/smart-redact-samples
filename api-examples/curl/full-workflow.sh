#!/usr/bin/env bash
# =============================================================================
# Smart Redact - Full Detection & Redaction Workflow
# =============================================================================
# End-to-end example: upload PDF -> detect PII -> redact PII -> download result
#
# Usage: ./full-workflow.sh <path-to-pdf> [output-path]
#
# Environment variables:
#   MANAGER_URL                       Manager API base URL (default http://localhost:9982)
#   SMART_REDACT_HTTP_TIMEOUT_SECONDS curl timeout for upload/download (default 120)
#   SMART_REDACT_JOB_TIMEOUT_SECONDS  curl timeout for sync detection/redaction (default 3600)
# =============================================================================
set -euo pipefail

MANAGER_URL="${MANAGER_URL:-http://localhost:9982}"
INPUT_FILE="${1:?Usage: $0 <path-to-pdf> [output-path]}"
OUTPUT_FILE="${2:-redacted-output.pdf}"
HTTP_TIMEOUT="${SMART_REDACT_HTTP_TIMEOUT_SECONDS:-120}"
JOB_TIMEOUT="${SMART_REDACT_JOB_TIMEOUT_SECONDS:-3600}"

if [ ! -f "$INPUT_FILE" ]; then
  echo "Error: File not found: $INPUT_FILE"
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

extract_json_value() {
  local file_path="$1"
  local expression="$2"

  python3 - "$file_path" "$expression" <<'PY'
import json
import sys

file_path, expression = sys.argv[1:3]
with open(file_path, "r", encoding="utf-8") as handle:
    data = json.load(handle)

value = eval(expression, {}, {"data": data})
if value is None:
    print("")
    raise SystemExit(0)

if isinstance(value, (dict, list)):
    print(json.dumps(value))
else:
    print(value)
PY
}

check_job_success_or_exit() {
  local file_path="$1"
  local stage_name="$2"
  local raw_body="$3"
  local job_status
  local error_title
  local error_detail
  local error_trace_id

  job_status="$(extract_json_value "$file_path" 'data.get("jobStatus")')"
  error_title="$(extract_json_value "$file_path" '(data.get("error") or {}).get("title")')"
  error_detail="$(extract_json_value "$file_path" '(data.get("error") or {}).get("detail")')"
  error_trace_id="$(extract_json_value "$file_path" '(data.get("error") or {}).get("traceId")')"

  if [ "$job_status" = "error" ] || [ -n "$error_title" ] || [ -n "$error_detail" ] || [ -n "$error_trace_id" ]; then
    echo "  $stage_name failed." >&2
    [ -n "$error_title" ]     && echo "    Title:   $error_title"    >&2
    [ -n "$error_detail" ]    && echo "    Detail:  $error_detail"   >&2
    [ -n "$error_trace_id" ]  && echo "    TraceId: $error_trace_id" >&2
    if [ -z "$error_title" ] && [ -z "$error_detail" ] && [ -z "$error_trace_id" ]; then
      echo "    Raw response:" >&2
      echo "$raw_body" | python3 -m json.tool >&2 2>/dev/null || echo "$raw_body" >&2
    fi
    exit 1
  fi
}

echo "=========================================="
echo " Smart Redact - Full Workflow"
echo "=========================================="
echo ""

# ---------------------------------------------------------------------------
# Step 1 - Upload input PDF
# ---------------------------------------------------------------------------
echo "[1/4] Uploading: $INPUT_FILE"
upload_body=$(curl -sS --max-time "$HTTP_TIMEOUT" \
  -X POST "${MANAGER_URL}/v1/files/upload/fromLocal" \
  -F "file=@${INPUT_FILE}")

printf '%s' "$upload_body" > "$TMP_DIR/upload.json"

FILE_ID="$(extract_json_value "$TMP_DIR/upload.json" 'data.get("fileId")')"
DEK_TOKEN="$(extract_json_value "$TMP_DIR/upload.json" 'data.get("dekToken")')"

if [ -z "$FILE_ID" ] || [ -z "$DEK_TOKEN" ]; then
  echo "  Upload failed:"
  echo "$upload_body" | python3 -m json.tool 2>/dev/null || echo "$upload_body"
  exit 1
fi
echo "  File ID: $FILE_ID"
echo ""

# ---------------------------------------------------------------------------
# Step 2 - Synchronous PII detection
# ---------------------------------------------------------------------------
echo "[2/4] Running synchronous PII detection..."
detect_payload=$(python3 - "$FILE_ID" "$DEK_TOKEN" <<'PY'
import json
import sys

pdf_file_id, dek_token = sys.argv[1:3]
print(json.dumps({
    "pdfFileId": pdf_file_id,
    "dekToken": dek_token,
    "processingMode": "sync",
}))
PY
)

detect_body=$(curl -sS --max-time "$JOB_TIMEOUT" \
  -X POST "${MANAGER_URL}/v1/jobs/detection" \
  -H "Content-Type: application/json" \
  -d "$detect_payload")

printf '%s' "$detect_body" > "$TMP_DIR/detection.json"
check_job_success_or_exit "$TMP_DIR/detection.json" "Detection" "$detect_body"

FDF_FILE_ID="$(extract_json_value "$TMP_DIR/detection.json" 'next((item.get("fileId") for item in (data.get("outputFiles") or []) if item.get("fileCode") == "fdf"), None)')"
FDF_DEK_TOKEN="$(extract_json_value "$TMP_DIR/detection.json" 'next((item.get("dekToken") for item in (data.get("outputFiles") or []) if item.get("fileCode") == "fdf"), None)')"
REDACTIONS_JSON="$(extract_json_value "$TMP_DIR/detection.json" '(data.get("result") or {}).get("redactions")')"

if [ -z "$FDF_FILE_ID" ] || [ -z "$FDF_DEK_TOKEN" ]; then
  echo "  Detection did not return an FDF output file."
  echo "$detect_body" | python3 -m json.tool 2>/dev/null || echo "$detect_body"
  exit 1
fi

printf '%s' "$REDACTIONS_JSON" > "$TMP_DIR/redactions.json"
REDACTION_COUNT="$(extract_json_value "$TMP_DIR/redactions.json" 'len(data)')"

echo "  Detection complete."
echo "  FDF File ID: $FDF_FILE_ID"
echo "  Redactions: $REDACTION_COUNT"
echo ""

# ---------------------------------------------------------------------------
# Step 3 - Synchronous PII redaction
# ---------------------------------------------------------------------------
echo "[3/4] Running synchronous PII redaction..."
redact_payload=$(python3 - "$FILE_ID" "$FDF_FILE_ID" "$DEK_TOKEN" "$FDF_DEK_TOKEN" "$TMP_DIR/redactions.json" <<'PY'
import json
import sys

pdf_file_id, fdf_file_id, pdf_dek_token, fdf_dek_token, redactions_file = sys.argv[1:6]

with open(redactions_file, "r", encoding="utf-8") as handle:
    redactions = json.load(handle)

if not isinstance(redactions, list):
    raise SystemExit("Detection response did not include a redactions array.")

print(json.dumps({
    "pdfFileId": pdf_file_id,
    "fdfFileId": fdf_file_id,
    "pdfDekToken": pdf_dek_token,
    "fdfDekToken": fdf_dek_token,
    "redactionInput": {
        "redactions": redactions,
    },
    "processingMode": "sync",
}))
PY
)

redact_body=$(curl -sS --max-time "$JOB_TIMEOUT" \
  -X POST "${MANAGER_URL}/v1/jobs/redaction" \
  -H "Content-Type: application/json" \
  -d "$redact_payload")

printf '%s' "$redact_body" > "$TMP_DIR/redaction.json"
check_job_success_or_exit "$TMP_DIR/redaction.json" "Redaction" "$redact_body"

REDACTED_FILE_ID="$(extract_json_value "$TMP_DIR/redaction.json" 'next((item.get("fileId") for item in (data.get("outputFiles") or []) if item.get("fileCode") == "pdf"), None)')"
REDACTED_DEK_TOKEN="$(extract_json_value "$TMP_DIR/redaction.json" 'next((item.get("dekToken") for item in (data.get("outputFiles") or []) if item.get("fileCode") == "pdf"), None)')"

if [ -z "$REDACTED_FILE_ID" ] || [ -z "$REDACTED_DEK_TOKEN" ]; then
  echo "  Redaction did not return a downloadable PDF output."
  echo "$redact_body" | python3 -m json.tool 2>/dev/null || echo "$redact_body"
  exit 1
fi

echo "  Redaction complete."
echo "  Redacted file ID: $REDACTED_FILE_ID"
echo ""

# ---------------------------------------------------------------------------
# Step 4 - Download redacted PDF
# ---------------------------------------------------------------------------
echo "[4/4] Downloading redacted PDF..."
http_code=$(curl -sS --max-time "$HTTP_TIMEOUT" -o "$OUTPUT_FILE" -w "%{http_code}" \
  -X POST "${MANAGER_URL}/v1/files/download" \
  -H "Content-Type: application/json" \
  -d "{\"fileId\": \"${REDACTED_FILE_ID}\", \"dekToken\": \"${REDACTED_DEK_TOKEN}\"}")

if [ "$http_code" = "200" ]; then
  echo "  Saved to: $OUTPUT_FILE"
  ls -lh "$OUTPUT_FILE"
else
  echo "  Download failed (HTTP $http_code)"
  cat "$OUTPUT_FILE"
  rm -f "$OUTPUT_FILE"
  exit 1
fi

echo ""
echo "=========================================="
echo " Workflow complete!"
echo "=========================================="
