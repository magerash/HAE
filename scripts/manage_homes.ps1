# HAE - manage the weighting.homes list in config.json.
# Subcommands:
#   list                          : print current homes
#   add <path-or-name>            : append to homes
#   remove <path-or-name>         : remove from homes (case-insensitive)
#   auto-detect [-TopN N] [-Apply]: scan prompts/raw/, rank projects by record count
#                                   With -Apply, add top N to homes.
#
# Capture scripts read config.json on every fire - changes take effect immediately,
# no Claude Code restart needed.

[CmdletBinding()]
param(
    [Parameter(Position=0)] [string]$Subcommand = 'list',
    [Parameter(Position=1)] [string]$Target,
    [int]$TopN,
    [int]$MinRecords,
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'

. "$(Split-Path -Parent $PSCommandPath)\_lib.ps1"
$dataRoot = Resolve-HaeDataRoot
$configPath = Join-Path $dataRoot 'config.json'   # operator-private user config (homes lives here, not plugin defaults)
$rawDir = Get-HaeRawDir

function Read-UserConfig {
    if (Test-Path $configPath) {
        try { return Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
    }
    # Bootstrap empty user config if missing
    return [pscustomobject]@{
        haeDataRoot = $null
        weighting = [pscustomobject]@{ homes = @(); project_overrides = [pscustomobject]@{} }
        statusline = [pscustomobject]@{ previous_command = $null }
    }
}
function Write-UserConfig($cfg) {
    $dir = Split-Path -Parent $configPath
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $json = $cfg | ConvertTo-Json -Depth 20
    [System.IO.File]::WriteAllText($configPath, $json, [System.Text.UTF8Encoding]::new($false))
}

$cfg = Read-UserConfig
if (-not $TopN) {
    $TopN = [int]$cfg.weighting.auto_promote.top_n
    if ($TopN -le 0) { $TopN = 3 }
}
if (-not $MinRecords) {
    $MinRecords = [int]$cfg.weighting.auto_promote.min_records
    if ($MinRecords -le 0) { $MinRecords = 100 }
}

$homes = @($cfg.weighting.homes | Where-Object { $_ -ne $null -and -not [string]::IsNullOrWhiteSpace([string]$_) })

switch ($Subcommand.ToLowerInvariant()) {
    'list' {
        Write-Host "Current homes ($($homes.Count)):"
        if ($homes.Count -eq 0) {
            Write-Host "  (none, all captures get other_weight = $($cfg.weighting.other_weight))"
        } else {
            foreach ($h in $homes) {
                $kind = if ($h -match '[\\/]') { 'path' } else { 'name' }
                $line = "  - {0}  [{1}]" -f $h, $kind
                Write-Host $line
            }
        }
        Write-Host ""
        Write-Host "Weights: home=$($cfg.weighting.home_weight)  other=$($cfg.weighting.other_weight)"
        if ($cfg.weighting.project_overrides) {
            $ovr = $cfg.weighting.project_overrides.PSObject.Properties | Where-Object { $_.Name -ne '_example_other_repo' }
            if ($ovr) {
                Write-Host "Per-project overrides:"
                foreach ($o in $ovr) { Write-Host "  - $($o.Name) = $($o.Value)" }
            }
        }
    }

    'add' {
        if ([string]::IsNullOrWhiteSpace($Target)) {
            Write-Error 'Usage: manage_homes add PATH-OR-NAME'
            exit 1
        }
        $tNorm = $Target.TrimEnd('\','/').ToLowerInvariant()
        $existing = $homes | Where-Object { ([string]$_).TrimEnd('\','/').ToLowerInvariant() -eq $tNorm }
        if ($existing) {
            Write-Host "Already present: $Target"
            exit 0
        }
        $homes += $Target
        $cfg.weighting.homes = @($homes)
        Write-UserConfig $cfg
        Write-Host "Added: $Target"
        Write-Host "Homes now: $($homes.Count)"
    }

    'remove' {
        if ([string]::IsNullOrWhiteSpace($Target)) {
            Write-Error 'Usage: manage_homes remove PATH-OR-NAME'
            exit 1
        }
        $tNorm = $Target.TrimEnd('\','/').ToLowerInvariant()
        $newHomes = @($homes | Where-Object { ([string]$_).TrimEnd('\','/').ToLowerInvariant() -ne $tNorm })
        if ($newHomes.Count -eq $homes.Count) {
            Write-Host "Not found: $Target"
            exit 0
        }
        $cfg.weighting.homes = $newHomes
        Write-UserConfig $cfg
        Write-Host "Removed: $Target"
        Write-Host "Homes now: $($newHomes.Count)"
    }

    'auto-detect' {
        if (-not (Test-Path $rawDir)) {
            Write-Host "No raw dir, run captures or backfill first."
            exit 0
        }

        # Group by project basename. Track best-available cwd seen for that project
        # (full path preferred; fall back to null = use basename-match home entry).
        $counts = @{}
        Get-ChildItem $rawDir -Filter '*.jsonl' -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            Get-Content $_.FullName -Encoding UTF8 | ForEach-Object {
                if ([string]::IsNullOrWhiteSpace($_)) { return }
                try {
                    $r = $_ | ConvertFrom-Json
                    $project = [string]$r.project
                    if ([string]::IsNullOrEmpty($project)) { return }
                    if (-not $counts.ContainsKey($project)) {
                        $counts[$project] = @{
                            project  = $project
                            cwd      = $null
                            records  = 0
                            sessions = @{}
                        }
                    }
                    if ($r.cwd -and -not $counts[$project].cwd) {
                        $counts[$project].cwd = [string]$r.cwd
                    }
                    $counts[$project].records++
                    if ($r.session_id) { $counts[$project].sessions[[string]$r.session_id] = $true }
                } catch {}
            }
        }

        if ($counts.Count -eq 0) {
            Write-Host "No records found in $rawDir"
            exit 0
        }

        $ranked = $counts.Values |
            ForEach-Object {
                [pscustomobject]@{
                    project    = $_.project
                    cwd        = $_.cwd
                    home_entry = if ($_.cwd) { $_.cwd } else { $_.project }
                    match_kind = if ($_.cwd) { 'path' } else { 'name' }
                    records    = $_.records
                    sessions   = $_.sessions.Count
                }
            } |
            Where-Object { $_.records -ge $MinRecords } |
            Sort-Object records -Descending

        Write-Host ("Auto-detect: projects with at least {0} records, top {1}:" -f $MinRecords, $TopN)
        $topRanked = @($ranked | Select-Object -First $TopN)
        if ($topRanked.Count -eq 0) {
            Write-Host "  (none meet threshold; lower -MinRecords or capture more)"
            Write-Host ""
            Write-Host "All projects in raw store:"
            $all = $counts.Values |
                ForEach-Object {
                    [pscustomobject]@{ project = $_.project; records = $_.records; sessions = $_.sessions.Count }
                } |
                Sort-Object records -Descending |
                Select-Object -First 10
            $all | Format-Table -AutoSize | Out-String | Write-Host
            exit 0
        }

        $topRanked | Format-Table -AutoSize | Out-String | Write-Host

        if ($Apply) {
            $added = 0
            foreach ($r in $topRanked) {
                $candidate = $r.home_entry
                $cNorm = $candidate.TrimEnd('\','/').ToLowerInvariant()
                $exists = $homes | Where-Object { ([string]$_).TrimEnd('\','/').ToLowerInvariant() -eq $cNorm }
                if (-not $exists) {
                    $homes += $candidate
                    $added++
                    Write-Host ("  + added: {0}  [{1}]" -f $candidate, $r.match_kind)
                }
            }
            if ($added -gt 0) {
                $cfg.weighting.homes = @($homes)
                Write-UserConfig $cfg
                Write-Host "Added $added home(s). Total now: $($homes.Count)"
            } else {
                Write-Host "No additions, all top candidates already in homes."
            }
        } else {
            Write-Host ""
            Write-Host "Re-run with -Apply to add the above to weighting.homes."
        }
    }

    default {
        Write-Error "Unknown subcommand '$Subcommand'. Use: list | add | remove | auto-detect"
        exit 1
    }
}
