# HAE - universal statusline wrapper
# Runs the user's pre-existing statusLine command (saved to config.statusline.previous_command)
# on row 1, then HAE segment on row 2.
#
# Optimization: dot-sources statusline.ps1 so the HAE segment runs in THIS process,
# eliminating one PowerShell child spawn per render. Net: 1 powershell + (optionally)
# 1 child for the wrapped previous command (e.g. node for OMC).
#
# Stdin (Claude Code passes JSON context) is captured once and forwarded to the
# previous command via a Process pipe.

$ErrorActionPreference = 'SilentlyContinue'

$haeRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$configPath = Join-Path $haeRoot 'config.json'

# Capture stdin once
$stdinBytes = $null
try {
    if ([Console]::IsInputRedirected) {
        $ms = New-Object System.IO.MemoryStream
        [Console]::OpenStandardInput().CopyTo($ms)
        $stdinBytes = $ms.ToArray()
        $ms.Dispose()
    }
} catch {}

# Read previous statusLine command from HAE config
$prevCmd = $null
try {
    $config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($config.statusline -and $config.statusline.previous_command) {
        $prevCmd = [string]$config.statusline.previous_command
    }
} catch {}

# Run previous command (if any), forwarding stdin
$prevOut = ''
if ($prevCmd) {
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = 'cmd.exe'
        $psi.Arguments = "/c $prevCmd"
        $psi.RedirectStandardInput = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $proc = [System.Diagnostics.Process]::Start($psi)
        if ($stdinBytes -and $stdinBytes.Length -gt 0) {
            $proc.StandardInput.BaseStream.Write($stdinBytes, 0, $stdinBytes.Length)
            $proc.StandardInput.BaseStream.Flush()
        }
        $proc.StandardInput.Close()
        $prevOut = $proc.StandardOutput.ReadToEnd()
        if (-not $proc.WaitForExit(2000)) {
            $proc.Kill()
        }
        $prevOut = $prevOut.TrimEnd("`r", "`n")
    } catch { $prevOut = '' }
}

# Run HAE segment IN-PROCESS via dot-source (no child PS spawn)
$haeOut = ''
try {
    . (Join-Path $PSScriptRoot 'statusline.ps1')
    $haeOut = (Get-HaeStatusline -HaeRoot $haeRoot).TrimEnd("`r", "`n")
} catch { $haeOut = '' }

# Compose - one row per non-empty source
if ($prevOut -and $haeOut) {
    Write-Output $prevOut
    Write-Output $haeOut
} elseif ($prevOut) {
    Write-Output $prevOut
} elseif ($haeOut) {
    Write-Output $haeOut
}
