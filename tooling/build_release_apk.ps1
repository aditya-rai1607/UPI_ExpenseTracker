$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot
try {
    & powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'sync_telephony_patch.ps1')
    flutter build apk --release
}
finally {
    Pop-Location
}
