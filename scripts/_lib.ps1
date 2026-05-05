# HAE - shared helper library
# Dot-source from any HAE script:
#   . "$(Split-Path -Parent $PSCommandPath)\_lib.ps1"
#
# Provides:
#   Resolve-HaePluginRoot     : path to plugin install dir (where this script lives)
#   Resolve-HaeDataRoot       : path to operator data dir (env > config field > %USERPROFILE%\.hae)
#   Get-HaeConfig             : merged config (defaults from plugin, user overrides from data dir)
#   Get-HaeRawDir             : <dataRoot>\prompts\raw
#   Get-HaeStructuredDir      : <dataRoot>\prompts\structured
#   Get-HaeProfileDir         : <dataRoot>\profile
#   Get-HaeStateDir           : <dataRoot>\state
#   Ensure-HaeDataRoot        : mkdir -p the four data subdirs (idempotent)
#
# Design contract:
#   - PLUGIN code lives in install path (e.g. C:\Plugins\hae). Read-only at runtime.
#   - DATA lives in operator data dir (e.g. %USERPROFILE%\.hae). Cross-project, mutable.
#   - Config: config.default.json (plugin, committed) merged with config.json (data dir, operator-private).

$script:HaeConfigCache = $null  # per-process cache; safe for capture hot path

function Resolve-HaePluginRoot {
    # Caller's script lives in <plugin>\scripts\foo.ps1; plugin root is two levels up.
    # We use $script:MyInvocation from the caller's scope is unreliable; require caller passes $PSCommandPath.
    # Default: walk up from THIS file's location.
    return (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
}

function Resolve-HaeDataRoot {
    # Resolution order: env var > user config field haeDataRoot > %USERPROFILE%\.hae
    if ($env:HAE_DATA_DIR -and -not [string]::IsNullOrWhiteSpace($env:HAE_DATA_DIR)) {
        return $env:HAE_DATA_DIR
    }
    # Avoid infinite loop: read user config file directly without calling Get-HaeConfig
    $defaultDataRoot = Join-Path $env:USERPROFILE '.hae'
    $userConfigPath = Join-Path $defaultDataRoot 'config.json'
    if (Test-Path $userConfigPath) {
        try {
            $userCfg = Get-Content $userConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($userCfg.haeDataRoot -and -not [string]::IsNullOrWhiteSpace($userCfg.haeDataRoot)) {
                return $userCfg.haeDataRoot
            }
        } catch {}
    }
    return $defaultDataRoot
}

function Merge-HaeObject {
    param($base, $override)
    if ($null -eq $override) { return $base }
    if ($null -eq $base) { return $override }
    if ($override -is [System.Management.Automation.PSCustomObject] -and $base -is [System.Management.Automation.PSCustomObject]) {
        $merged = [pscustomobject]@{}
        foreach ($prop in $base.PSObject.Properties) {
            $merged | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value -Force
        }
        foreach ($prop in $override.PSObject.Properties) {
            $existing = $merged.PSObject.Properties[$prop.Name]
            if ($existing -and $existing.Value -is [System.Management.Automation.PSCustomObject] -and $prop.Value -is [System.Management.Automation.PSCustomObject]) {
                $merged | Add-Member -NotePropertyName $prop.Name -NotePropertyValue (Merge-HaeObject $existing.Value $prop.Value) -Force
            } else {
                $merged | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value -Force
            }
        }
        return $merged
    }
    return $override  # scalars and arrays: user wins outright
}

function Get-HaeConfig {
    param([switch]$NoCache)
    if (-not $NoCache -and $script:HaeConfigCache) { return $script:HaeConfigCache }

    $pluginRoot = Resolve-HaePluginRoot
    $defaultPath = Join-Path $pluginRoot 'config.default.json'
    $dataRoot = Resolve-HaeDataRoot
    $userPath = Join-Path $dataRoot 'config.json'

    $defaultCfg = $null
    if (Test-Path $defaultPath) {
        try { $defaultCfg = Get-Content $defaultPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
    }
    # Backwards-compat: if config.default.json absent, fall back to plugin's legacy config.json
    if ($null -eq $defaultCfg) {
        $legacyPath = Join-Path $pluginRoot 'config.json'
        if (Test-Path $legacyPath) {
            try { $defaultCfg = Get-Content $legacyPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
        }
    }

    $userCfg = $null
    if (Test-Path $userPath) {
        try { $userCfg = Get-Content $userPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
    }

    $merged = Merge-HaeObject $defaultCfg $userCfg
    if ($null -eq $merged) { $merged = [pscustomobject]@{} }
    $script:HaeConfigCache = $merged
    return $merged
}

function Get-HaeRawDir        { return (Join-Path (Resolve-HaeDataRoot) 'prompts\raw') }
function Get-HaeStructuredDir { return (Join-Path (Resolve-HaeDataRoot) 'prompts\structured') }
function Get-HaeProfileDir    { return (Join-Path (Resolve-HaeDataRoot) 'profile') }
function Get-HaeStateDir      { return (Join-Path (Resolve-HaeDataRoot) 'state') }
function Get-HaeOverridesFile { return (Join-Path (Get-HaeStructuredDir) 'overrides.jsonl') }

function Ensure-HaeDataRoot {
    $dataRoot = Resolve-HaeDataRoot
    foreach ($sub in @('prompts\raw','prompts\structured','profile','state')) {
        $p = Join-Path $dataRoot $sub
        if (-not (Test-Path $p)) {
            try { New-Item -ItemType Directory -Path $p -Force | Out-Null } catch {}
        }
    }
    return $dataRoot
}
