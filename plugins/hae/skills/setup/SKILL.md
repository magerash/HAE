---
name: setup
description: Bootstrap HAE data dir, env vars, and statusline after marketplace install. Use when user invokes /hae:setup, just installed via /plugin install hae@hae, or asks "how do I finish HAE setup", "HAE_DATA_DIR not set", "no captures appearing after install".
---

# /hae:setup — post-install bootstrap

When HAE is installed via Claude Code marketplace (`/plugin install hae@hae` or `/plugin install hae@hae-local`), only plugin files are placed. Operator-side setup is missing:

- `HAE_DATA_DIR` env var
- `~/.hae/` data dir tree
- `<DataDir>/config.json` (from `config.user.example.json` template)
- `~/.claude/settings.json` `statusLine.command` rewire

This skill runs `scripts/setup_data.ps1` to do all of the above. Idempotent — safe to re-run.

## Procedure

Parse user intent:

| User says | Args |
|-----------|------|
| "setup", "bootstrap", "init data" | (none — defaults) |
| "setup with data dir <X>" | `-DataDir <X>` |
| "persist", "user-wide", "remember env" | `-PersistEnv` |
| "skip statusline", "don't touch statusline" | `-SkipStatusline` |

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/setup_data.ps1" [-DataDir <path>] [-PersistEnv] [-SkipStatusline]
```

Default behavior:
- `DataDir` resolves: `$env:HAE_DATA_DIR` -> `%USERPROFILE%\.hae`
- Env set for current process only (use `-PersistEnv` to write user-scope)
- Statusline rewired to plugin's `statusline_universal.ps1`

## When to run

- After `/plugin install hae@hae` (GitHub marketplace) — full bootstrap needed
- After `/plugin install hae@hae-local` (local marketplace) — only if `install_plugin.ps1` was not used
- If captures stop and `HAE_DATA_DIR` got cleared — re-run with `-PersistEnv`
- If statusline missing after Claude Code update wiped `settings.json`

## When NOT to run

- After `scripts/install_plugin.ps1 -PersistEnv` — already does all of this
- If user has custom data dir layout — ask first before running with defaults

## Output

Show user:
- Data dir created/preserved
- Config bootstrapped or preserved
- Env var scope (process vs user-wide)
- Statusline status (added/rewired/preserved)
- Restart reminder

Tell the user to restart Claude Code so the statusline + env take effect, then type any prompt to verify capture lands in `<DataDir>\prompts\raw\<date>__<sid>.jsonl`.
