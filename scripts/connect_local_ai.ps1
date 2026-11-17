param([string]$Adb = 'adb')
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskDevices = & $Adb devices
if ($LASTEXITCODE -ne 0) { throw 'Could not contact adb. Install Android platform tools or pass -Adb with its full path.' }
$taskAuthorized = @($taskDevices | Where-Object { $_ -match '^\S+\s+device$' })
if ($taskAuthorized.Count -ne 1) { throw 'Connect exactly one phone by USB, enable USB debugging, and approve this computer on the phone.' }
& $Adb reverse tcp:8787 tcp:8787
if ($LASTEXITCODE -ne 0) { throw 'Could not connect the phone to the local backend.' }
$taskHealth = Invoke-RestMethod -Uri 'http://127.0.0.1:8787/health' -TimeoutSec 5
if (-not $taskHealth.ready) { throw 'Start the configured backend with npm start in server first.' }
$taskApk = Join-Path $taskRoot 'build\app\outputs\flutter-apk\app-debug.apk'
if (-not (Test-Path -LiteralPath $taskApk)) { throw 'Build the local AI debug APK first; see server/README.md.' }
& $Adb install -r $taskApk
if ($LASTEXITCODE -ne 0) { throw 'APK installation failed. Existing app data was not cleared.' }
Write-Output 'Local AI test app installed. Keep this computer and backend running. Open JotIt, sign in with Google, then open AI assistance in the note toolbar.'
