param(
    [string]$DeploymentDirectory = (Join-Path $PSScriptRoot '../../PFM-City-Deployments/V5'),
    [string]$BaseUrl = ''
)

$ErrorActionPreference = 'Stop'
$deploymentPath = (Resolve-Path -LiteralPath $DeploymentDirectory).Path
$html = Get-Content -LiteralPath (Join-Path $deploymentPath 'PmfCity.html') -Raw
$configMatch = [regex]::Match($html, 'const GODOT_CONFIG = (.+?);')
if (-not $configMatch.Success) { throw 'Missing Godot loader configuration' }
$config = $configMatch.Groups[1].Value | ConvertFrom-Json
$required = @('PmfCity.html', 'PmfCity.js', 'PmfCity.wasm', 'PmfCity.pck',
    'PmfCity.png', 'PmfCity.icon.png', 'PmfCity.apple-touch-icon.png',
    'PmfCity.audio.worklet.js', 'PmfCity.audio.position.worklet.js')

foreach ($name in $required) {
    $file = Get-Item -LiteralPath (Join-Path $deploymentPath $name)
    if ($file.Length -eq 0) { throw "Empty export file: $name" }
    if ($name -in @('PmfCity.pck', 'PmfCity.wasm')) {
        if ($config.fileSizes.$name -ne $file.Length) {
            throw "Loader size mismatch: $name. Re-export all files together."
        }
    }
    $expectedHash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    if ($BaseUrl) {
        $response = Invoke-WebRequest -Uri ($BaseUrl.TrimEnd('/') + '/' + $name) -TimeoutSec 30 -UseBasicParsing
        $bytes = $response.RawContentStream.ToArray()
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try { $actualHash = [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '') }
        finally { $sha.Dispose() }
        if ($actualHash -ne $expectedHash) { throw "Server file differs from V5: $name (stale, incomplete, or mixed deployment)" }
        if ($name -eq 'PmfCity.wasm' -and "$($response.Headers['Content-Type'])" -notmatch 'application/wasm') {
            throw 'Server must serve .wasm with Content-Type: application/wasm'
        }
    }
    Write-Output "PASS: $name ($($file.Length) bytes) SHA256 $expectedHash"
}
Write-Output $(if ($BaseUrl) { 'PASS: all served files match the local export byte-for-byte' } else { 'PASS: local Web export files and loader sizes are consistent' })
