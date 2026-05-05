# HAE - one-shot backfill from existing Claude Code transcripts.
# OPTIONAL. User runs once; tracks processed sessions in state/backfilled_sessions.json
# so subsequent runs are no-op (or only pick up new sessions).
#
# Walks ~/.claude/projects/<encoded-cwd>/<session-uuid>.jsonl and produces records
# in the same shape as the live capture. Source = "backfill". Records are written
# to per-session files prompts/raw/<date>__<sid8>.jsonl just like live capture.

[CmdletBinding()]
param(
    [string]$ProjectsRoot = (Join-Path $env:USERPROFILE '.claude\projects'),
    [int]$MaxSessions = 0,        # 0 = no limit
    [switch]$DryRun,
    [switch]$ForceReprocess       # Ignore state file; reprocess all sessions
)

$ErrorActionPreference = 'Continue'

$haeRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$configPath = Join-Path $haeRoot 'config.json'
$config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json

if (-not (Test-Path $ProjectsRoot)) {
    Write-Error "Claude projects dir not found: $ProjectsRoot"
    exit 1
}

$rawDir = Join-Path $haeRoot $config.sink.raw_dir
if (-not (Test-Path $rawDir)) { New-Item -ItemType Directory -Path $rawDir -Force | Out-Null }

$stateDir = Join-Path $haeRoot 'state'
if (-not (Test-Path $stateDir)) { New-Item -ItemType Directory -Path $stateDir -Force | Out-Null }
$statePath = Join-Path $stateDir 'backfilled_sessions.json'

$state = @{ processed = @{}; last_run = $null; sessions_count = 0; records_count = 0 }
if ((Test-Path $statePath) -and (-not $ForceReprocess)) {
    try {
        $loaded = Get-Content $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($loaded.processed) {
            $state.processed = @{}
            foreach ($p in $loaded.processed.PSObject.Properties) { $state.processed[$p.Name] = $p.Value }
        }
        if ($loaded.sessions_count) { $state.sessions_count = [int]$loaded.sessions_count }
        if ($loaded.records_count) { $state.records_count = [int]$loaded.records_count }
    } catch {}
}

# Helper functions
function Get-PathHash([string]$p) {
    if ([string]::IsNullOrEmpty($p)) { return $null }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $b = [System.Text.Encoding]::UTF8.GetBytes($p.ToLowerInvariant())
    return ([System.BitConverter]::ToString($sha.ComputeHash($b)).Replace('-','').Substring(0,16)).ToLowerInvariant()
}
function Get-PathTail([string]$p, [int]$n) {
    if ([string]::IsNullOrEmpty($p)) { return $null }
    $parts = $p -split '[\\/]+' | Where-Object { $_ -ne '' }
    if ($parts.Count -le $n) { return ($parts -join '/') }
    return ($parts[-$n..-1] -join '/')
}

# Decode Anthropic's project-dir slug back to a usable cwd guess.
# Format observed: -C--Projects-My-habits  →  C:\Projects\My habits
function Decode-ProjectDir([string]$slug) {
    if ([string]::IsNullOrEmpty($slug)) { return $null }
    if ($slug.StartsWith('-')) { $slug = $slug.Substring(1) }
    # First segment "C-" or "D-" becomes "C:"
    if ($slug -match '^([A-Za-z])-(.*)$') {
        $drive = $Matches[1]
        $rest = $Matches[2]
        return ($drive + ':\' + ($rest -replace '-', '\'))
    }
    return ($slug -replace '-', '\')
}

# Walk projects
$sessionFiles = Get-ChildItem $ProjectsRoot -Recurse -Filter '*.jsonl' -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.jsonl$' }

Write-Host "Discovered $($sessionFiles.Count) session transcripts under $ProjectsRoot"

$storeFull = $false
if ($config.privacy -and $config.privacy.store_full_paths) { $storeFull = $true }
$segs = 2
if ($config.privacy -and $config.privacy.path_segments_kept) { $segs = [int]$config.privacy.path_segments_kept }

$sessionsThisRun = 0
$recordsThisRun = 0
$sessionsSkipped = 0

foreach ($sf in $sessionFiles) {
    $sid = $sf.BaseName
    if ($state.processed.ContainsKey($sid)) { $sessionsSkipped++; continue }
    if ($MaxSessions -gt 0 -and $sessionsThisRun -ge $MaxSessions) { break }

    $projectSlug = $sf.Directory.Name
    $cwdGuess = Decode-ProjectDir $projectSlug
    $projectName = if ($cwdGuess) { Split-Path $cwdGuess -Leaf } else { $projectSlug }

    # Project weighting - tries 3 match strategies because Decode-ProjectDir is lossy
    # (slug uses '-' for both '\' and ' ', so 'C:\Projects\My habits' becomes
    # ambiguous '-C--Projects-My-habits').
    $isHome = $false
    $weight = [double]$config.weighting.other_weight
    $cwdNorm = if ($cwdGuess) { $cwdGuess.TrimEnd('\','/').ToLowerInvariant() } else { '' }
    $projNorm = $projectName.ToLowerInvariant()
    $slugNorm = $projectSlug.ToLowerInvariant()

    foreach ($h in @($config.weighting.homes)) {
        if ($null -eq $h -or [string]::IsNullOrWhiteSpace([string]$h)) { continue }
        $hStr = [string]$h
        $hNorm = $hStr.TrimEnd('\','/').ToLowerInvariant()
        if ($hStr -match '[\\/]') {
            # 1. Direct path-prefix match against decoded cwd (works when path has no spaces)
            if ($cwdNorm -and ($cwdNorm -eq $hNorm -or $cwdNorm.StartsWith($hNorm + '\') -or $cwdNorm.StartsWith($hNorm + '/'))) {
                $isHome = $true; break
            }
            # 2. Slug-form match: encode home path the way Anthropic does (':' '\' '/' ' ' all -> '-')
            #    Real slugs have NO leading dash (e.g. 'C--Projects-My-habits' for 'C:\Projects\My habits')
            $hSlug = ($hNorm -replace '[:\\/ ]', '-')
            if ($slugNorm -eq $hSlug -or $slugNorm.StartsWith($hSlug + '-')) {
                $isHome = $true; break
            }
        } else {
            # 3. Basename match
            if ($projNorm -eq $hNorm) { $isHome = $true; break }
        }
    }
    if ($isHome) {
        $weight = [double]$config.weighting.home_weight
    } elseif ($config.weighting.project_overrides -and ($config.weighting.project_overrides.PSObject.Properties.Name -contains $projectName)) {
        $weight = [double]$config.weighting.project_overrides.$projectName
    }

    $sessionRecords = @()
    $linesRead = 0
    Get-Content $sf.FullName -Encoding UTF8 | ForEach-Object {
        $linesRead++
        if ([string]::IsNullOrWhiteSpace($_)) { return }
        try {
            $entry = $_ | ConvertFrom-Json
        } catch { return }

        $msgType = $null
        $text = $null
        $ts = $entry.timestamp
        if ($entry.type -eq 'user' -or $entry.message.role -eq 'user') {
            $msgType = 'UserPromptSubmit'
            $c = $entry.message.content
            if ($c -is [string]) { $text = $c }
            elseif ($c -is [array]) {
                $parts = @()
                foreach ($p in $c) {
                    if ($p.type -eq 'text' -and $p.text) { $parts += $p.text }
                }
                $text = ($parts -join "`n")
            }
        } elseif ($entry.type -eq 'assistant' -or $entry.message.role -eq 'assistant') {
            if (-not $config.capture.include_response) { return }
            $msgType = 'Stop'
            $c = $entry.message.content
            if ($c -is [string]) { $text = $c }
            elseif ($c -is [array]) {
                $parts = @()
                foreach ($p in $c) {
                    if ($p.type -eq 'text' -and $p.text) { $parts += $p.text }
                }
                $text = ($parts -join "`n")
            }
        }
        if (-not $msgType -or [string]::IsNullOrEmpty($text)) { return }

        $maxChars = [int]$config.capture.max_prompt_chars
        if ($text.Length -gt $maxChars) { $text = $text.Substring(0, $maxChars) + '...[TRUNCATED]' }
        foreach ($pattern in $config.capture.redact_patterns) {
            $text = [regex]::Replace($text, $pattern, '[REDACTED]')
        }

        $tsString = if ($ts) { $ts } else { (Get-Date).ToUniversalTime().ToString('o') }

        $rec = [ordered]@{
            id              = [guid]::NewGuid().ToString()
            ts              = $tsString
            event           = $msgType
            session_id      = $sid
            transcript_path = if ($storeFull) { $sf.FullName } else { $null }
            transcript_hash = Get-PathHash $sf.FullName
            transcript_tail = Get-PathTail $sf.FullName $segs
            cwd             = if ($storeFull) { $cwdGuess } else { $null }
            cwd_hash        = Get-PathHash $cwdGuess
            cwd_tail        = Get-PathTail $cwdGuess $segs
            project         = $projectName
            is_home_project = $isHome
            project_weight  = $weight
            hae_phase       = [int]$config.phase
            source          = 'backfill'
        }
        if ($msgType -eq 'UserPromptSubmit') {
            $rec.prompt = $text
            $rec.prompt_chars = $text.Length
        } else {
            $rec.response = $text
            $rec.response_chars = $text.Length
        }
        $sessionRecords += $rec
    }

    if ($sessionRecords.Count -eq 0) {
        $state.processed[$sid] = @{ ts = (Get-Date).ToUniversalTime().ToString('o'); records = 0 }
        continue
    }

    if ($DryRun) {
        Write-Host "[DRY] $sid : $($sessionRecords.Count) records would be written ($projectName)"
        $sessionsThisRun++
        continue
    }

    # Write to per-session file (group by record date in case session spanned UTC boundary)
    foreach ($r in $sessionRecords) {
        try {
            $recDate = ([DateTime]::Parse($r.ts)).ToUniversalTime().ToString('yyyy-MM-dd')
        } catch {
            $recDate = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd')
        }
        $sidShort = $sid.Substring(0, 8)
        $outFile = Join-Path $rawDir "$recDate`__bf-$sidShort.jsonl"
        $outJson = $r | ConvertTo-Json -Compress -Depth 10
        [System.IO.File]::AppendAllText($outFile, $outJson + "`n", [System.Text.UTF8Encoding]::new($false))
    }

    $state.processed[$sid] = @{ ts = (Get-Date).ToUniversalTime().ToString('o'); records = $sessionRecords.Count; project = $projectName }
    $sessionsThisRun++
    $recordsThisRun += $sessionRecords.Count
    Write-Host "$sid : $($sessionRecords.Count) records ($projectName)"
}

if (-not $DryRun) {
    $state.last_run = (Get-Date).ToUniversalTime().ToString('o')
    $state.sessions_count = $state.sessions_count + $sessionsThisRun
    $state.records_count = $state.records_count + $recordsThisRun
    $stateJson = $state | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($statePath, $stateJson, [System.Text.UTF8Encoding]::new($false))
}

Write-Host ""
Write-Host "Backfill summary"
Write-Host "  Sessions processed this run: $sessionsThisRun"
Write-Host "  Sessions skipped (already done): $sessionsSkipped"
Write-Host "  Records written: $recordsThisRun"
Write-Host "  Total sessions backfilled (lifetime): $($state.sessions_count)"
Write-Host "  Total records backfilled (lifetime):  $($state.records_count)"
if ($DryRun) { Write-Host "  DRY RUN - no files written, no state updated" }
