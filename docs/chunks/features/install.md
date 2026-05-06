# Install / Uninstall

## Quick Reference

- Plugin installer: `scripts/install_plugin.ps1`
- Legacy hook-only: `scripts/install_hooks.ps1`
- Statusline installer: `scripts/install_statusline.ps1`
- Install doc: `INSTALL.md`
- Manifest: `.claude-plugin/plugin.json`
- Hook bindings: `hooks/hooks.json`
- Marketplace registry: `~/.claude/marketplaces.json`
- Settings target: `~/.claude/settings.json`
- Related chunks: `patterns/idempotent-installer.md`, `features/statusline.md`

## Overview

Two install paths:

1. **Plugin install** (`install_plugin.ps1`) - register HAE as a Claude Code plugin via local marketplace. Provides skills + agents + hooks. Recommended.
2. **Legacy hook-only** (`install_hooks.ps1`) - patches `settings.json` directly with hook bindings. No skills, no agents. Kept for environments without plugin support.

## Modes

`install_plugin.ps1` supports:

| Mode | Effect |
|------|--------|
| (default) Junction | symlink `C:\Plugins\hae` -> `C:\Projects\HAE` (dev workflow; edits are live) |
| `-Copy` | copy contents to `C:\Plugins\hae` (release workflow; edits don't propagate) |
| `-Uninstall` | remove from marketplace registry, remove install dir |
| `-DataRoot <path>` | override `%USERPROFILE%\.hae` for this user |

## Steps (install)

1. Resolve plugin source (this script's parent dir).
2. Resolve install target (`C:\Plugins\hae` default).
3. Create junction or copy contents.
4. Update `~/.claude/marketplaces.json`: register `hae-local` marketplace pointing at install dir.
5. Update `~/.claude/settings.json`: enable `hae@hae-local`.
6. Backup originals as `*.bak.<timestamp>.<guid>` before write.
7. Print smoke-test instructions.

## Steps (uninstall)

1. Remove `hae@hae-local` from `enabledPlugins` in settings.json.
2. Remove `hae-local` marketplace entry.
3. Remove install dir (junction or copied tree).
4. Leave `<dataRoot>` untouched (operator data is sacred).

## Idempotency contract

Re-running the installer must:
- Print "junction up to date" or "files in sync" without re-creating.
- Detect existing marketplace entry and refresh content (no duplication).
- Always backup before any mutation.

See `patterns/idempotent-installer.md`.

## Verification

After install:
- `/reload-plugins` reports 0 errors
- `/doctor` clean
- `/plugin list` shows `hae@hae-local` enabled
- Type a prompt -> file appears in `<dataRoot>\prompts\raw\<date>__<sid>.jsonl`

## Common Issues

- **Junction creation requires admin** in some Windows configs - fall back to `-Copy`.
- **Two HAE installs registered**: marketplace sync issue. Inspect `~/.claude/marketplaces.json`, remove duplicate `hae-local`, re-run installer.
- **Settings.json corrupted**: backup at `~/.claude/settings.json.bak.<timestamp>.<guid>` - restore by overwrite.
- **Hooks fire but no records**: hot-path script can't resolve `<dataRoot>`. Set `$env:HAE_DATA_DIR` or check `_lib.ps1` resolution order.
