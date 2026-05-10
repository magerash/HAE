# HAE - install global hooks into ~/.claude/settings.json
# Idempotent: detects existing entries by `_hae_managed: true` marker and replaces them.
# Backs up settings.json before modification.
# Run manually after reviewing config.json and confirming you want global capture.

[CmdletBinding()]
param(
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'

$haeRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$claudeDir = Join-Path $env:USERPROFILE '.claude'
$settingsPath = Join-Path $claudeDir 'settings.json'

if (-not (Test-Path $claudeDir)) {
    Write-Error "Claude Code config dir not found: $claudeDir"
    exit 1
}

# Load or init settings
if (Test-Path $settingsPath) {
    $stamp = (Get-Date -Format 'yyyyMMdd-HHmmss-fff')
    $rand = ([guid]::NewGuid()).ToString('N').Substring(0,6)
    $backupPath = "$settingsPath.hae-backup-$stamp-$rand.json"
    Copy-Item $settingsPath $backupPath -ErrorAction Stop
    Write-Host "Backup written: $backupPath"
    $settings = Get-Content $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
} else {
    $settings = [pscustomobject]@{}
}

# Ensure hooks key exists as a hashtable-like object
if (-not $settings.hooks) {
    $settings | Add-Member -NotePropertyName 'hooks' -NotePropertyValue ([pscustomobject]@{}) -Force
}

function Remove-HaeHooks {
    param($hooksObj)
    $events = @('UserPromptSubmit', 'Stop')
    foreach ($evt in $events) {
        if ($hooksObj.PSObject.Properties.Name -contains $evt) {
            $list = @($hooksObj.$evt | Where-Object { -not $_._hae_managed })
            if ($list.Count -eq 0) {
                $hooksObj.PSObject.Properties.Remove($evt)
            } else {
                $hooksObj.$evt = $list
            }
        }
    }
}

Remove-HaeHooks -hooksObj $settings.hooks

if ($Uninstall) {
    $json = $settings | ConvertTo-Json -Depth 20
    [System.IO.File]::WriteAllText($settingsPath, $json, [System.Text.UTF8Encoding]::new($false))
    Write-Host "HAE hooks removed from $settingsPath"
    exit 0
}

$capturePromptScript = (Join-Path $haeRoot 'scripts\capture_prompt.ps1').Replace('\', '\\')
$captureResponseScript = (Join-Path $haeRoot 'scripts\capture_response.ps1').Replace('\', '\\')

$shellExe = 'powershell'
if (Get-Command pwsh -ErrorAction SilentlyContinue) { $shellExe = 'pwsh' }

$promptHook = [pscustomobject]@{
    type          = 'command'
    command       = "$shellExe -NoProfile -ExecutionPolicy Bypass -File `"$(Join-Path $haeRoot 'scripts\capture_prompt.ps1')`""
    _hae_managed  = $true
    _hae_version  = '0.1.0'
}
$responseHook = [pscustomobject]@{
    type          = 'command'
    command       = "$shellExe -NoProfile -ExecutionPolicy Bypass -File `"$(Join-Path $haeRoot 'scripts\capture_response.ps1')`""
    _hae_managed  = $true
    _hae_version  = '0.1.0'
}

# Append to UserPromptSubmit
$existingPrompt = @()
if ($settings.hooks.PSObject.Properties.Name -contains 'UserPromptSubmit') {
    $existingPrompt = @($settings.hooks.UserPromptSubmit)
}
$settings.hooks | Add-Member -NotePropertyName 'UserPromptSubmit' -NotePropertyValue (@($existingPrompt) + $promptHook) -Force

# Append to Stop
$existingStop = @()
if ($settings.hooks.PSObject.Properties.Name -contains 'Stop') {
    $existingStop = @($settings.hooks.Stop)
}
$settings.hooks | Add-Member -NotePropertyName 'Stop' -NotePropertyValue (@($existingStop) + $responseHook) -Force

$json = $settings | ConvertTo-Json -Depth 20
[System.IO.File]::WriteAllText($settingsPath, $json, [System.Text.UTF8Encoding]::new($false))

Write-Host ""
Write-Host "HAE hooks installed to $settingsPath (shell: $shellExe)"
Write-Host "Scripts: $haeRoot\scripts\"
Write-Host ""
Write-Host "NEXT: edit $haeRoot\config.json and set capture.enabled = true to start logging."
Write-Host "Uninstall: pwsh $PSCommandPath -Uninstall"
