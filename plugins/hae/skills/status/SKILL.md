---
name: status
description: Show HAE capture statistics dashboard - record counts, breakdown by project + home/other, profile completeness, structured count, plugin install state, backfill state. Use when user invokes /hae:status, asks "how much has HAE captured", "HAE stats", or wants a health check.
---

# /hae:status - HAE health snapshot

## Procedure

Run the script and surface its output verbatim:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/status.ps1"
```

`${CLAUDE_PLUGIN_ROOT}` resolves to the plugin install dir at runtime. Data lives in `$env:HAE_DATA_DIR` (default `%USERPROFILE%\.hae`); the script handles paths.

The script tallies:
- Plugin enable state + capture flags
- Homes list (read from operator user config)
- Raw captures: date range, total, source/event breakdown, distinct sessions, per-session vs combined files, home/other split, avg prompt length, top 10 projects
- Structured count
- Profile completeness (5-row table)
- Backfill state

## Don't

- Don't reformat the script output - mirror it verbatim
- Don't print contents of any prompt or principle (privacy)
- Don't auto-run consolidate, backfill, or classify - surface them as suggested next steps only when relevant
