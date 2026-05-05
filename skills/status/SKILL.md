---
name: status
description: Show HAE capture statistics dashboard - record counts, breakdown by project + home/other, profile completeness, structured count, plugin install state, backfill state, seeds. Use when user invokes /hae:status, asks "how much has HAE captured", "HAE stats", or wants a health check.
---

# /hae:status - HAE health snapshot

## Procedure

Run the script and surface its output verbatim:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<haeRoot>/scripts/status.ps1"
```

`<haeRoot>` is the plugin install dir. For plugin install:
`C:\Users\Magerash\.claude\plugins\marketplaces\hae-local\plugins\hae`

For direct dev path: `C:\Projects\My habits\.hae`

The script tallies:
- Plugin enable state + capture flags
- Homes list
- Raw captures: date range, total, source/event breakdown, distinct sessions, per-session vs combined files, home/other split, avg prompt length, top 10 projects
- Structured count
- Profile completeness (5-row table)
- Backfill state
- Seeds count

## Don't

- Don't reformat the script output - mirror it verbatim
- Don't print contents of any prompt or principle (privacy)
- Don't auto-run consolidate, backfill, or classify - surface them as suggested next steps only when relevant
