# HAE - install as a Claude Code plugin via local marketplace.
#
# Default flow (Copy mode):
#   1. Robocopy plugin source -> $CopyTo (default C:\Plugins\hae). Skips data dirs.
#   2. Junction <claude>/plugins/marketplaces/hae-local/plugins/hae -> $CopyTo.
#   3. Create data dir + copy config.user.example.json -> <dataDir>/config.json (first run only).
#   4. Set HAE_DATA_DIR env (process; user-scope if -PersistEnv).
#   5. Wire registry (known_marketplaces, installed_plugins, settings.json enabledPlugins).
#   6. Update settings.json statusLine.command to marketplace-junction path (survives source moves).
#
# Re-runnable: junction recreated only if stale; data dir config preserved if existing.
# Uninstall: removes junction + registry entries; data dir untouched (operator data).

[CmdletBinding()]
param(
    [string]$PluginPath,                                            # source dir (default: parent of scripts/)
    [string]$CopyTo = 'C:\Plugins\hae',                             # install target
    [string]$DataDir,                                               # data dir (default: $env:HAE_DATA_DIR or %USERPROFILE%\.hae)
    [ValidateSet('Copy','Junction')] [string]$Mode = 'Copy',        # Copy=robocopy to install path; Junction=marketplace -> source dir
    [string]$MarketplaceName = 'hae-local',
    [string]$PluginName = 'hae',
    [string]$PluginVersion,                                         # default: read from plugin.json
    [switch]$PersistEnv,                                            # write HAE_DATA_DIR to user-scope env
    [switch]$Uninstall,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# Resolve plugin source path
if (-not $PluginPath) {
    $PluginPath = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
}
$PluginPath = (Resolve-Path $PluginPath).Path
$pluginJsonPath = Join-Path $PluginPath '.claude-plugin\plugin.json'
if (-not (Test-Path $pluginJsonPath)) {
    Write-Error "Not a Claude Code plugin (missing .claude-plugin\plugin.json): $PluginPath"
    exit 1
}

# Read version from plugin.json (single source of truth) unless overridden
if (-not $PluginVersion) {
    $srcManifest = Get-Content $pluginJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($srcManifest.version) {
        $PluginVersion = $srcManifest.version
    } else {
        $PluginVersion = '0.0.0'
    }
}

# Resolve data dir (env > param > default)
if (-not $DataDir) {
    if ($env:HAE_DATA_DIR -and -not [string]::IsNullOrWhiteSpace($env:HAE_DATA_DIR)) {
        $DataDir = $env:HAE_DATA_DIR
    } else {
        $DataDir = Join-Path $env:USERPROFILE '.hae'
    }
}

$claudeDir = Join-Path $env:USERPROFILE '.claude'
$pluginsDir = Join-Path $claudeDir 'plugins'
$mpDir = Join-Path $pluginsDir "marketplaces\$MarketplaceName"
$mpPluginsDir = Join-Path $mpDir 'plugins'
$mpPluginLink = Join-Path $mpPluginsDir $PluginName
$mpJson = Join-Path $mpDir '.claude-plugin\marketplace.json'
$kmJson = Join-Path $pluginsDir 'known_marketplaces.json'
$ipJson = Join-Path $pluginsDir 'installed_plugins.json'
$settingsJson = Join-Path $claudeDir 'settings.json'
$key = "$PluginName@$MarketplaceName"

function New-BackupSuffix {
    "{0}-{1}" -f (Get-Date -Format 'yyyyMMdd-HHmmss-fff'), (([guid]::NewGuid()).ToString('N').Substring(0,6))
}
function Backup-File($path) {
    if (Test-Path $path) {
        $backup = "$path.hae-backup-$(New-BackupSuffix).json"
        Copy-Item $path $backup
        Write-Host "  backup: $backup"
    }
}
function Write-JsonFile($path, $obj) {
    $json = $obj | ConvertTo-Json -Depth 20
    [System.IO.File]::WriteAllText($path, $json, [System.Text.UTF8Encoding]::new($false))
}

# ========== UNINSTALL ==========
if ($Uninstall) {
    Write-Host "Uninstalling $key ..."
    if (Test-Path $mpPluginLink) { Remove-Item $mpPluginLink -Recurse -Force; Write-Host "  removed: $mpPluginLink" }
    if (Test-Path $mpDir) { Remove-Item $mpDir -Recurse -Force; Write-Host "  removed: $mpDir" }

    if (Test-Path $kmJson) {
        Backup-File $kmJson
        $km = Get-Content $kmJson -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($km.PSObject.Properties.Name -contains $MarketplaceName) {
            $km.PSObject.Properties.Remove($MarketplaceName)
            Write-JsonFile $kmJson $km
            Write-Host "  removed marketplace entry: $MarketplaceName"
        }
    }
    if (Test-Path $ipJson) {
        Backup-File $ipJson
        $ip = Get-Content $ipJson -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($ip.plugins -and ($ip.plugins.PSObject.Properties.Name -contains $key)) {
            $ip.plugins.PSObject.Properties.Remove($key)
            Write-JsonFile $ipJson $ip
            Write-Host "  removed installed entry: $key"
        }
    }
    if (Test-Path $settingsJson) {
        Backup-File $settingsJson
        $s = Get-Content $settingsJson -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($s.enabledPlugins -and ($s.enabledPlugins.PSObject.Properties.Name -contains $key)) {
            $s.enabledPlugins.PSObject.Properties.Remove($key)
            Write-JsonFile $settingsJson $s
            Write-Host "  removed enabledPlugins entry: $key"
        }
    }
    Write-Host ""
    Write-Host "Uninstalled. Data dir preserved at: $DataDir"
    Write-Host "Run /reload-plugins in Claude Code (or restart)."
    exit 0
}

# ========== INSTALL ==========
Write-Host "Installing $PluginName as plugin '$key'"
Write-Host "  source:   $PluginPath"
Write-Host "  mode:     $Mode"
if ($Mode -eq 'Copy') { Write-Host "  install:  $CopyTo" }
Write-Host "  data dir: $DataDir"
Write-Host ""

# 1. Decide effective plugin path
if ($Mode -eq 'Copy') {
    if (-not (Test-Path $CopyTo)) { New-Item -ItemType Directory -Path $CopyTo -Force | Out-Null }
    Write-Host "  Copying source -> install path (excluding operator data)..."
    # /XD with bare names matches anywhere in tree (would exclude skills/profile).
    # Use absolute paths so only top-level dirs are excluded.
    $rcArgs = @(
        $PluginPath, $CopyTo, '/E', '/PURGE',
        '/XD',
            (Join-Path $PluginPath 'prompts'),
            (Join-Path $PluginPath 'profile'),
            (Join-Path $PluginPath 'state'),
            (Join-Path $PluginPath '.git'),
        '/XF', '*.hae-backup-*.json',
        '/NFL','/NDL','/NJH','/NJS','/NP'
    )
    & robocopy @rcArgs | Out-Null
    if ($LASTEXITCODE -ge 8) {
        Write-Error "robocopy failed (exit $LASTEXITCODE)"
        exit 1
    }
    $effectivePath = (Resolve-Path $CopyTo).Path
    Write-Host "  copied to: $effectivePath"
} else {
    $effectivePath = $PluginPath
    Write-Host "  junction will target source dir directly (live dev mode)"
}

# 2. Marketplace dir + junction to effective plugin path
New-Item -ItemType Directory -Path "$mpDir\.claude-plugin" -Force | Out-Null
New-Item -ItemType Directory -Path $mpPluginsDir -Force | Out-Null
if (Test-Path $mpPluginLink) {
    $existing = Get-Item $mpPluginLink -Force
    if ($existing.LinkType -eq 'Junction' -and $existing.Target[0] -eq $effectivePath) {
        Write-Host "  junction up to date: $mpPluginLink"
    } else {
        Remove-Item $mpPluginLink -Recurse -Force
        New-Item -ItemType Junction -Path $mpPluginLink -Target $effectivePath | Out-Null
        Write-Host "  junction recreated: $mpPluginLink -> $effectivePath"
    }
} else {
    New-Item -ItemType Junction -Path $mpPluginLink -Target $effectivePath | Out-Null
    Write-Host "  junction: $mpPluginLink -> $effectivePath"
}

# 3. marketplace.json
$mpManifest = @{
    name = $MarketplaceName
    owner = @{ name = $env:USERNAME }
    metadata = @{
        description = "Local development marketplace for $PluginName."
        version = $PluginVersion
    }
    plugins = @(@{
        name = $PluginName
        description = "HAE - Human Agent Emulator"
        version = $PluginVersion
        author = @{ name = $env:USERNAME }
        source = "./plugins/$PluginName"
    })
}
Write-JsonFile $mpJson $mpManifest
Write-Host "  wrote: $mpJson"

# 4. known_marketplaces.json
if (-not (Test-Path $kmJson)) {
    [System.IO.File]::WriteAllText($kmJson, '{}', [System.Text.UTF8Encoding]::new($false))
}
Backup-File $kmJson
$km = Get-Content $kmJson -Raw -Encoding UTF8 | ConvertFrom-Json
$mpEntry = [pscustomobject]@{
    source = [pscustomobject]@{ source = 'file'; path = $mpDir }
    installLocation = $mpDir
    lastUpdated = (Get-Date).ToUniversalTime().ToString('o')
}
$km | Add-Member -NotePropertyName $MarketplaceName -NotePropertyValue $mpEntry -Force
Write-JsonFile $kmJson $km
Write-Host "  registered marketplace: $MarketplaceName"

# 5. installed_plugins.json
if (-not (Test-Path $ipJson)) {
    [System.IO.File]::WriteAllText($ipJson, '{"version":2,"plugins":{}}', [System.Text.UTF8Encoding]::new($false))
}
Backup-File $ipJson
$ip = Get-Content $ipJson -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $ip.plugins) { $ip | Add-Member -NotePropertyName 'plugins' -NotePropertyValue ([pscustomobject]@{}) -Force }
$ipEntry = @(@{
    scope = 'user'
    installPath = $mpPluginLink
    version = $PluginVersion
    installedAt = (Get-Date).ToUniversalTime().ToString('o')
    lastUpdated = (Get-Date).ToUniversalTime().ToString('o')
    gitCommitSha = 'local-dev'
})
$ip.plugins | Add-Member -NotePropertyName $key -NotePropertyValue $ipEntry -Force
Write-JsonFile $ipJson $ip
Write-Host "  registered installed plugin: $key"

# 6. settings.json enabledPlugins + statusLine rewire
if (-not (Test-Path $settingsJson)) {
    [System.IO.File]::WriteAllText($settingsJson, '{}', [System.Text.UTF8Encoding]::new($false))
}
Backup-File $settingsJson
$s = Get-Content $settingsJson -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $s.enabledPlugins) { $s | Add-Member -NotePropertyName 'enabledPlugins' -NotePropertyValue ([pscustomobject]@{}) -Force }
$s.enabledPlugins | Add-Member -NotePropertyName $key -NotePropertyValue $true -Force

# Statusline rewire: if existing statusLine.command points at any old .hae path, update to marketplace junction.
$statusLineScript = Join-Path $mpPluginLink 'scripts\statusline_universal.ps1'
$desiredStatusCmd = "powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$statusLineScript`""
if ($s.statusLine -and $s.statusLine.command) {
    $current = [string]$s.statusLine.command
    $shouldUpdate = $current -match '\\.hae\\scripts\\statusline' -or $current -match 'statusline_universal\.ps1'
    if ($shouldUpdate) {
        $s.statusLine.command = $desiredStatusCmd
        Write-Host "  statusline command rewired to marketplace junction"
    } else {
        Write-Host "  statusline command preserved (not HAE-related)"
    }
}

# Strip any legacy _hae_managed direct hook entries (superseded by plugin hooks).
$legacyRemoved = 0
if ($s.hooks) {
    foreach ($evt in @('UserPromptSubmit','Stop')) {
        if ($s.hooks.PSObject.Properties.Name -contains $evt) {
            $kept = @($s.hooks.$evt | Where-Object { -not $_._hae_managed })
            $before = @($s.hooks.$evt).Count
            $legacyRemoved += ($before - $kept.Count)
            if ($kept.Count -eq 0) {
                $s.hooks.PSObject.Properties.Remove($evt)
            } else {
                $s.hooks.$evt = $kept
            }
        }
    }
}
if ($legacyRemoved -gt 0) { Write-Host "  removed $legacyRemoved legacy direct-hook entries (plugin will provide them)" }

Write-JsonFile $settingsJson $s
Write-Host "  enabled in settings: $key"

# 7. Data dir + user config bootstrap
foreach ($sub in @('prompts\raw','prompts\structured','profile','state')) {
    $p = Join-Path $DataDir $sub
    if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
}
$userConfig = Join-Path $DataDir 'config.json'
$userExample = Join-Path $effectivePath 'config.user.example.json'
if (-not (Test-Path $userConfig)) {
    if (Test-Path $userExample) {
        Copy-Item $userExample $userConfig
        Write-Host "  bootstrapped user config: $userConfig (from template)"
    } else {
        Write-Host "  WARN: no config.user.example.json in plugin source; user config not created"
    }
} else {
    Write-Host "  user config preserved: $userConfig"
}

# 8. Env var
$env:HAE_DATA_DIR = $DataDir
if ($PersistEnv) {
    [Environment]::SetEnvironmentVariable('HAE_DATA_DIR', $DataDir, 'User')
    Write-Host "  HAE_DATA_DIR persisted to user-scope env vars"
} else {
    Write-Host "  HAE_DATA_DIR set for this process; rerun with -PersistEnv to persist user-wide"
    Write-Host "    or add to PowerShell profile: `$env:HAE_DATA_DIR = '$DataDir'"
}

Write-Host ""
Write-Host "Installed."
Write-Host ""
Write-Host "Summary:"
Write-Host "  source:    $PluginPath"
Write-Host "  install:   $effectivePath"
Write-Host "  junction:  $mpPluginLink"
Write-Host "  data dir:  $DataDir"
Write-Host "  enabled:   $key"
Write-Host ""
Write-Host "Next:"
Write-Host "  1. Restart Claude Code (statusline + plugin registry need fresh process)"
Write-Host "  2. /plugin list   (verify: $key should appear)"
Write-Host "  3. type /$PluginName`: in any prompt; type a prompt to verify capture"
Write-Host ""
Write-Host "Uninstall: powershell -File `"$PSCommandPath`" -Uninstall"
