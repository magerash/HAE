# PowerShell Conventions

## Quick Reference

- Target shell: Windows PowerShell 5.1 (NOT PowerShell 7+); some users on non-Latin locales.
- Shared lib: `scripts/_lib.ps1` (config + path helpers).
- Related chunks: `patterns/hot-path.md`, `patterns/data-root-resolution.md`, `patterns/idempotent-installer.md`

## Hard rules (HAE-specific)

- **No emoji in source or generated content** - per project rule. Strip from prompts, output, comments.
- **No em-dash** characters anywhere in `.ps1` files. Windows PS 5.1 with non-Latin locale mangles them. Use `-` or `:` instead.
- **ASCII-safe paths only**: never hardcode `C:\Users\<name>` or `%USERPROFILE%`-resolved paths in source. Always derive at runtime via `_lib.ps1`.
- **No `&&` / `||` chain operators** - PS 5.1 doesn't have them. Use `; if ($?) { ... }` or sequence statements.
- **No ternary / null-coalescing / null-conditional** (`?:`, `??`, `?.`) - not in 5.1. Use `if/else` and explicit `$null -eq` checks.
- **No `2>&1` on native exes** in PS 5.1: wraps stderr lines as ErrorRecord, sets `$? = false` even on exit 0. Don't redirect; let stderr flow.

## Encoding

- File writes: `[System.IO.File]::AppendAllText($path, $text, [System.Text.UTF8Encoding]::new($false))` (UTF-8 no-BOM).
- File reads: `Get-Content -Encoding UTF8`.
- Stdin: read raw bytes via `Console.OpenStandardInput().CopyTo($ms)`, then `Encoding.UTF8.GetString` - bypasses console code page.
- `Out-File` defaults to UTF-16 LE in 5.1 - never use without explicit `-Encoding utf8`.

## Error handling

- Cold path: `$ErrorActionPreference = 'Stop'`, surface failures.
- Hot path: `$ErrorActionPreference = 'SilentlyContinue'`, outer `try { } catch { }`, always `exit 0`. See `patterns/hot-path.md`.

## Common patterns

```powershell
# Resolve plugin root from script location (works under junction or copy)
$pluginRoot = Split-Path -Parent $PSCommandPath

# Source the lib
. "$(Split-Path -Parent $PSCommandPath)\_lib.ps1"

# Get config (merged defaults + user)
$cfg = Get-HaeConfig

# Get data dir paths
$rawDir   = Get-HaeRawDir
$strDir   = Get-HaeStructuredDir
$stateDir = Get-HaeStateDir
$profDir  = Get-HaeProfileDir
```

## Cmdlet param patterns

```powershell
[CmdletBinding()]
param(
    [Parameter(Position=0, Mandatory=$true)] [string]$Question,
    [int]$K = 6,
    [switch]$JsonOutput
)
```

Use `[CmdletBinding()]` so `-Verbose`, `-WhatIf`, `-Confirm` Just Work.

## Don't

- Don't use `Add-Content` for hot path (slow, encoding surprises).
- Don't pipe `ConvertTo-Json | Set-Content` - emit and write in one `AppendAllText` call.
- Don't rely on `$LASTEXITCODE` after `2>&1` redirect of native exe.
- Don't `Set-StrictMode -Version Latest` in hot path (overhead + surprise errors on missing PSObject members).

## Common Issues

- **Empty file written** - encoder param missed or text was `$null`; check before write.
- **JSON parse fails on round-trip** - `ConvertTo-Json -Compress -Depth 10` then `ConvertFrom-Json`. Default depth (2) loses nested objects.
- **Locale-dependent regex** - case-insensitive matching with non-ASCII letters: pass `[System.Text.RegularExpressions.RegexOptions]::IgnoreCase` explicitly.
