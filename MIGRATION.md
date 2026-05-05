# MIGRATION

## v0.3.x → v0.4.0

Breaking: plugin source split out of host project; data directory moved to operator's home; config layout split into committed defaults + operator-private overrides.

### TL;DR

If you're coming from the in-project layout where `.hae/` lived inside your active project (e.g. `C:\Projects\My habits\.hae\`):

1. Snapshot data to new global location.
2. Uninstall old plugin.
3. Install fresh from new dev repo location.
4. Restart Claude Code.

Your prompts/structured/profile/state survive intact. `weighting.homes` is preserved.

### Prerequisites

- Working install of HAE v0.3.x (junction at `~/.claude/plugins/marketplaces/hae-local/plugins/hae` → some in-project `.hae/` dir).
- HAE dev repo cloned to `C:\Projects\HAE\` (this repo).

### Step 1 — Snapshot data

```powershell
$src = "C:\Projects\My habits\.hae"   # or wherever your old .hae lives
$dst = "$env:USERPROFILE\.hae"

foreach ($sub in 'prompts','profile','state') {
    $s = Join-Path $src $sub
    $d = Join-Path $dst $sub
    if (Test-Path $s) {
        robocopy $s $d /MIR /COPY:DAT /NFL /NDL /NJH /NJS /NP | Out-Null
    }
}
```

### Step 2 — Snapshot user config

The pre-v0.4.0 `config.json` mixed defaults and operator-private fields. The new layout puts operator-private fields in a separate file at `<dataRoot>/config.json`. The installer's `config.user.example.json` template is the right shape.

If you have customized `weighting.homes`, `weighting.project_overrides`, or `statusline.previous_command`, write a minimal user config preserving them:

```powershell
$old = "C:\Projects\My habits\.hae\config.json"
$new = "$env:USERPROFILE\.hae\config.json"
$cfg = Get-Content $old -Raw -Encoding UTF8 | ConvertFrom-Json
$user = @{
    haeDataRoot = $null
    weighting = @{
        homes = $cfg.weighting.homes
        project_overrides = $cfg.weighting.project_overrides
    }
    statusline = @{
        previous_command = $cfg.statusline.previous_command
    }
}
$user | ConvertTo-Json -Depth 10 | Set-Content $new -Encoding UTF8
```

If you skip this, the installer copies a stub `config.user.example.json` with empty values; you can re-add homes via `/hae:home add <path>`.

### Step 3 — Uninstall old plugin

```powershell
powershell -File "C:\Projects\My habits\.hae\scripts\install_plugin.ps1" -Uninstall
```

Removes marketplace junction + registry entries. The on-disk `.hae/` dir is untouched (cold backup).

### Step 4 — Install new plugin

```powershell
powershell -File C:\Projects\HAE\scripts\install_plugin.ps1 `
  -CopyTo "C:\Plugins\hae" `
  -DataDir "$env:USERPROFILE\.hae" `
  -PersistEnv
```

Installer prints summary: source, install target, junction path, data dir, env var status.

### Step 5 — Restart Claude Code

The plugin registry + statusline command both need a fresh process to pick up changes. Close and reopen Claude Code (or run `/reload-plugins` if no statusline change).

### Step 6 — Verify

In Claude Code:

- `/plugin list` → `hae@hae-local` enabled, source resolves through marketplace junction to `C:\Plugins\hae`.
- `/reload-plugins` → 0 errors.
- `/hae:status` → record counts match what you snapshotted.
- Type any prompt → new record appears in `%USERPROFILE%\.hae\prompts\raw\<date>__<sid>.jsonl` within 1s.
- Open Claude Code in a different project → type prompt → record lands in same shared data dir, `project` field tags origin.
- `/hae:home list` → previously configured homes intact.
- `/hae:twin "test"` → returns twin block with persona + exemplars from global pool.

### Step 7 — Clean up old in-project `.hae/`

After 1-2 weeks of new install running clean, delete the cold backup:

```powershell
Remove-Item "C:\Projects\My habits\.hae" -Recurse -Force
```

### Rollback

If something breaks in step 5 or 6:

1. Uninstall new: `powershell -File C:\Projects\HAE\scripts\install_plugin.ps1 -Uninstall`
2. Reinstall old: `powershell -File "C:\Projects\My habits\.hae\scripts\install_plugin.ps1"`
3. Restore `~/.claude/settings.json` from a recent `*.hae-backup-*.json` (the installer leaves these next to every modified file).
4. Old data sink at `C:\Projects\My habits\.hae\prompts\` is untouched throughout — old plugin keeps working from there.

The new data dir at `%USERPROFILE%\.hae\` is left in place as a safe-to-delete duplicate.

## Why the split

- Plugin source must work for any operator, not just one in-project layout.
- Data must capture across all projects, not just one.
- Operator-private config (homes list with full paths) must not commit to a public dev repo.
- Plugin code must iterate independently of any host project's commits.
