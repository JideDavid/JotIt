param(
    [string]$AiUrl = '',
    [string]$Flutter = 'C:\dev\flutter\bin\flutter.bat'
)
$ErrorActionPreference = 'Stop'
if (-not $AiUrl) {
    Write-Host 'Building with Firebase AI Logic and production App Check. No Gemini key or backend URL is embedded.'
    Push-Location -LiteralPath (Split-Path -Parent $PSScriptRoot)
    try {
        & $Flutter build apk --release --no-pub
        if ($LASTEXITCODE -ne 0) { throw 'Release build failed.' }
    } finally { Pop-Location }
    return
}
$endpoint = $null
if (-not [Uri]::TryCreate($AiUrl, [UriKind]::Absolute, [ref]$endpoint) -or
    $endpoint.Scheme -ne 'https' -or $endpoint.IsLoopback -or
    $endpoint.UserInfo -or $endpoint.Query -or $endpoint.Fragment -or
    $endpoint.AbsolutePath -ne '/v1/assist') {
    throw 'Use the deployed HTTPS URL ending in /v1/assist, without credentials, query parameters or fragments.'
}
$healthUrl = $endpoint.GetLeftPart([UriPartial]::Authority) + '/health'
$health = Invoke-RestMethod -Uri $healthUrl -TimeoutSec 120
if ($health.ready -ne $true -or $health.protocolVersion -ne 2) {
    throw 'The backend is not ready or does not support the current note editor protocol.'
}
# Confirm public callers cannot generate without Firebase authentication.
$authStatus = 0
try {
    $response = Invoke-WebRequest -Uri $endpoint.AbsoluteUri -Method Post -ContentType 'application/json' -Body '{}' -UseBasicParsing -TimeoutSec 30
    $authStatus = [int]$response.StatusCode
} catch {
    if ($null -eq $_.Exception.Response) { throw }
    $authStatus = [int]$_.Exception.Response.StatusCode
}
if ($authStatus -ne 401) { throw 'Backend authentication check failed; expected HTTP 401 without a sign-in token.' }
Write-Host 'Backend readiness and Firebase authentication checks passed.'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectRoot
try {
    & $Flutter build apk --release --no-pub "--dart-define=JOTIT_AI_URL=$($endpoint.AbsoluteUri)"
    if ($LASTEXITCODE -ne 0) { throw 'Release build failed.' }
    Write-Host "AI-enabled APK: $projectRoot\build\app\outputs\flutter-apk\app-release.apk"
} finally { Pop-Location }
