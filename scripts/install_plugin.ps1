# HAE - install as a Claude Code plugin via local marketplace.
# Auto-detects plugin path (parent of scripts/ dir = the plugin root).
# Idempotent: safe to re-run; updates registry entries in place.
# Backs up settings.json + plugin registry files before touching them.

[CmdletBinding()]
param(
    [string]$PluginPath,
    [string]$MarketplaceName = 'hae-local',
    [string]$PluginName = 'hae',
    [string]$PluginVersion = '0.1.0',
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'

# Resolve plugin path: caller-provided OR parent dir of this script's parent dir.
if (-not $PluginPath) {
    $PluginPath = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
}
$PluginPath = (Resolve-Path $PluginPath).Path

if (-not (Test-Path (Join-Path $PluginPath '.claude-plugin\plugin.json'))) {
    Write-Error "Not a Claude Code plugin (missing .claude-plugin\plugin.json): $PluginPath"
    exit 1
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
    Write-Host "Uninstalled. Run /reload-plugins in Claude Code."
    exit 0
}

Write-Host "Installing $PluginName as plugin '$key'"
Write-Host "  plugin source: $PluginPath"
Write-Host ""

# 1. Marketplace dir + junction to plugin source
New-Item -ItemType Directory -Path "$mpDir\.claude-plugin" -Force | Out-Null
New-Item -ItemType Directory -Path $mpPluginsDir -Force | Out-Null
if (Test-Path $mpPluginLink) {
    $existing = Get-Item $mpPluginLink -Force
    if ($existing.LinkType -eq 'Junction' -and $existing.Target[0] -eq $PluginPath) {
        Write-Host "  junction up to date: $mpPluginLink"
    } else {
        Remove-Item $mpPluginLink -Recurse -Force
        New-Item -ItemType Junction -Path $mpPluginLink -Target $PluginPath | Out-Null
        Write-Host "  junction recreated: $mpPluginLink -> $PluginPath"
    }
} else {
    New-Item -ItemType Junction -Path $mpPluginLink -Target $PluginPath | Out-Null
    Write-Host "  junction: $mpPluginLink -> $PluginPath"
}

# 2. marketplace.json
$mpManifest = @{
    name = $MarketplaceName
    owner = @{ name = $env:USERNAME }
    metadata = @{
        description = "Local development marketplace for $PluginName."
        version = $PluginVersion
    }
    plugins = @(@{
        name = $PluginName
        description = "Local-dev plugin: $PluginName"
        version = $PluginVersion
        author = @{ name = $env:USERNAME }
        source = "./plugins/$PluginName"
    })
}
Write-JsonFile $mpJson $mpManifest
Write-Host "  wrote: $mpJson"

# 3. known_marketplaces.json
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

# 4. installed_plugins.json
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

# 5. settings.json enabledPlugins
if (-not (Test-Path $settingsJson)) {
    [System.IO.File]::WriteAllText($settingsJson, '{}', [System.Text.UTF8Encoding]::new($false))
}
Backup-File $settingsJson
$s = Get-Content $settingsJson -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $s.enabledPlugins) { $s | Add-Member -NotePropertyName 'enabledPlugins' -NotePropertyValue ([pscustomobject]@{}) -Force }
$s.enabledPlugins | Add-Member -NotePropertyName $key -NotePropertyValue $true -Force

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

Write-Host ""
Write-Host "Installed."
Write-Host ""
Write-Host "Next:"
Write-Host "  1. /reload-plugins  (or restart Claude Code if reload reports 0 plugins)"
Write-Host "  2. /plugin list     (verify: $key should appear)"
Write-Host "  3. type /$PluginName`: in any prompt and check completions"
Write-Host ""
Write-Host "Uninstall: powershell -File `"$PSCommandPath`" -Uninstall"
