#!/usr/bin/env bash
# =============================================================================
# Generate a 32-byte Base64-encoded encryption key for Smart Redact
# =============================================================================
# Usage:
#   ./generate-encryption-key.sh                    # prints the key
#   export ENCRYPTION_KEY=$(./generate-encryption-key.sh)  # sets env var
# =============================================================================
set -euo pipefail

openssl rand -base64 32
