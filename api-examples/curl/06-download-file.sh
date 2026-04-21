#!/usr/bin/env bash
# =============================================================================
# Step 6: Download a file (original or redacted)
# =============================================================================
# Usage: ./06-download-file.sh <fileId> <dekToken> [output-path]
# =============================================================================
set -euo pipefail

MANAGER_URL="${MANAGER_URL:-http://localhost:9982}"
FILE_ID="${1:?Usage: $0 <fileId> <dekToken> [output-path]}"
DEK_TOKEN="${2:?Usage: $0 <fileId> <dekToken> [output-path]}"
OUTPUT="${3:-downloaded.pdf}"

echo "Downloading file: $FILE_ID"
echo "Saving to: $OUTPUT"
echo ""

http_code=$(curl -s -o "$OUTPUT" -w "%{http_code}" \
  -X POST "${MANAGER_URL}/v1/files/download" \
  -H "Content-Type: application/json" \
  -d "{
    \"fileId\": \"${FILE_ID}\",
    \"dekToken\": \"${DEK_TOKEN}\"
  }")

if [ "$http_code" = "200" ]; then
  echo "File downloaded successfully: $OUTPUT"
  ls -lh "$OUTPUT"
else
  echo "Download failed (HTTP $http_code)."
  cat "$OUTPUT"
  rm -f "$OUTPUT"
  exit 1
fi
