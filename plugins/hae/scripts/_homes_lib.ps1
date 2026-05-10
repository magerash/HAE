# HAE - shared homes/auto-promote helper library
# Dot-source from any HAE script:
#   . "$(Split-Path -Parent $PSCommandPath)\_homes_lib.ps1"
#
# Provides:
#   Get-ProjectRecordCounts   : scan raw dir, return hashtable project -> {records, sessions, cwd, cwd_tail, home_entry, match_kind}
#   Test-AutoPromoteThreshold : return list of qualifying projects per config thresholds
#   Invoke-AutoPromote        : write additions to user config + audit log; idempotent
#   Read-HaeUserConfig        : load operator-private user config (creates skeleton if missing)
#   Write-HaeUserConfig       : persist user config back to disk (UTF-8 no BOM)
#
# Design contract:
#   - Helpers do NOT modify cached merged config (Get-HaeConfig). User config writes only.
#   - Read-HaeUserConfig is non-destructive: returns minimal skeleton when file missing.
#   - All file IO swallows errors and returns sensible defaults to keep callers safe.

# Requires _lib.ps1 to be dot-sourced first (callers do this).

function Read-HaeUserConfig {
    $configPath = Join-Path (Resolve-HaeDataRoot) 'config.json'
    if (Test-Path $configPath) {
        try { return Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
    }
    return [pscustomobject]@{
        haeDataRoot = $null
        weighting = [pscustomobject]@{ homes = @(); project_overrides = [pscustomobject]@{} }
        statusline = [pscustomobject]@{ previous_command = $null }
    }
}

function Write-HaeUserConfig($cfg) {
    $configPath = Join-Path (Resolve-HaeDataRoot) 'config.json'
    $dir = Split-Path -Parent $configPath
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $json = $cfg | ConvertTo-Json -Depth 20
    [System.IO.File]::WriteAllText($configPath, $json, [System.Text.UTF8Encoding]::new($false))
}

function Get-ProjectRecordCounts {
    # Scan raw dir, group by project basename. Track best-available cwd seen for that project.
    # Returns hashtable keyed by project name. Each entry has records, sessions count, home_entry,
    # match_kind (path|name).
    $rawDir = Get-HaeRawDir
    $counts = @{}
    if (-not (Test-Path $rawDir)) { return $counts }

    Get-ChildItem $rawDir -Filter '*.jsonl' -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        Get-Content $_.FullName -Encoding UTF8 -ErrorAction SilentlyContinue | ForEach-Object {
            if ([string]::IsNullOrWhiteSpace($_)) { return }
            try {
                $r = $_ | ConvertFrom-Json
                $project = [string]$r.project
                if ([string]::IsNullOrEmpty($project)) { return }
                if (-not $counts.ContainsKey($project)) {
                    $counts[$project] = @{
                        project    = $project
                        cwd        = $null
                        cwd_tail   = $null
                        records    = 0
                        sessions   = @{}
                    }
                }
                if ($r.cwd -and -not $counts[$project].cwd) {
                    $counts[$project].cwd = [string]$r.cwd
                }
                if ($r.cwd_tail -and -not $counts[$project].cwd_tail) {
                    $counts[$project].cwd_tail = [string]$r.cwd_tail
                }
                $counts[$project].records++
                if ($r.session_id) { $counts[$project].sessions[[string]$r.session_id] = $true }
            } catch {}
        }
    }
    return $counts
}

function Test-AutoPromoteThreshold {
    # Returns list of project candidates that:
    #   - have records >= MinRecords (from cfg.weighting.auto_promote.min_records, default 100)
    #   - are NOT already in user weighting.homes (case-insensitive, trim trailing slashes)
    #   - top N (from cfg.weighting.auto_promote.top_n, default 3)
    #
    # Each candidate: { project, cwd, home_entry, match_kind, records, sessions }
    # Returns empty array when auto_promote disabled or no qualifying projects.
    param(
        [Parameter()] $MergedCfg = (Get-HaeConfig),
        [Parameter()] $UserCfg = (Read-HaeUserConfig),
        [int]$MinRecords,
        [int]$TopN
    )

    $ap = $MergedCfg.weighting.auto_promote
    if (-not $ap -or $ap.enabled -ne $true) { return @() }

    if (-not $MinRecords) {
        $MinRecords = [int]$ap.min_records
        if ($MinRecords -le 0) { $MinRecords = 100 }
    }
    if (-not $TopN) {
        $TopN = [int]$ap.top_n
        if ($TopN -le 0) { $TopN = 3 }
    }

    $existingHomes = @($UserCfg.weighting.homes | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    $existingNorm = @($existingHomes | ForEach-Object { ([string]$_).TrimEnd('\','/').ToLowerInvariant() })

    $counts = Get-ProjectRecordCounts
    if ($counts.Count -eq 0) { return @() }

    $ranked = $counts.Values |
        ForEach-Object {
            $entry = if ($_.cwd) { $_.cwd } else { $_.project }
            [pscustomobject]@{
                project    = $_.project
                cwd        = if ($_.cwd) { $_.cwd } else { $null }
                cwd_tail   = $_.cwd_tail
                home_entry = $entry
                match_kind = if ($_.cwd) { 'path' } else { 'name' }
                records    = $_.records
                sessions   = $_.sessions.Count
            }
        } |
        Where-Object { $_.records -ge $MinRecords } |
        Where-Object {
            $norm = ([string]$_.home_entry).TrimEnd('\','/').ToLowerInvariant()
            -not ($existingNorm -contains $norm)
        } |
        Sort-Object records -Descending |
        Select-Object -First $TopN

    return @($ranked)
}

function Invoke-AutoPromote {
    # Apply candidates to user config + write audit log. Idempotent (skips already-present entries).
    # Returns count of projects added.
    #
    # Audit log line format (one JSON per line):
    #   {"ts":"...","project":"...","home_entry":"...","match_kind":"...","records":N,"sessions":N,"trigger":"..."}
    param(
        [Parameter(Mandatory=$true)] $Candidates,
        [string]$Trigger = 'classify'
    )

    $candList = @($Candidates | Where-Object { $_ -and $_.home_entry })
    if ($candList.Count -eq 0) { return 0 }

    $userCfg = Read-HaeUserConfig
    $homes = @($userCfg.weighting.homes | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    $existingNorm = @($homes | ForEach-Object { ([string]$_).TrimEnd('\','/').ToLowerInvariant() })

    $stateDir = Get-HaeStateDir
    if (-not (Test-Path $stateDir)) { New-Item -ItemType Directory -Path $stateDir -Force | Out-Null }
    $logPath = Join-Path $stateDir 'auto_promote.log'

    $added = 0
    foreach ($c in $candList) {
        $norm = ([string]$c.home_entry).TrimEnd('\','/').ToLowerInvariant()
        if ($existingNorm -contains $norm) { continue }
        $homes += $c.home_entry
        $existingNorm += $norm
        $added++

        $logLine = [pscustomobject]@{
            ts         = (Get-Date).ToUniversalTime().ToString('o')
            project    = $c.project
            home_entry = $c.home_entry
            match_kind = $c.match_kind
            records    = $c.records
            sessions   = $c.sessions
            trigger    = $Trigger
        } | ConvertTo-Json -Compress
        try { [System.IO.File]::AppendAllText($logPath, $logLine + "`n", [System.Text.UTF8Encoding]::new($false)) } catch {}
    }

    if ($added -gt 0) {
        $userCfg.weighting.homes = @($homes)
        Write-HaeUserConfig $userCfg
    }

    return $added
}
