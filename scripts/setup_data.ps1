# HAE - bootstrap data dir + env + statusline after marketplace install.
#
# Marketplace install (/plugin install hae@hae) only places plugin files.
# This script does the operator-side setup that install_plugin.ps1 does:
#   1. Create data dir tree (~/.hae/{prompts/raw,prompts/structured,profile,state})
#   2. Copy config.user.example.json -> <DataDir>/config.json (first run only)
#   3. Set HAE_DATA_DIR env (process + optional user-scope)
#   4. Rewire ~/.claude/settings.json statusLine.command to plugin's statusline_universal.ps1
#
# Idempotent. Safe to re-run.

[CmdletBinding()]
param(
    [string]$DataDir,                               # default: $env:HAE_DATA_DIR or %USERPROFILE%\.hae
    [string]$PluginPath,                            # default: parent of scripts/ (this script's location)
    [switch]$PersistEnv,                            # write HAE_DATA_DIR to user-scope env
    [switch]$SkipStatusline                         # don't touch settings.json statusLine
)

$ErrorActionPreference = 'Stop'

if (-not $PluginPath) {
    $PluginPath = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
}
$PluginPath = (Resolve-Path $PluginPath).Path

if (-not $DataDir) {
    if ($env:HAE_DATA_DIR -and -not [string]::IsNullOrWhiteSpace($env:HAE_DATA_DIR)) {
        $DataDir = $env:HAE_DATA_DIR
    } else {
        $DataDir = Join-Path $env:USERPROFILE '.hae'
    }
}

Write-Host "HAE setup"
Write-Host "  plugin:   $PluginPath"
Write-Host "  data dir: $DataDir"
Write-Host ""

# 1. Data dir tree
foreach ($sub in @('prompts\raw','prompts\structured','profile','state')) {
    $p = Join-Path $DataDir $sub
    if (-not (Test-Path $p)) {
        New-Item -ItemType Directory -Path $p -Force | Out-Null
        Write-Host "  created: $p"
    }
}

# 2. User config bootstrap
$userConfig = Join-Path $DataDir 'config.json'
$userExample = Join-Path $PluginPath 'config.user.example.json'
if (-not (Test-Path $userConfig)) {
    if (Test-Path $userExample) {
        Copy-Item $userExample $userConfig
        Write-Host "  bootstrapped user config: $userConfig"
    } else {
        Write-Host "  WARN: no config.user.example.json in plugin source; user config not created"
    }
} else {
    Write-Host "  user config preserved: $userConfig"
}

# 3. Env var
$env:HAE_DATA_DIR = $DataDir
if ($PersistEnv) {
    [Environment]::SetEnvironmentVariable('HAE_DATA_DIR', $DataDir, 'User')
    Write-Host "  HAE_DATA_DIR persisted to user-scope env"
} else {
    Write-Host "  HAE_DATA_DIR set for this process only (rerun with -PersistEnv to persist user-wide)"
}

# 4. Statusline rewire
if (-not $SkipStatusline) {
    $claudeDir = Join-Path $env:USERPROFILE '.claude'
    $settingsJson = Join-Path $claudeDir 'settings.json'
    if (Test-Path $settingsJson) {
        # Find marketplace junction to plugin (preferred path, survives source moves)
        $mpJunction = Join-Path $claudeDir 'plugins\marketplaces\hae-local\plugins\hae'
        if (-not (Test-Path $mpJunction)) {
            # Try git-marketplace path (when installed via /plugin install hae@hae)
            $mpJunction = $PluginPath
        }
        $statusLineScript = Join-Path $mpJunction 'scripts\statusline_universal.ps1'
        $desiredStatusCmd = "powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$statusLineScript`""

        $backup = "$settingsJson.hae-backup-{0}-{1}.json" -f (Get-Date -Format 'yyyyMMdd-HHmmss-fff'), (([guid]::NewGuid()).ToString('N').Substring(0,6))
        Copy-Item $settingsJson $backup
        Write-Host "  backup: $backup"

        $s = Get-Content $settingsJson -Raw -Encoding UTF8 | ConvertFrom-Json
        if (-not $s.statusLine) {
            $s | Add-Member -NotePropertyName 'statusLine' -NotePropertyValue ([pscustomobject]@{ type='command'; command=$desiredStatusCmd }) -Force
            Write-Host "  statusline added"
        } else {
            $current = [string]$s.statusLine.command
            $shouldUpdate = -not $current -or $current -match 'statusline_universal\.ps1' -or $current -match '\\.hae\\scripts\\statusline'
            if ($shouldUpdate) {
                $s.statusLine.command = $desiredStatusCmd
                $s.statusLine.type = 'command'
                Write-Host "  statusline rewired"
            } else {
                Write-Host "  statusline preserved (not HAE-related)"
            }
        }
        $json = $s | ConvertTo-Json -Depth 20
        [System.IO.File]::WriteAllText($settingsJson, $json, [System.Text.UTF8Encoding]::new($false))
    } else {
        Write-Host "  settings.json not found; skipping statusline rewire"
    }
}

Write-Host ""
Write-Host "Setup complete."
Write-Host "Next:"
Write-Host "  1. Restart Claude Code (env + statusline need fresh process)"
Write-Host "  2. Type any prompt -> verify capture at $DataDir\prompts\raw\<date>__<sid>.jsonl"
