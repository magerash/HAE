# Data Root Resolution

## Quick Reference

- Helper: `Resolve-HaeDataRoot` in `scripts/_lib.ps1`
- Resolution order: `$env:HAE_DATA_DIR` -> user config `dataRoot` -> `%USERPROFILE%\.hae`
- All path-producing helpers: `Get-HaeRawDir`, `Get-HaeStructuredDir`, `Get-HaeStateDir`, `Get-HaeProfileDir`, `Get-HaeOverridesFile`
- Related chunks: `patterns/powershell-conventions.md`, `architecture/overview.md`

## Overview

HAE separates code (in repo) from data (in operator's home). All scripts derive paths through `_lib.ps1` helpers. No script hardcodes a user-specific path.

## Resolution order

`Resolve-HaeDataRoot` checks, in order:

1. `$env:HAE_DATA_DIR` - explicit override (CI, tests, multi-tenant).
2. User config file `<%USERPROFILE%\.hae>\config.user.json` -> `dataRoot` field. (Bootstrap chicken-and-egg: the helper looks for the user config in the default location to read the override location. If it points elsewhere, future calls follow.)
3. Fallback: `%USERPROFILE%\.hae`.

Result is created if missing (`New-Item -ItemType Directory -Force`).

## Subdir helpers

```powershell
Get-HaeRawDir         # <root>\prompts\raw
Get-HaeStructuredDir  # <root>\prompts\structured
Get-HaeStateDir       # <root>\state
Get-HaeProfileDir     # <root>\profile
Get-HaeOverridesFile  # <root>\prompts\structured\overrides.jsonl
```

Each ensures the parent dir exists before returning.

## Config resolution

`Get-HaeConfig` returns merged result of:

1. `<pluginRoot>\config.default.json` (shipped, read-only).
2. `<dataRoot>\config.user.json` (operator overrides; optional).

User config wins per top-level key. Lists (e.g. `redact_patterns`, `homes`) are replaced wholesale, not merged - so user config that wants to extend defaults must include them.

Read on every call (no cache). Hot-path callers tolerate this because file is small.

## Why this matters

- Standalone repo: `C:\Projects\HAE` -> ships to `C:\Plugins\hae` -> data at `%USERPROFILE%\.hae`. No data in either code dir.
- CI: set `$env:HAE_DATA_DIR = "$PWD\test-data"` to redirect to a per-job sandbox.
- Multi-user: each user's `%USERPROFILE%\.hae` is separate. No cross-user data leak.

## Anti-patterns

- Hardcoding `"$env:USERPROFILE\.hae"` in a script - bypasses env override.
- Caching `$dataRoot` at module load - if `$env:HAE_DATA_DIR` changes mid-session (e.g. test setup), stale value sticks.
- Writing to `<pluginRoot>` from a script - data must never live alongside code.

## Common Issues

- **Records vanish after env tweak**: `$env:HAE_DATA_DIR` changed without moving prior data. Either move data or unset the env.
- **User config not picked up**: file exists but at the wrong path. Resolver checks default location first; if user moved data root, copy `config.user.json` to the new location too.
- **Permission denied on `%USERPROFILE%\.hae`**: rare on Windows; check ACL inheritance from profile root.
