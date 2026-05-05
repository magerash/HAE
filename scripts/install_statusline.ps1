# HAE - install/uninstall the universal statusline wrapper.
# Captures whatever statusLine.command is currently set, saves it to HAE config
# as previous_command, then sets statusLine.command to the HAE wrapper.
# Idempotent: if already wrapped, no-op (preserves the originally captured previous command).

[CmdletBinding()]
param(
    [switch]$Uninstall,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$haeRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$configPath = Join-Path $haeRoot 'config.json'
$wrapperScript = Join-Path $haeRoot 'scripts\statusline_universal.ps1'
# -WindowStyle Hidden suppresses brief window flash on each render.
# -NonInteractive prevents any prompt dialog from blocking.
$wrapperCmd = "powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$wrapperScript`""

$settingsPath = Join-Path $env:USERPROFILE '.claude\settings.json'
if (-not (Test-Path $settingsPath)) {
    Write-Error "settings.json not found at $settingsPath"
    exit 1
}

# Backup
$stamp = (Get-Date -Format 'yyyyMMdd-HHmmss-fff')
$rand = ([guid]::NewGuid()).ToString('N').Substring(0,6)
Copy-Item $settingsPath "$settingsPath.hae-backup-$stamp-$rand.json"

$settings = Get-Content $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
$config   = Get-Content $configPath   -Raw -Encoding UTF8 | ConvertFrom-Json

# Ensure config.statusline exists
if (-not $config.statusline) {
    $config | Add-Member -NotePropertyName 'statusline' -NotePropertyValue ([pscustomobject]@{ previous_command = $null }) -Force
}

function Save-Config {
    $json = $config | ConvertTo-Json -Depth 20
    [System.IO.File]::WriteAllText($configPath, $json, [System.Text.UTF8Encoding]::new($false))
}
function Save-Settings {
    $json = $settings | ConvertTo-Json -Depth 20
    [System.IO.File]::WriteAllText($settingsPath, $json, [System.Text.UTF8Encoding]::new($false))
}

if ($Uninstall) {
    Write-Host "Uninstalling HAE statusline wrapper..."
    $prev = $config.statusline.previous_command
    if (-not $settings.statusLine) {
        Write-Host "  (no statusLine entry to revert)"
    } elseif ($prev) {
        $settings.statusLine.command = $prev
        Save-Settings
        Write-Host "  restored previous statusLine.command:"
        Write-Host "    $prev"
    } else {
        $settings.PSObject.Properties.Remove('statusLine')
        Save-Settings
        Write-Host "  removed statusLine entry (no previous to restore)"
    }
    # Clear the saved previous so a future re-install picks up fresh state
    $config.statusline.previous_command = $null
    Save-Config
    Write-Host "Done. Statusline reverted."
    exit 0
}

# Detect existing
$existing = $null
if ($settings.statusLine) { $existing = [string]$settings.statusLine.command }

# Already wrapped?
if ($existing -and ($existing -like "*statusline_universal.ps1*") -and -not $Force) {
    Write-Host "HAE statusline wrapper already installed."
    Write-Host "  previous (preserved): $($config.statusline.previous_command)"
    Write-Host "  Use -Force to capture current statusLine as new previous."
    exit 0
}

# Save existing as previous (if any). Don't overwrite saved previous unless -Force or no current.
if ($existing -and ($existing -notlike "*statusline_universal.ps1*")) {
    $config.statusline.previous_command = $existing
    Save-Config
    Write-Host "Captured previous statusLine.command:"
    Write-Host "  $existing"
} elseif ($Force -and $existing -and ($existing -like "*statusline_universal.ps1*")) {
    Write-Host "  -Force on already-wrapped state: keeping prior previous_command unchanged."
}

# Set statusLine to HAE wrapper
if (-not $settings.statusLine) {
    $settings | Add-Member -NotePropertyName 'statusLine' -NotePropertyValue ([pscustomobject]@{
        type = 'command'
        command = $wrapperCmd
    }) -Force
} else {
    $settings.statusLine.command = $wrapperCmd
    if (-not $settings.statusLine.type) {
        $settings.statusLine | Add-Member -NotePropertyName 'type' -NotePropertyValue 'command' -Force
    }
}
Save-Settings

Write-Host ""
Write-Host "HAE statusline wrapper installed."
Write-Host "  statusLine.command:"
Write-Host "    $wrapperCmd"
if ($config.statusline.previous_command) {
    Write-Host "  previous (will print on row 1):"
    Write-Host "    $($config.statusline.previous_command)"
} else {
    Write-Host "  no previous statusLine - HAE prints alone"
}
Write-Host ""
Write-Host "Restart Claude Code OR run /reload-plugins for the change to take effect in your UI."
Write-Host "Uninstall: powershell -File `"$PSCommandPath`" -Uninstall"
