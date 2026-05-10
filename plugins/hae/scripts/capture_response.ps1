# HAE - Stop hook (assistant response capture)
# Direct write to per-session dated JSONL. Reads transcript tail inline -
# bounded by 50 lines, sub-50ms even on slow disks. No cross-session contention
# because each session has its own filename.
# Designed to never block Claude Code - exits 0 on all errors.

$ErrorActionPreference = 'SilentlyContinue'

try {
    . "$(Split-Path -Parent $PSCommandPath)\_lib.ps1"
    $config = Get-HaeConfig
    if (-not $config -or -not $config.capture -or -not $config.capture.enabled) { exit 0 }

    # Two write modes:
    #   - include_response=true  : full record w/ response text + tokens (privacy-permitting)
    #   - include_response=false + include_tokens=true (default v0.6.0+): slim cost-record (tokens + meta only, NO response text)
    #   - include_response=false + include_tokens=false : skip entirely
    $writeMode = 'skip'
    if ($config.capture.include_response) {
        $writeMode = 'full'
    } elseif ($null -eq $config.capture.include_tokens -or $config.capture.include_tokens -eq $true) {
        $writeMode = 'tokens'
    }
    if ($writeMode -eq 'skip') { exit 0 }

    $ms = New-Object System.IO.MemoryStream
    $stdin = [Console]::OpenStandardInput()
    $stdin.CopyTo($ms)
    $bytes = $ms.ToArray()
    $ms.Dispose()
    if ($bytes.Length -eq 0) { exit 0 }
    $payload = [System.Text.Encoding]::UTF8.GetString($bytes)
    if ([string]::IsNullOrWhiteSpace($payload)) { exit 0 }

    $hook = $payload | ConvertFrom-Json
    $transcriptPath = [string]$hook.transcript_path
    $sessionId = [string]$hook.session_id
    if ([string]::IsNullOrEmpty($transcriptPath) -or -not (Test-Path $transcriptPath)) { exit 0 }

    # Tail-bounded transcript read - last 50 lines only.
    # Also extracts usage + model from the LAST assistant record that has them
    # (per H18 research 2026-05-10: every assistant API response carries message.usage).
    $tail = Get-Content $transcriptPath -Tail 50 -Encoding UTF8
    $assistantText = $null
    $tokensIn = $null
    $tokensOut = $null
    $tokensCacheRead = $null
    $tokensCacheCreate = $null
    $modelId = $null
    foreach ($line in $tail) {
        try {
            $entry = $line | ConvertFrom-Json
            if ($entry.type -eq 'assistant' -or $entry.role -eq 'assistant') {
                $content = $entry.message.content
                if ($content -is [array]) {
                    $textParts = @()
                    foreach ($c in $content) {
                        if ($c.type -eq 'text' -and $c.text) { $textParts += $c.text }
                    }
                    if ($textParts.Count -gt 0) { $assistantText = ($textParts -join "`n") }
                } elseif ($content -is [string]) {
                    $assistantText = $content
                }
                # H18: extract usage + model when present (last wins; chronological tail order)
                try {
                    $u = $entry.message.usage
                    if ($null -ne $u) {
                        if ($null -ne $u.input_tokens)               { $tokensIn          = [int]$u.input_tokens }
                        if ($null -ne $u.output_tokens)              { $tokensOut         = [int]$u.output_tokens }
                        if ($null -ne $u.cache_read_input_tokens)    { $tokensCacheRead   = [int]$u.cache_read_input_tokens }
                        if ($null -ne $u.cache_creation_input_tokens){ $tokensCacheCreate = [int]$u.cache_creation_input_tokens }
                    }
                    $m = $entry.message.model
                    if (-not [string]::IsNullOrWhiteSpace([string]$m)) { $modelId = [string]$m }
                } catch { }
            }
        } catch { continue }
    }
    # In tokens-only mode, response text not required - exit only if also no token data
    if ($writeMode -eq 'tokens') {
        if ($null -eq $tokensIn -and $null -eq $tokensOut -and $null -eq $tokensCacheCreate) { exit 0 }
        $assistantText = $null
    } else {
        if ([string]::IsNullOrEmpty($assistantText)) { exit 0 }

        $maxChars = [int]$config.capture.max_prompt_chars
        if ($assistantText.Length -gt $maxChars) {
            $assistantText = $assistantText.Substring(0, $maxChars) + '...[TRUNCATED]'
        }
        foreach ($pattern in $config.capture.redact_patterns) {
            $assistantText = [regex]::Replace($assistantText, $pattern, '[REDACTED]')
        }
    }

    $cwd = [string]$hook.cwd
    $projectName = if ($cwd) { Split-Path $cwd -Leaf } else { 'unknown' }

    # 3-tier weighting: home / active (live, default) / override.
    $isHome = $false
    $activeWeight = if ($null -ne $config.weighting.active_weight) { [double]$config.weighting.active_weight } else { [double]$config.weighting.other_weight }
    $weight = $activeWeight
    $tier = 'active'
    if ($cwd) {
        $cwdNorm = $cwd.TrimEnd('\','/').ToLowerInvariant()
        $projNorm = $projectName.ToLowerInvariant()
        foreach ($h in @($config.weighting.homes)) {
            if ($null -eq $h -or [string]::IsNullOrWhiteSpace([string]$h)) { continue }
            $hNorm = ([string]$h).TrimEnd('\','/').ToLowerInvariant()
            if ($hNorm -match '[\\/]') {
                if ($cwdNorm -eq $hNorm -or $cwdNorm.StartsWith($hNorm + '\') -or $cwdNorm.StartsWith($hNorm + '/')) {
                    $isHome = $true; break
                }
            } else {
                if ($projNorm -eq $hNorm) { $isHome = $true; break }
            }
        }
        if ($isHome) {
            $weight = [double]$config.weighting.home_weight
            $tier = 'home'
        } elseif ($config.weighting.project_overrides -and ($config.weighting.project_overrides.PSObject.Properties.Name -contains $projectName)) {
            $weight = [double]$config.weighting.project_overrides.$projectName
            $tier = 'override'
        }
    }

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

    $eventTag = if ($writeMode -eq 'tokens') { 'StopTokens' } else { 'Stop' }
    $respChars = if ($null -ne $assistantText) { $assistantText.Length } else { $null }

    $record = [ordered]@{
        id              = [guid]::NewGuid().ToString()
        ts              = (Get-Date).ToUniversalTime().ToString('o')
        event           = $eventTag
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
        tier            = $tier
        response        = $assistantText
        response_chars  = $respChars
        tokens_in           = $tokensIn
        tokens_out          = $tokensOut
        tokens_cache_read   = $tokensCacheRead
        tokens_cache_create = $tokensCacheCreate
        model               = $modelId
        hae_phase       = [int]$config.phase
        source          = 'hook'
    }

    $json = $record | ConvertTo-Json -Compress -Depth 10

    $rawDir = Get-HaeRawDir
    if (-not (Test-Path $rawDir)) { New-Item -ItemType Directory -Path $rawDir -Force | Out-Null }

    $dateStamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd')
    $sidShort = if ($sessionId) { $sessionId.Substring(0, [Math]::Min(8, $sessionId.Length)) } else { 'noses' }
    $file = Join-Path $rawDir "$dateStamp`__$sidShort.jsonl"

    [System.IO.File]::AppendAllText($file, $json + "`n", [System.Text.UTF8Encoding]::new($false))
} catch {
    # Never block Claude Code.
}

exit 0
