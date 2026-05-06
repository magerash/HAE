# Idempotent Installer Pattern

## Quick Reference

- Scripts: `scripts/install_plugin.ps1`, `scripts/install_hooks.ps1`, `scripts/install_statusline.ps1`
- Touched files: `~/.claude/marketplaces.json`, `~/.claude/settings.json`
- Backup format: `<file>.bak.<timestamp>.<guid>`
- Related chunks: `features/install.md`, `features/statusline.md`

## Overview

Installer scripts must be safe to re-run. The operator is encouraged to re-run after any schema, hook, or skill change. "Re-run" means: detect existing state, refresh content, no duplication, no destructive edits without backup.

## Rules

1. **Always backup before mutating** any file in `~/.claude/`. Backup path: `<file>.bak.<UTC-timestamp>.<guid>`. Multiple backups retained, never overwritten.
2. **Detect existing state** before write:
   - For junction: `Get-Item -LiteralPath $target -Force`; if `LinkType -eq 'Junction'` and `Target -eq $source`, print "junction up to date" and skip.
   - For copy: hash source vs target dir; if equal, print "files in sync" and skip.
   - For settings.json: parse current JSON, compare against desired state, write only if different.
3. **No duplication** in list-shaped settings (e.g. `enabledPlugins`, marketplace entries). Use a set semantics: remove existing matching entry, add fresh one.
4. **Atomic writes** for settings: write to `<file>.tmp`, then `Move-Item -Force` over the target. Avoids partial-write corruption.
5. **Print verification steps** after install so operator can confirm.

## Skeleton

```powershell
function Backup-FileSafe([string]$path) {
    if (-not (Test-Path $path)) { return }
    $stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
    $guid = [guid]::NewGuid().ToString('N').Substring(0,8)
    $bak = "$path.bak.$stamp.$guid"
    Copy-Item -LiteralPath $path -Destination $bak -Force
    return $bak
}

function Update-SettingsJson([string]$path, [scriptblock]$mutator) {
    $bak = Backup-FileSafe $path
    $json = if (Test-Path $path) {
        Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
    } else { [pscustomobject]@{} }

    & $mutator $json

    $tmp = "$path.tmp"
    ($json | ConvertTo-Json -Depth 32) | Set-Content -Path $tmp -Encoding UTF8 -NoNewline
    Move-Item -LiteralPath $tmp -Destination $path -Force
}
```

## Junction vs Copy mode

- **Junction (default)**: `New-Item -ItemType Junction -Path $target -Value $source`. Edits to source are live. Dev workflow.
- **Copy**: `Copy-Item -Recurse $source $target`. Snapshot. Release workflow.

Junction creation may require admin on some Windows configs. Fall back to copy with a clear message.

## Uninstall

- Reverse of install: remove from settings (preserve other plugins), remove from marketplaces, remove install dir.
- **Never touch `<dataRoot>`** - operator data is sacred; uninstall doesn't delete captured prompts or profile.
- Print "data preserved at <path>" so operator knows where it lives.

## Verification block (printed after install)

```
Install complete.
  Plugin source: <source>
  Install path:  <target>
  Mode:          junction|copy
  Settings backup: <bak path>

Smoke test:
  /reload-plugins   (expect 0 errors)
  /plugin list      (expect hae@hae-local enabled)
  Type any prompt -> file appears at <dataRoot>\prompts\raw\<date>__<sid>.jsonl
```

## Common Issues

- **Backup dir clutters `~/.claude/`**: prune `.bak.*` older than 90 days in a separate maintenance script - don't auto-prune in installer.
- **Two backups with same timestamp**: GUID suffix prevents collisions. Always include both.
- **Re-run drops other plugins from `enabledPlugins`**: bug. Mutator must read existing list, add HAE if missing, write back.
- **Junction created but settings missed**: installer crashed mid-flight. Re-run is safe; junction step idempotent, settings step idempotent.
