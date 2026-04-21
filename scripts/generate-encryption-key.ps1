# =============================================================================
# Generate a 32-byte Base64-encoded encryption key for Smart Redact (PowerShell)
# =============================================================================
# Usage:
#   .\generate-encryption-key.ps1                       # prints the key
#   $env:ENCRYPTION_KEY = (.\generate-encryption-key.ps1)  # sets env var
# =============================================================================
$ErrorActionPreference = 'Stop'

$bytes = New-Object byte[] 32
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
try {
    $rng.GetBytes($bytes)
} finally {
    $rng.Dispose()
}
[Convert]::ToBase64String($bytes)
