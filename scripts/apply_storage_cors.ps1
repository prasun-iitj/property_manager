# Apply CORS to Firebase Storage bucket (required for web preview/download via SDK).
# Prerequisites: Google Cloud SDK (gsutil) installed and logged in.
#
# Usage:
#   .\scripts\apply_storage_cors.ps1
#   .\scripts\apply_storage_cors.ps1 -Bucket "gs://propertymanagerapp-c4961.firebasestorage.app"

param(
    [string]$Bucket = "gs://propertymanagerapp-c4961.firebasestorage.app"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$corsFile = Join-Path $root "cors.json"

if (-not (Test-Path $corsFile)) {
    Write-Error "cors.json not found at $corsFile"
}

Write-Host "Applying CORS to $Bucket ..."
gsutil cors set $corsFile $Bucket
Write-Host "Done. Hot-restart the Flutter app and try preview/download again."
