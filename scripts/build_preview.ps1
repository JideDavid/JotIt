param(
    [string]$Flutter = 'flutter',
    [switch]$NoPub
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $root

if (-not $NoPub) {
    & $Flutter pub get
    if ($LASTEXITCODE -ne 0) {
        throw 'Dependency setup did not finish. Resolve the reported setup issue, or use -NoPub only when dependencies are already resolved.'
    }
}

$cache = Join-Path $root '.dart_tool\flutter_build'
if (Test-Path -LiteralPath $cache) {
    Get-ChildItem -LiteralPath $cache -Directory | Where-Object {
        -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint)
    } | ForEach-Object {
        $stamp = Join-Path $_.FullName 'web_entrypoint.stamp'
        if (Test-Path -LiteralPath $stamp -PathType Leaf) {
            Remove-Item -LiteralPath $stamp
        }
    }
}

& $Flutter build web --release --no-pub -t lib/preview.dart --no-web-resources-cdn --no-wasm-dry-run
if ($LASTEXITCODE -ne 0) {
    throw 'Preview compilation failed.'
}

$registrants = Get-ChildItem -LiteralPath $cache -Filter web_plugin_registrant.dart -File -Recurse
$registered = $registrants | Where-Object {
    $source = Get-Content -LiteralPath $_.FullName -Raw
    $source.Contains('AudioplayersPlugin.registerWith') -and
    $source.Contains('FilePickerWeb.registerWith') -and
    $source.Contains('RecordPluginWeb.registerWith')
}
if (-not $registered) {
    throw 'The expected media web plugins were not registered.'
}
