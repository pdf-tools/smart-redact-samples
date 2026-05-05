#!/usr/bin/env bash
# =============================================================================
# Step 1: Upload a PDF file to Smart Redact
# =============================================================================
# Usage: ./01-upload-file.sh <path-to-pdf>
# =============================================================================
set -euo pipefail

MANAGER_URL="${MANAGER_URL:-http://localhost:9982}"
FILE_PATH="${1:?Usage: $0 <path-to-pdf>}"

if [ ! -f "$FILE_PATH" ]; then
  echo "Error: File not found: $FILE_PATH"
  exit 1
fi

echo "Uploading: $FILE_PATH"
echo ""

response=$(curl -s -w "\n%{http_code}" \
  -X POST "${MANAGER_URL}/v1/files/upload/fromLocal" \
  -F "file=@${FILE_PATH}")

http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

echo "HTTP Status: $http_code"
echo "Response:"
echo "$body" | python3 -m json.tool 2>/dev/null || echo "$body"

echo ""
echo "Save the 'fileId' and 'dekToken' from the response for the next steps."
