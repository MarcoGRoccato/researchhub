[CmdletBinding()]
param(
    [switch]$NoClean
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Remove-PathIfExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force
    }
}

function Get-EuropeRomeTimeInfo {
    $utcNow = [DateTime]::UtcNow

    # Windows usually uses "W. Europe Standard Time"
    $tzCandidates = @(
        'Europe/Rome',
        'W. Europe Standard Time',
        'Central European Standard Time'
    )

    foreach ($tzId in $tzCandidates) {
        try {
            $tz = [TimeZoneInfo]::FindSystemTimeZoneById($tzId)
            $local = [TimeZoneInfo]::ConvertTimeFromUtc($utcNow, $tz)
            $offset = $tz.GetUtcOffset($utcNow)

            $sign = if ($offset.TotalMinutes -ge 0) { '+' } else { '-' }
            $hh = [Math]::Abs($offset.Hours).ToString('00')
            $mm = [Math]::Abs($offset.Minutes).ToString('00')

            $stamp = "{0} {1}{2}:{3}" -f $local.ToString('yyyy-MM-dd HH:mm:ss'), $sign, $hh, $mm

            return [PSCustomObject]@{
                TimeZoneId    = $tz.Id
                LocalDateTime = $local
                Offset        = $offset
                Timestamp     = $stamp
            }
        }
        catch {
            continue
        }
    }

    throw "Could not resolve Europe/Rome timezone on this system."
}

# Resolve repo root from script path: shared\scripts\render_site.ps1 -> repo root = ..\..
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir '..\..')).Path

if (-not (Test-Path -LiteralPath (Join-Path $repoRoot '.git'))) {
    throw "Repo root not found at $repoRoot (.git missing)."
}

$quartoCmd = Get-Command quarto -ErrorAction SilentlyContinue
if (-not $quartoCmd) {
    throw "Quarto CLI not found in PATH. Open a shell where 'quarto' works and rerun."
}

Set-Location $repoRoot

$rome = Get-EuropeRomeTimeInfo
$buildTimestamp = $rome.Timestamp

Write-Host "Repo root: $repoRoot" -ForegroundColor Cyan
Write-Host "Europe/Rome timestamp: $buildTimestamp (tz id used: $($rome.TimeZoneId))" -ForegroundColor Cyan

if (-not $NoClean) {
    Write-Host "Cleaning .quarto/ and docs/ ..." -ForegroundColor Yellow
    Remove-PathIfExists '.quarto'
    Remove-PathIfExists 'docs'
}

Write-Host "Rendering Quarto site ..." -ForegroundColor Yellow
& quarto render --metadata "build_timestamp=$buildTimestamp"
if ($LASTEXITCODE -ne 0) {
    throw "Quarto render failed with exit code $LASTEXITCODE"
}

$indexHtml = Join-Path $repoRoot 'docs\index.html'
if (-not (Test-Path -LiteralPath $indexHtml)) {
    throw "Rendered index not found: $indexHtml"
}

# Inject/update footer timestamp only on docs/index.html
$html = Get-Content -LiteralPath $indexHtml -Raw

# Remove previous injected footer block if present
$html = [Regex]::Replace(
    $html,
    '(?s)\s*<!-- RH_BUILD_TS_START -->.*?<!-- RH_BUILD_TS_END -->\s*',
    "`r`n"
)

$footerLines = @(
    '<!-- RH_BUILD_TS_START -->'
    '<footer id="rh-build-timestamp-footer" style="margin:2rem auto 1rem auto;max-width:980px;padding:0 1rem;color:#6b7280;font-size:.85rem;font-family:system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;">'
    "  Last build (Europe/Rome): $buildTimestamp"
    '</footer>'
    '<!-- RH_BUILD_TS_END -->'
)
$footerBlock = ($footerLines -join "`r`n")

if ($html -match '</body>') {
    $html = $html -replace '</body>', "`r`n$footerBlock`r`n</body>"
}
else {
    $html = $html + "`r`n$footerBlock`r`n"
}

Set-Content -LiteralPath $indexHtml -Encoding UTF8 $html

Write-Host "Footer timestamp injected into docs/index.html" -ForegroundColor Green
Write-Host "Done." -ForegroundColor Green
