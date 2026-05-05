# HAE - status dashboard
# Tallies raw + structured records, profile completeness, backfill state, plugin enable.
# Single source of truth for /hae:status skill.

$ErrorActionPreference = 'SilentlyContinue'

$haeRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$cfg = Get-Content "$haeRoot\config.json" -Raw -Encoding UTF8 | ConvertFrom-Json

# Raw tally - dedupes by record id (per-session file + combined daily file may both contain
# the same record after /hae:consolidate; counting both would double-count).
$rawDir = "$haeRoot\prompts\raw"
$seenIds = @{}
$total = 0
$bySource = @{}
$byEvent  = @{}
$byProject = @{}
$homeCount  = 0
$otherCount = 0
$sessions = @{}
$perSessionFiles = 0
$combinedFiles = 0
$minTs = $null
$maxTs = $null
$promptCharSum = 0
$promptCharCount = 0

if (Test-Path $rawDir) {
    # Process combined files first (newer source of truth from consolidate);
    # per-session files only contribute records not already seen.
    $files = Get-ChildItem $rawDir -Filter '*.jsonl' -ErrorAction SilentlyContinue | Sort-Object {
        if ($_.BaseName -match '^\d{4}-\d{2}-\d{2}__') { 1 } else { 0 }
    }
    foreach ($f in $files) {
        if ($f.BaseName -match '^\d{4}-\d{2}-\d{2}__') { $perSessionFiles++ } else { $combinedFiles++ }
        Get-Content $f.FullName -Encoding UTF8 | ForEach-Object {
            if ([string]::IsNullOrWhiteSpace($_)) { return }
            try {
                $r = $_ | ConvertFrom-Json
                $rid = [string]$r.id
                if ($rid -and $seenIds.ContainsKey($rid)) { return }
                if ($rid) { $seenIds[$rid] = $true }
                $total++
                $src = if ($r.source) { [string]$r.source } else { 'unknown' }
                $bySource[$src] = ($bySource[$src] + 1)
                $evt = [string]$r.event
                $byEvent[$evt] = ($byEvent[$evt] + 1)
                $proj = [string]$r.project
                $byProject[$proj] = ($byProject[$proj] + 1)
                if ($r.is_home_project) { $homeCount++ } else { $otherCount++ }
                if ($r.session_id) { $sessions[[string]$r.session_id] = $true }
                $ts = [DateTime]::Parse($r.ts).ToUniversalTime()
                if (-not $minTs -or $ts -lt $minTs) { $minTs = $ts }
                if (-not $maxTs -or $ts -gt $maxTs) { $maxTs = $ts }
                if ($r.prompt_chars) { $promptCharSum += [int]$r.prompt_chars; $promptCharCount++ }
            } catch {}
        }
    }
}

# Structured
$structDir = "$haeRoot\prompts\structured"
$structCount = 0
if (Test-Path $structDir) {
    Get-ChildItem $structDir -Filter '*.jsonl' -ErrorAction SilentlyContinue | ForEach-Object {
        $structCount += (Get-Content $_.FullName | Measure-Object -Line).Lines
    }
}

# Profile
$profDir = "$haeRoot\profile"
$profFiles = @('paei.json','hexaco.json','custom.json','principles.md','persona.md')

# Backfill state
$bfStatePath = "$haeRoot\state\backfilled_sessions.json"
$bfState = $null
if (Test-Path $bfStatePath) {
    try { $bfState = Get-Content $bfStatePath -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
}

# Plugin enabled?
$pluginEnabled = $false
try {
    $settings = Get-Content "$env:USERPROFILE\.claude\settings.json" -Raw -Encoding UTF8 | ConvertFrom-Json
    $pluginEnabled = $settings.enabledPlugins.'hae@hae-local' -eq $true
} catch {}

# Compose
$capStr = if ($cfg.capture.enabled) { 'ON' } else { 'OFF' }
$lines = @()
$lines += "## HAE status - phase $($cfg.phase) - capture: $capStr"
$lines += ''
$lines += '### Plugin'
$lines += "- enabled: $pluginEnabled (hae@hae-local)"
$lines += "- response capture: $(if ($cfg.capture.include_response) { 'on' } else { 'off' })"
$lines += "- privacy.store_full_paths: $($cfg.privacy.store_full_paths)"
$lines += ''
$lines += '### Homes'
$homes = @($cfg.weighting.homes | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
if ($homes.Count -eq 0) {
    $lines += '- (none) - all captures get other_weight; run /hae:home auto-detect'
} else {
    foreach ($h in $homes) {
        $kind = if ($h -match '[\\/]') { 'path' } else { 'name' }
        $lines += "- $h  [$kind]"
    }
}
$lines += "- weights: home=$($cfg.weighting.home_weight)  other=$($cfg.weighting.other_weight)"
$lines += ''
$lines += '### Raw captures'
if ($total -eq 0) {
    $lines += '- (no records yet)'
} else {
    $lines += "- Date range:     $($minTs.ToString('yyyy-MM-dd HH:mm')) -> $($maxTs.ToString('yyyy-MM-dd HH:mm')) UTC"
    $lines += "- Total:          $total records"
    $bySrcStr = (($bySource.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join '  ')
    $lines += "- By source:      $bySrcStr"
    $byEvtStr = (($byEvent.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join '  ')
    $lines += "- By event:       $byEvtStr"
    $lines += "- Sessions:       $($sessions.Count) distinct"
    $lines += "- Files:          $perSessionFiles per-session, $combinedFiles combined"
    if ($perSessionFiles -gt 0 -and $combinedFiles -eq 0) {
        $lines += "                  (run /hae:consolidate to merge per-session files)"
    }
    $lines += "- Home / Other:   $homeCount / $otherCount"
    if ($promptCharCount -gt 0) {
        $avg = [math]::Round($promptCharSum / $promptCharCount, 0)
        $lines += "- Avg prompt:     $avg chars"
    }
    $lines += '- Top projects:'
    $byProject.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 10 | ForEach-Object {
        $lines += "    $($_.Key) = $($_.Value)"
    }
}
$lines += ''
$lines += '### Structured'
if ($structCount -eq 0) {
    $lines += '- 0 records - run /hae:classify (Phase 3 stub for now)'
} else {
    $lines += "- $structCount records"
}
$lines += ''
$lines += '### Profile'
$lines += '| File           | Exists | Modified         |'
$lines += '|----------------|--------|------------------|'
foreach ($pf in $profFiles) {
    $p = Join-Path $profDir $pf
    if (Test-Path $p) {
        $mod = (Get-Item $p).LastWriteTime.ToString('yyyy-MM-dd HH:mm')
        $lines += ('| {0,-14} | yes    | {1} |' -f $pf, $mod)
    } else {
        $lines += ('| {0,-14} | no     | -                |' -f $pf)
    }
}
$lines += ''
$lines += '### Backfill'
if (-not $bfState) {
    $lines += '- never run - invoke /hae:backfill to import historical sessions (optional)'
} else {
    $lines += "- last run: $($bfState.last_run)"
    $lines += "- sessions imported (lifetime): $($bfState.sessions_count)"
    $lines += "- records imported (lifetime): $($bfState.records_count)"
}
$lines -join "`n" | Write-Host
