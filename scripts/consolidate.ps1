# HAE - consolidate per-session daily files into combined daily file.
# Optional, lazy. Per-session files (raw/<date>__<sid>.jsonl) are first-class storage;
# this just produces a combined raw/<date>.jsonl for downstream consumers that prefer
# one file per day. Source per-session files are kept by default (delete with -Cleanup).
# Run on demand by /hae:status, /hae:classify, /hae:consolidate.

[CmdletBinding()]
param(
    [switch]$Cleanup,    # Delete per-session sources after successful merge
    [string]$Date        # Optional yyyy-MM-dd filter; defaults to all dates with per-session files
)

$ErrorActionPreference = 'Continue'

$haeRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$configPath = Join-Path $haeRoot 'config.json'
$config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json

$rawDir = Join-Path $haeRoot $config.sink.raw_dir
if (-not (Test-Path $rawDir)) { Write-Host "No raw dir."; exit 0 }

# Discover per-session files: <yyyy-MM-dd>__<sid>.jsonl
$pattern = if ($Date) { "$Date`__*.jsonl" } else { '*__*.jsonl' }
$sessionFiles = Get-ChildItem $rawDir -Filter $pattern | Sort-Object Name

if ($sessionFiles.Count -eq 0) { Write-Host "No per-session files to consolidate."; exit 0 }

# Group by date
$byDate = @{}
foreach ($f in $sessionFiles) {
    if ($f.Name -match '^(\d{4}-\d{2}-\d{2})__') {
        $d = $Matches[1]
        if (-not $byDate.ContainsKey($d)) { $byDate[$d] = @() }
        $byDate[$d] += $f
    }
}

$totalRecords = 0
$totalDeleted = 0

foreach ($d in ($byDate.Keys | Sort-Object)) {
    $combined = Join-Path $rawDir "$d.jsonl"
    $records = @()
    foreach ($f in $byDate[$d]) {
        $lines = Get-Content $f.FullName -Encoding UTF8
        foreach ($l in $lines) {
            if (-not [string]::IsNullOrWhiteSpace($l)) { $records += $l }
        }
    }
    # Sort by timestamp
    $sorted = $records | Sort-Object { (($_ | ConvertFrom-Json).ts) }

    # Append (don't overwrite - combined file may already have other-source records like backfill)
    $existing = @{}
    if (Test-Path $combined) {
        Get-Content $combined -Encoding UTF8 | ForEach-Object {
            if (-not [string]::IsNullOrWhiteSpace($_)) {
                try { $existing[(($_ | ConvertFrom-Json).id)] = $true } catch {}
            }
        }
    }

    $appended = 0
    foreach ($r in $sorted) {
        try {
            $id = ($r | ConvertFrom-Json).id
            if (-not $existing.ContainsKey($id)) {
                [System.IO.File]::AppendAllText($combined, $r + "`n", [System.Text.UTF8Encoding]::new($false))
                $existing[$id] = $true
                $appended++
            }
        } catch { }
    }

    Write-Host "$d : $appended records appended to $($combined | Split-Path -Leaf) (sources: $($byDate[$d].Count) per-session files)"
    $totalRecords += $appended

    if ($Cleanup) {
        foreach ($f in $byDate[$d]) {
            Remove-Item $f.FullName -Force
            $totalDeleted++
        }
    }
}

Write-Host ""
Write-Host "Total records consolidated: $totalRecords"
if ($Cleanup) { Write-Host "Per-session sources deleted: $totalDeleted" } else { Write-Host "Per-session sources kept (use -Cleanup to delete after merge)" }
