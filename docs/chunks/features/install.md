# Install / Uninstall

## Quick Reference

- Full installer: `scripts/install_plugin.ps1` (Copy mode default; reads version from `.claude-plugin/plugin.json`)
- Bootstrap-only: `scripts/setup_data.ps1` (data dir + env + statusline)
- Legacy hook-only: `scripts/install_hooks.ps1`
- Statusline installer: `scripts/install_statusline.ps1`
- Install doc: `INSTALL.md`
- Plugin manifest: `.claude-plugin/plugin.json`
- Marketplace manifest: NOT in repo - co-existing `plugin.json` + `marketplace.json` in `.claude-plugin/` breaks plugin loading; GitHub-marketplace install needs repo restructure (plugin -> `plugins/hae/` subdir)
- Hook bindings: `hooks/hooks.json`
- Local marketplace registry: `~/.claude/plugins/known_marketplaces.json`
- Settings target: `~/.claude/settings.json`
- Related chunks: `patterns/idempotent-installer.md`, `features/statusline.md`

## Overview

Two install paths:

1. **Full bootstrap (path A)** - `install_plugin.ps1`. Copy plugin to `C:\Plugins\hae`, register local marketplace `hae-local`, junction marketplace -> install path, bootstrap `~/.hae/` data dir + env + statusline. Recommended.
2. **Legacy hook-only (fallback)** - `install_hooks.ps1` patches `settings.json` with hook bindings. No skills, no agents. Kept for environments without plugin support.

> GitHub-marketplace install (`/plugin marketplace add Magerash/HAE`) is blocked: Claude Code can't load a plugin when `plugin.json` + `marketplace.json` co-exist in the same `.claude-plugin/` dir. Repo restructure to `plugins/hae/` subdir needed; tracked as future work.

## Modes (install_plugin.ps1)

| Param | Effect |
|-------|--------|
| `-Mode Copy` (default) | robocopy plugin source -> `$CopyTo` (default `C:\Plugins\hae`); junction marketplace -> install path |
| `-Mode Junction` | marketplace junction -> source dir directly (live dev; edits propagate) |
| `-Uninstall` | remove junction + registry entries; data dir preserved |
| `-DataDir <path>` | override `%USERPROFILE%\.hae` |
| `-PersistEnv` | write `HAE_DATA_DIR` to user-scope env vars |
| `-PluginVersion <ver>` | override version (default: read from `plugin.json`) |

## Steps (install_plugin.ps1)

1. Resolve plugin source (parent of `scripts/`).
2. Read version from `.claude-plugin/plugin.json` (single source of truth).
3. Resolve `$DataDir` (env > param > `%USERPROFILE%\.hae`).
4. Copy or junction plugin to install target.
5. Junction `~/.claude/plugins/marketplaces/hae-local/plugins/hae` -> install path.
6. Write `marketplace.json` with current version.
7. Update `~/.claude/plugins/known_marketplaces.json` + `installed_plugins.json` + `settings.json` `enabledPlugins`.
8. Bootstrap data dir tree, copy `config.user.example.json` -> `<DataDir>/config.json` (first run only).
9. Set `HAE_DATA_DIR` env (process; user-scope if `-PersistEnv`).
10. Rewire `settings.json` `statusLine.command` to plugin's `statusline_universal.ps1`.
11. Backup originals as `*.hae-backup-<timestamp>-<guid>.json` before write.

## Steps (setup_data.ps1 / /hae:setup)

Subset of install_plugin.ps1 steps 8-10. For re-bootstrap when settings.json drifts (e.g. Claude Code update wipes statusline) or env var gets cleared.

1. Resolve `$DataDir`.
2. Create `~/.hae/{prompts/raw,prompts/structured,profile,state}` if missing.
3. Copy `config.user.example.json` -> `<DataDir>/config.json` (first run only).
4. Set `HAE_DATA_DIR` env (process; user-scope if `-PersistEnv`).
5. Rewire `settings.json` `statusLine.command` (skip with `-SkipStatusline`).

## Steps (uninstall)

1. Remove marketplace junction.
2. Remove marketplace dir + entry from `known_marketplaces.json`.
3. Remove plugin entry from `installed_plugins.json`.
4. Remove `enabledPlugins.hae@hae-local` from settings.json.
5. Leave `<DataDir>` untouched (operator data is sacred).

## Idempotency contract

Re-running any installer must:
- Print "junction up to date" or "user config preserved" without overwriting.
- Detect existing marketplace entry and refresh in place (no duplication).
- Always backup before any settings.json mutation (timestamped + GUID suffix).
- Never reset `HAE_DATA_DIR` if already valid.

See `patterns/idempotent-installer.md`.

## Verification

After install:
- `/reload-plugins` reports 0 errors
- `/doctor` clean
- `/plugin list` shows `hae@hae-local` enabled
- `/plugin list` shows version matching `plugin.json` (regression guard for hardcoded version bug)
- Type a prompt -> file appears in `<DataDir>\prompts\raw\<date>__<sid>.jsonl`

## Common Issues

- **Junction creation requires admin** in some Windows configs - fall back to `-Mode Copy` (default).
- **Marketplace.json shows stale version** - was hardcoded pre-v0.4.2; now reads from `plugin.json`. Re-run installer to refresh.
- **Two HAE installs registered**: marketplace sync issue. Inspect `~/.claude/plugins/known_marketplaces.json`, remove duplicate, re-run installer.
- **Settings.json corrupted**: backup at `~/.claude/settings.json.hae-backup-<timestamp>-<guid>.json` - restore by overwrite.
- **`HAE_DATA_DIR` not set after Claude Code reset**: re-run `install_plugin.ps1 -PersistEnv` or `/hae:setup persist`.
- **Hooks fire but no records (general)**: hot-path script can't resolve `<DataDir>`. Set `$env:HAE_DATA_DIR` or check `_lib.ps1` resolution order.
