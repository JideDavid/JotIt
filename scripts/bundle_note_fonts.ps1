$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$destination = Join-Path $root 'assets/fonts'
$licenses = Join-Path $destination 'licenses'
New-Item -ItemType Directory -Force -Path $destination, $licenses | Out-Null

$families = [ordered]@{
    'DM Sans' = 'dmsans'
    'Space Grotesk' = 'spacegrotesk'
    'Anton' = 'anton'
    'Archivo Black' = 'archivoblack'
    'Bungee' = 'bungee'
    'Righteous' = 'righteous'
    'DM Serif Display' = 'dmserifdisplay'
    'Playfair Display' = 'playfairdisplay'
    'Lobster' = 'lobster'
    'Caveat' = 'caveat'
}
$cssUrl = 'https://fonts.googleapis.com/css2?family=Anton&family=Archivo+Black&family=Bungee&family=Caveat:wght@400;700&family=DM+Sans:ital,wght@0,400;0,700;1,400;1,700&family=DM+Serif+Display:ital@0;1&family=Lobster&family=Playfair+Display:ital,wght@0,400;0,700;1,400;1,700&family=Righteous&family=Space+Grotesk:wght@400;700&display=swap'
# A legacy user agent requests static TrueType faces for all Flutter platforms.
$css = (Invoke-WebRequest -Uri $cssUrl -UserAgent 'Mozilla/5.0' -TimeoutSec 30).Content
$records = @()
foreach ($face in [regex]::Matches($css, '@font-face\s*\{([^}]+)\}')) {
    $body = $face.Groups[1].Value
    $family = [regex]::Match($body, "font-family:\s*'([^']+)'", 'IgnoreCase').Groups[1].Value
    if (-not $families.Contains($family)) { throw "Unexpected font family: $family" }
    $weight = [int][regex]::Match($body, 'font-weight:\s*(\d+)').Groups[1].Value
    $italic = $body -match 'font-style:\s*italic'
    $url = [regex]::Match($body, 'src:\s*url\((https://fonts\.gstatic\.com/[^)]+\.ttf)\)').Groups[1].Value
    if (-not $url) { throw "No TrueType face for $family" }
    $style = if ($weight -eq 700) { 'Bold' } else { 'Regular' }
    if ($italic) { $style = if ($weight -eq 700) { 'BoldItalic' } else { 'Italic' } }
    $file = "$($family.Replace(' ', ''))-$style.ttf"
    $path = Join-Path $destination $file
    Invoke-WebRequest -Uri $url -OutFile $path -TimeoutSec 30
    $records += [ordered]@{
        family = $family; weight = $weight; italic = $italic; file = $file
        source = $url; sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}
foreach ($family in $families.Keys) {
    $slug = $families[$family]
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/google/fonts/main/ofl/$slug/OFL.txt" -OutFile (Join-Path $licenses "$slug-OFL.txt") -TimeoutSec 30
}
$manifest = [ordered]@{ stylesheet = $cssUrl; fonts = $records }
[IO.File]::WriteAllText((Join-Path $destination 'SOURCES.json'), ($manifest | ConvertTo-Json -Depth 5))
Write-Output "Bundled $($records.Count) font faces across $($families.Count) Google Fonts families."
