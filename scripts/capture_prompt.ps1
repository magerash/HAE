# HAE - UserPromptSubmit hook
# Direct write to per-session dated JSONL: prompts/raw/<UTC-date>__<sid>.jsonl
# One writer per file (Claude Code is sequential within a session) → no append race,
# no mutex, no spool, no scheduler. Cross-session contention impossible because
# each session has its own filename.
# Designed to never block Claude Code - exits 0 on all errors.

$ErrorActionPreference = 'SilentlyContinue'

try {
    . "$(Split-Path -Parent $PSCommandPath)\_lib.ps1"
    $config = Get-HaeConfig
    if (-not $config -or -not $config.capture -or -not $config.capture.enabled) { exit 0 }

    # Read stdin as raw bytes and decode UTF-8 - independent of console encoding.
    $ms = New-Object System.IO.MemoryStream
    $stdin = [Console]::OpenStandardInput()
    $stdin.CopyTo($ms)
    $bytes = $ms.ToArray()
    $ms.Dispose()
    if ($bytes.Length -eq 0) { exit 0 }
    $payload = [System.Text.Encoding]::UTF8.GetString($bytes)
    if ([string]::IsNullOrWhiteSpace($payload)) { exit 0 }

    $hook = $payload | ConvertFrom-Json
    $prompt = [string]$hook.prompt
    if ([string]::IsNullOrEmpty($prompt)) { exit 0 }

    $maxChars = [int]$config.capture.max_prompt_chars
    if ($prompt.Length -gt $maxChars) {
        $prompt = $prompt.Substring(0, $maxChars) + '...[TRUNCATED]'
    }

    foreach ($pattern in $config.capture.redact_patterns) {
        $prompt = [regex]::Replace($prompt, $pattern, '[REDACTED]')
    }

    $cwd = [string]$hook.cwd
    $transcriptPath = [string]$hook.transcript_path
    $sessionId = [string]$hook.session_id
    $projectName = if ($cwd) { Split-Path $cwd -Leaf } else { 'unknown' }

    # Project weighting - match cwd against homes list (path prefixes or basenames).
    $isHome = $false
    $weight = [double]$config.weighting.other_weight
    if ($cwd) {
        $cwdNorm = $cwd.TrimEnd('\','/').ToLowerInvariant()
        $projNorm = $projectName.ToLowerInvariant()
        foreach ($h in @($config.weighting.homes)) {
            if ($null -eq $h -or [string]::IsNullOrWhiteSpace([string]$h)) { continue }
            $hNorm = ([string]$h).TrimEnd('\','/').ToLowerInvariant()
            if ($hNorm -match '[\\/]') {
                # Path-prefix match
                if ($cwdNorm -eq $hNorm -or $cwdNorm.StartsWith($hNorm + '\') -or $cwdNorm.StartsWith($hNorm + '/')) {
                    $isHome = $true; break
                }
            } else {
                # Basename match
                if ($projNorm -eq $hNorm) { $isHome = $true; break }
            }
        }
        if ($isHome) {
            $weight = [double]$config.weighting.home_weight
        } elseif ($config.weighting.project_overrides -and ($config.weighting.project_overrides.PSObject.Properties.Name -contains $projectName)) {
            $weight = [double]$config.weighting.project_overrides.$projectName
        }
    }

    # Path PII
    $storeFull = $false
    if ($config.privacy -and $config.privacy.store_full_paths) { $storeFull = $true }
    $segs = 2
    if ($config.privacy -and $config.privacy.path_segments_kept) { $segs = [int]$config.privacy.path_segments_kept }

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

    $record = [ordered]@{
        id              = [guid]::NewGuid().ToString()
        ts              = (Get-Date).ToUniversalTime().ToString('o')
        event           = 'UserPromptSubmit'
        session_id      = $sessionId
        transcript_path = if ($storeFull) { $transcriptPath } else { $null }
        transcript_hash = Get-PathHash $transcriptPath
        transcript_tail = Get-PathTail $transcriptPath $segs
        cwd             = if ($storeFull) { $cwd } else { $null }
        cwd_hash        = Get-PathHash $cwd
        cwd_tail        = Get-PathTail $cwd $segs
        project         = $projectName
        is_home_project = $isHome
        project_weight  = $weight
        permission      = [string]$hook.permission_mode
        prompt          = $prompt
        prompt_chars    = $prompt.Length
        hae_phase       = [int]$config.phase
        source          = 'hook'
    }

    $json = $record | ConvertTo-Json -Compress -Depth 10

    $rawDir = Get-HaeRawDir
    if (-not (Test-Path $rawDir)) { New-Item -ItemType Directory -Path $rawDir -Force | Out-Null }

    # Per-session dated file - single writer per file, no contention.
    $dateStamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd')
    $sidShort = if ($sessionId) { $sessionId.Substring(0, [Math]::Min(8, $sessionId.Length)) } else { 'noses' }
    $file = Join-Path $rawDir "$dateStamp`__$sidShort.jsonl"

    [System.IO.File]::AppendAllText($file, $json + "`n", [System.Text.UTF8Encoding]::new($false))
} catch {
    # Never block Claude Code on capture failure.
}

exit 0
