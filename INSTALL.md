# HAE — install guide

Two install paths — **plugin install** (recommended; loads hooks + skills + agents) or **direct hooks only** (capture only, no skills).

> **Notation:** `<haeRoot>` in commands below = absolute path to your `.hae/` directory (e.g. `C:\path\to\your-project\.hae`). The installers auto-detect this path from their own location, so you usually don't need to edit it. Substitute as needed for hand-typed commands.

## Plugin install (one command)

From the `.hae/` directory on any machine:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\install_plugin.ps1
```

That script:
- Auto-detects plugin path from its own location
- Creates a local marketplace at `~/.claude/plugins/marketplaces/hae-local/`
- Junctions the plugin source into the marketplace
- Writes `marketplace.json`, registers in `known_marketplaces.json` + `installed_plugins.json`
- Sets `enabledPlugins["hae@hae-local"] = true` in `~/.claude/settings.json`
- Strips any legacy direct-hook entries (the plugin provides them)
- Backs up every modified file with timestamped suffix

Optional flags:

```powershell
# Different plugin location
scripts\install_plugin.ps1 -PluginPath "D:\my-stuff\hae"

# Different marketplace name (e.g. multiple HAE installs)
scripts\install_plugin.ps1 -MarketplaceName hae-personal

# Uninstall (removes marketplace + entries; keeps your data in prompts/ and profile/)
scripts\install_plugin.ps1 -Uninstall
```

### Verify

In Claude Code:
```
/reload-plugins              # should report: 1 plugin · 7 skills · 1 agent · 2 hooks
/plugin list                 # should show hae@hae-local enabled
```

Type `/hae:` — completion should offer `/hae:profile` `/hae:status` `/hae:home` `/hae:backfill` `/hae:consolidate` `/hae:classify` `/hae:twin`.

If `/reload-plugins` reports 0, fully restart Claude Code (some versions only read the marketplace registry at boot).

### Why a local marketplace

Claude Code only loads plugins via the marketplace registry — there's no "raw filesystem path" install mechanism. For dev without publishing to GitHub, we register a fake local marketplace. The plugin source stays in your repo (junctioned, not copied), so edits flow through instantly. After SKILL.md / hook edits, run `/reload-plugins`.

---

## Legacy: direct hooks only (capture, no skills)

If you don't want plugin install, you can wire just the capture hooks via `scripts/install_hooks.ps1`. Skills + the twin agent will NOT be loaded.

### Prerequisites for direct-hooks-only install

## Prerequisites

- Windows + PowerShell (5.1 built-in OR PowerShell 7+ `pwsh`). Installer auto-detects and prefers `pwsh` if available.
- Claude Code installed; `~/.claude/settings.json` exists
- `.hae/` checked out at `<haeRoot>` (any project path)

## Step 1 — review config

Open `.hae/config.json` and verify:

- `capture.enabled` — leave `false` for now (you flip this in Step 4)
- `capture.include_response` — set `true` only if you want Stop hook to capture assistant responses (more disk + privacy surface)
- `capture.redact_patterns` — extend if you have project-specific secrets
- `capture.max_prompt_chars` — default 50 000 fits most prompts

## Step 2 — install global hooks

```powershell
powershell "<haeRoot>\scripts\install_hooks.ps1"
```

(or `pwsh` if you have PowerShell 7)

What this does:
1. Backs up `~/.claude/settings.json` to `settings.json.hae-backup-<timestamp>.json`
2. Adds two hook entries (`UserPromptSubmit`, `Stop`) tagged `_hae_managed: true`
3. Each hook calls a script in this repo via absolute path

**Idempotent**: re-running replaces the HAE entries, leaves your other hooks untouched.

## Step 3 — restart Claude Code (REQUIRED)

Hooks are loaded into memory when a Claude Code session starts. Sessions running at install time will NOT pick up the new hooks until restarted. Close all sessions and open a new one before testing.

To verify a fresh session has hooks loaded: type any prompt, then check `.hae/prompts/spool/` — a `p-*.jsonl` file should appear within seconds.

## Step 4 — flip the switch

Edit `.hae/config.json`:

```json
"capture": { "enabled": true, ... }
```

No restart needed — scripts re-read config on every hook fire.

## Step 5 — verify

Type any prompt in any Claude Code session, then:

```powershell
Get-Content "<haeRoot>\prompts\raw\$(Get-Date -Format 'yyyy-MM-dd').jsonl" -Tail 1
```

You should see your prompt as a single JSON line.

## Step 5b — set home projects (recommended)

`weighting.homes` is empty by default. Until you populate it, every captured record gets `other_weight` (0.3) — flat signal. Two options:

**A. Manual** — if you already know the project paths:

```powershell
powershell "<haeRoot>\scripts\manage_homes.ps1" add "<your-project-path>"
```

Or invoke `/hae:home add <your-project-path>` from a Claude Code session.

**B. Auto-detect** — after capturing some records (or running backfill), let HAE find top-volume projects:

```powershell
powershell "<haeRoot>\scripts\manage_homes.ps1" auto-detect             # preview
powershell "<haeRoot>\scripts\manage_homes.ps1" auto-detect -Apply      # apply
```

Or `/hae:home auto-detect -Apply` from a session.

## Step 6 — (optional) backfill from existing history

If you want the twin to learn from your past Claude Code sessions instead of starting cold, run a one-shot backfill of `~/.claude/projects/` transcripts:

```powershell
# Preview first
powershell "<haeRoot>\scripts\backfill_history.ps1" -DryRun

# Real run
powershell "<haeRoot>\scripts\backfill_history.ps1"
```

Or invoke `/hae:backfill` from a Claude Code session. It's idempotent — tracks processed sessions in `.hae/state/backfilled_sessions.json` and skips them next time. Skip this step entirely if you'd rather only capture forward.

## Uninstall

```powershell
powershell "<haeRoot>\scripts\install_hooks.ps1" -Uninstall
```

To purge all captured data:

```powershell
Remove-Item -Recurse -Force "<haeRoot>\prompts\raw\*"
Remove-Item -Recurse -Force "<haeRoot>\state"
```

Removes only `_hae_managed: true` entries from `~/.claude/settings.json`.

## Background processes (what runs in your dock / process viewer)

HAE spawns short-lived processes at three trigger points. All use `-WindowStyle Hidden` and `-NonInteractive` so no console window flashes.

| Trigger | Process | Lifetime |
|---------|---------|----------|
| User types prompt | `powershell capture_prompt.ps1` | sub-50ms |
| Assistant finishes turn | `powershell capture_response.ps1` (only if `capture.include_response = true`) | sub-50ms |
| Statusline render | `powershell statusline_universal.ps1` (dot-sources `statusline.ps1` in-process) | ~100-300ms |
| Statusline render (if wrapping OMC/another HUD) | `cmd /c <prev-command>` invoked by wrapper | varies (e.g. `node omc-hud.mjs` ~200ms) |

**Total per render** with OMC wrapping: 1 PowerShell process (HAE) + 1 cmd shim + 1 child for the wrapped HUD (e.g. node). Without wrapping: just 1 PowerShell. All headless.

If you still see persistent processes:
- Check Task Manager for stuck `powershell.exe` instances. HAE scripts always exit on completion (no daemon, no listener).
- The OMC `node` is OMC's own child, not HAE.
- Hooks fire ONLY on prompt-submit / turn-end, not continuously.

**Why PowerShell at all (vs node like OMC):** zero install dependency on Windows. Built-in `[System.Diagnostics.Process]`, JSON parser, regex, file I/O — no external runtime needed for an open-source plugin install.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| No raw file appears after prompt | Check `~/.claude/settings.json` actually has the hook entries; verify `capture.enabled = true`; verify `pwsh` runs from a fresh shell |
| Claude Code seems slower | Hooks are async-fire-and-forget but Bash/pwsh spawn cost is non-zero. Set `include_response = false` to halve the load. |
| Sensitive content in raw log | `prompts/raw/` is gitignored. Add a redact pattern to `config.json`, run `scripts/redact_existing.ps1` (Phase 1 — not yet shipped). |
| Hook fails silently | Capture scripts swallow errors by design (must never block Claude Code). Check `$haeRoot\prompts\raw\` exists; check pwsh version `pwsh --version` ≥ 7. |
