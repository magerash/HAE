# HAE - statusline segment with ANSI colors.
#
# Two invocation modes:
#   1. Direct execution (Claude Code statusLine.command points at this file):
#      Auto-invokes Get-HaeStatusline and writes to stdout.
#   2. Dot-sourced (wrapper does `. statusline.ps1`):
#      Defines Get-HaeStatusline function only; wrapper calls it inline.
#      Avoids spawning a child PowerShell process per render.
#
# Disable colors by setting $env:NO_COLOR=1 or config.statusline.colors=false.

$ErrorActionPreference = 'SilentlyContinue'

function Get-HaeStatusline {
    [CmdletBinding()]
    param(
        [string]$HaeRoot = $null
    )

    try {
        if (-not $HaeRoot) {
            $HaeRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
        }
        $configPath = Join-Path $HaeRoot 'config.json'
        if (-not (Test-Path $configPath)) {
            return '[hae#?] not configured'
        }

        $config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json

        # Color toggle
        $useColor = $true
        if ($env:NO_COLOR) { $useColor = $false }
        if ($config.statusline -and $config.statusline.PSObject.Properties.Name -contains 'colors' -and $config.statusline.colors -eq $false) {
            $useColor = $false
        }

        $E = [char]27
        if ($useColor) {
            $RESET     = "$E[0m"
            $DIM       = "$E[2m"
            $GRAY_DARK = "$E[90m"
            $GRAY_LITE = "$E[38;5;250m"
            $GREEN     = "$E[32m"
            $RED       = "$E[31m"
            $YELLOW    = "$E[33m"
            $BCYAN     = "$E[1;36m"
            $MAGENTA   = "$E[35m"
        } else {
            $RESET = $DIM = $GRAY_DARK = $GRAY_LITE = $GREEN = $RED = $YELLOW = $BCYAN = $MAGENTA = ''
        }

        # Plugin version
        $version = '?'
        $manifestPath = Join-Path $HaeRoot '.claude-plugin\plugin.json'
        if (Test-Path $manifestPath) {
            try { $version = (Get-Content $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json).version } catch {}
        }

        $capState = if ($config.capture.enabled) { 'ON' } else { 'OFF' }
        $capColor = if ($config.capture.enabled) { $GREEN } else { $RED }

        # Counts - dedup by id across per-session + combined daily files
        $rawDir = Join-Path $HaeRoot 'prompts\raw'
        $today = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd')
        $todayRecords = 0
        $todaySessions = @{}
        $totalRecords = 0
        $seenIds = @{}
        if (Test-Path $rawDir) {
            $files = Get-ChildItem $rawDir -Filter '*.jsonl' -ErrorAction SilentlyContinue | Sort-Object {
                if ($_.BaseName -match '^\d{4}-\d{2}-\d{2}__') { 1 } else { 0 }
            }
            foreach ($f in $files) {
                Get-Content $f.FullName -Encoding UTF8 -ErrorAction SilentlyContinue | ForEach-Object {
                    if ([string]::IsNullOrWhiteSpace($_)) { return }
                    try {
                        $r = $_ | ConvertFrom-Json
                        $rid = [string]$r.id
                        if ($rid -and $seenIds.ContainsKey($rid)) { return }
                        if ($rid) { $seenIds[$rid] = $true }
                        $totalRecords++
                        $ts = [DateTime]::Parse($r.ts).ToUniversalTime()
                        if ($ts.ToString('yyyy-MM-dd') -eq $today) {
                            $todayRecords++
                            if ($r.session_id) { $todaySessions[[string]$r.session_id] = $true }
                        }
                    } catch {}
                }
            }
        }

        # Structured count
        $structDir = Join-Path $HaeRoot 'prompts\structured'
        $structCount = 0
        if (Test-Path $structDir) {
            Get-ChildItem $structDir -Filter '*.jsonl' -ErrorAction SilentlyContinue | ForEach-Object {
                if ($_.Name -ne 'overrides.jsonl') {
                    $structCount += (Get-Content $_.FullName -ErrorAction SilentlyContinue | Measure-Object -Line).Lines
                }
            }
        }

        # Homes
        $homes = @($config.weighting.homes | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
        if ($homes.Count -eq 0) {
            $homeBit = "${RED}!nohome${RESET}"
        } elseif ($homes.Count -eq 1) {
            $homeBit = "${GRAY_DARK}home:${RESET}${GREEN}$($homes[0])${RESET}"
        } else {
            $homeBit = "${GRAY_DARK}homes:${RESET}${GREEN}$($homes.Count)${RESET}"
        }

        # Profile completeness
        $profDir = Join-Path $HaeRoot 'profile'
        $profExists = @{
            P = (Test-Path (Join-Path $profDir 'paei.json'))
            H = (Test-Path (Join-Path $profDir 'hexaco.json'))
            C = (Test-Path (Join-Path $profDir 'custom.json'))
            r = (Test-Path (Join-Path $profDir 'principles.md'))
        }
        $personaExists = (Test-Path (Join-Path $profDir 'persona.md'))
        $profStr = ''
        foreach ($k in @('P','H','C','r')) {
            if ($profExists[$k]) { $profStr += "${GREEN}$k${RESET}" } else { $profStr += "${DIM}-${RESET}" }
        }
        if ($personaExists) { $profStr += "${BCYAN}*${RESET}" }
        $profBit = "${GRAY_DARK}prof:${RESET}$profStr"

        # Hint
        $hint = $null
        if (-not $config.capture.enabled) { $hint = 'enable capture in config.json' }
        elseif ($totalRecords -eq 0) { $hint = 'awaiting first prompt' }
        elseif (-not $profExists.P -and -not $profExists.H -and -not $profExists.C) { $hint = '/hae:profile' }
        elseif ($homes.Count -eq 0) { $hint = '/hae:home auto-detect' }
        elseif ($structCount -eq 0 -and $totalRecords -ge 50) { $hint = '/hae:classify' }

        # Compose
        $brand  = "${GRAY_LITE}[hae#$version]${RESET}"
        $cap    = "${GRAY_DARK}cap:${RESET}${capColor}${capState}${RESET}"
        $counts = "${GRAY_DARK}sessions:${RESET}${YELLOW}$($todaySessions.Count)${RESET} ${GRAY_DARK}raw:${RESET}${YELLOW}${todayRecords}${RESET} ${GRAY_DARK}total:${RESET}${YELLOW}${totalRecords}${RESET}"

        $parts = @($brand, $cap, $counts, $homeBit, $profBit)
        if ($structCount -gt 0) { $parts += "${GRAY_DARK}str:${RESET}${MAGENTA}${structCount}${RESET}" }
        if ($hint) { $parts += "${GRAY_DARK}next:${RESET}${YELLOW}${hint}${RESET}" }

        $sep = " ${GRAY_DARK}|${RESET} "
        return ($parts -join $sep)
    } catch {
        return '[hae#?] err'
    }
}

# Auto-invoke when run directly (not dot-sourced).
# Detection: $MyInvocation.InvocationName equals '.' for dot-source, else direct.
if ($MyInvocation.InvocationName -ne '.') {
    if ([Console]::IsInputRedirected) {
        $null = [Console]::In.ReadToEnd()
    }
    Write-Host -NoNewline (Get-HaeStatusline)
}
