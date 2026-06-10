$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$source = Join-Path $repoRoot 'third_party\telephony'
$target = Join-Path $env:LOCALAPPDATA 'Pub\Cache\hosted\pub.dev\telephony-0.2.0'

if (-not (Test-Path $source)) {
    throw "Vendored telephony source not found at $source"
}

if (-not (Test-Path $target)) {
    throw "Hosted telephony package not found at $target. Run 'flutter pub get' first."
}

Copy-Item -Path (Join-Path $source 'android\build.gradle') -Destination (Join-Path $target 'android\build.gradle') -Force
Copy-Item -Path (Join-Path $source 'android\src\main\AndroidManifest.xml') -Destination (Join-Path $target 'android\src\main\AndroidManifest.xml') -Force

Write-Host "Patched telephony Android files in pub cache: $target"
