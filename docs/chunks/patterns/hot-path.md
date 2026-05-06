# Hot Path Invariants

## Quick Reference

- Hot-path scripts: `scripts/capture_prompt.ps1`, `scripts/capture_response.ps1`, `scripts/statusline.ps1`, `scripts/statusline_universal.ps1`
- Budget: <50ms for hooks, <200ms for statusline.
- Related chunks: `patterns/powershell-conventions.md`, `features/capture.md`, `features/statusline.md`

## Overview

Hot-path scripts run on every Claude Code prompt. They must finish fast, never block the event loop, and never raise an exception that propagates to the user.

## Iron rules

1. **Outer `try { } catch { }` swallows everything**. The catch block may be empty; the goal is that no exception escapes.
2. **`exit 0` always** - even on caught error. A non-zero exit slows the host on next event.
3. **`$ErrorActionPreference = 'SilentlyContinue'`** at top, before sourcing lib.
4. **No network calls. No subprocess. No background jobs.** Synchronous local I/O only.
5. **No `Write-Host` to stdout/stderr** - host may pipe it somewhere visible. If you must log, write to a file in `<dataRoot>\state\`.
6. **No interactive prompts** - `Read-Host`, `Get-Credential`, `-Confirm` would hang.
7. **Bail early on disabled feature** - check `$cfg.capture.enabled` before doing anything expensive.

## Skeleton

```powershell
$ErrorActionPreference = 'SilentlyContinue'
try {
    . "$(Split-Path -Parent $PSCommandPath)\_lib.ps1"
    $cfg = Get-HaeConfig
    if (-not $cfg.capture.enabled) { exit 0 }

    # ... read stdin, build record, write JSONL ...
} catch {
    # never propagate
}
exit 0
```

## Performance levers

- **Lazy reads**: avoid `Get-ChildItem -Recurse` in hot path. For statusline, read `<dataRoot>\state\last_count.json` cached value, not raw enumeration.
- **No `ConvertFrom-Json` of large state**: if config is large, cache parsed object on disk and load by mtime check.
- **One disk write per invocation**: build full record in memory, single `AppendAllText`.
- **Skip work on `$null` early**: empty stdin -> exit 0 immediately.

## Don't

- Don't add a "just one quick HTTP call" - guaranteed to bite later.
- Don't `Sort-Object` or `Group-Object` large arrays in hot path.
- Don't use `Measure-Command` in production hot path - keep it in dev/profiling code.
- Don't introduce a shared lock file or mutex - per-session filename invariant removes the need.

## Verification

```powershell
# Time a synthetic prompt round-trip
$payload = '{"prompt":"hello","cwd":"C:\\Projects\\HAE","session_id":"test123","transcript_path":"x"}'
Measure-Command { $payload | pwsh -NoProfile -File scripts/capture_prompt.ps1 }
# TotalMilliseconds should be << 50
```

## Common Issues

- **Statusline shows stale count**: cache file not invalidated. Re-derive on read or stat raw dir mtime.
- **Hook fires but capture missing**: silent catch swallowed an error. Add a debug toggle that writes to `<dataRoot>\state\hot_path_errors.log` only when enabled.
- **PS startup overhead** dominates: profile is loaded; ensure hook command uses `-NoProfile`.
