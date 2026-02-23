param()

$ErrorActionPreference = 'Stop'

# Config
$MaxSizeBytes = 5MB

# Get repo root (absolute path)
$RepoRoot = (git rev-parse --show-toplevel).Trim()
if (-not $RepoRoot) {
    Write-Host 'ERROR: Cannot determine Git repository root.' -ForegroundColor Red
    exit 1
}

# Staged files only: Added / Copied / Modified / Renamed
$StagedFiles = git diff --cached --name-only --diff-filter=ACMR
if (-not $StagedFiles) {
    exit 0
}

# Patterns (case-insensitive)
$BlockedDirRegex = '(^|/)(data|raw_data|processed_data|outputs|output|temp|tmp|cache|caches|results|analysis_data|input_data|derived_data|intermediate|exports?|archives?)($|/)'
$BlockedExtRegex = '\.(csv|tsv|tab|txt|xlsx|xls|xlsm|xlsb|xltx|xltm|xlam|ods|sqlite|sqlite3|db|mdb|accdb|sav|zsav|por|dta|sas7bdat|xpt|rds|rda|rdata|feather|parquet|arrow|fst|pkl|pickle|joblib|npy|npz|mat|h5|hdf5|edf|bdf|gdf|fif|set|fdt|vhdr|vmrk|eeg|cnt|xdf|mff|egi|acq|zip|7z|rar|tar|gz|bz2|xz|tgz|env|pem|p12|key)$'

$Violations = New-Object System.Collections.Generic.List[string]

foreach ($relPathRaw in $StagedFiles) {
    if ([string]::IsNullOrWhiteSpace($relPathRaw)) { continue }

    # Git returns forward slashes; normalize and keep a forward-slash version for regex checks
    $relPathForward = ($relPathRaw -replace '\\','/').Trim()
    $relPathWin = $relPathForward -replace '/', '\'
    $fullPath = Join-Path $RepoRoot $relPathWin

    # Allow docs/* for website publishing assets (but still size-check)
    $isInDocs = $relPathForward -imatch '^docs/'

    if (-not $isInDocs) {
        if ($relPathForward -imatch $BlockedDirRegex) {
            $Violations.Add("Blocked path (data-like directory): $relPathForward")
            continue
        }

        if ($relPathForward -imatch $BlockedExtRegex) {
            $Violations.Add("Blocked file type: $relPathForward")
            continue
        }
    }

    # Size check (skip if file missing in worktree, e.g., edge cases)
    if (Test-Path -LiteralPath $fullPath) {
        try {
            $len = (Get-Item -LiteralPath $fullPath).Length
            if ($len -gt $MaxSizeBytes -and -not $isInDocs) {
                $Violations.Add("Blocked large file (>5MB): $relPathForward ($len bytes)")
                continue
            }
        } catch {
            $Violations.Add("Could not read file size: $relPathForward")
            continue
        }
    }
}

if ($Violations.Count -gt 0) {
    Write-Host ''
    Write-Host '----------------------------------------' -ForegroundColor Red
    Write-Host 'Commit blocked by ResearchHub pre-commit hook.' -ForegroundColor Red
    Write-Host 'Reason(s):' -ForegroundColor Yellow
    foreach ($v in $Violations) {
        Write-Host " - $v" -ForegroundColor Yellow
    }
    Write-Host '----------------------------------------' -ForegroundColor Red
    Write-Host 'Move data outside the repo (e.g., F:\ResearchHub_Data).' -ForegroundColor Cyan
    Write-Host ''
    exit 1
}

exit 0

