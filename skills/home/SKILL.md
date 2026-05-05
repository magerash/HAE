---
name: home
description: Manage HAE home-project list (config.weighting.homes). List current homes, add/remove a project, or auto-detect top-volume projects from captured records and promote them. Use when user invokes /hae:home, asks "what is HAE home", "set HAE home", "promote project to home", or "which projects are weighted high".
---

# /hae:home — manage home-project list

`weighting.homes` controls which projects get `home_weight` (1.0) vs `other_weight` (0.3) per captured record. List entries can be:

- **Path prefix** — e.g. `C:\Projects\My habits` — matches any cwd starting with this
- **Bare basename** — e.g. `My habits` — matches any cwd whose `Split-Path -Leaf` equals this

Empty homes list = nothing is home, all records get `other_weight`. That's a valid configuration but means flat training signal — not recommended once you have an active dev project.

## Procedure

Parse the user's intent into a subcommand:

| User says | Subcommand |
|-----------|-----------|
| "list", "show", "what are homes" | `list` |
| "add <X>", "set <X> as home", "promote <X>" | `add <X>` |
| "remove <X>", "unhome <X>" | `remove <X>` |
| "auto-detect", "auto-promote", "find homes from data" | `auto-detect` (preview only) |
| "auto-detect and apply", "auto-promote top N" | `auto-detect -Apply` |

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<haeRoot>\scripts\manage_homes.ps1" <subcommand> [args]
```

For `add`, accept either a full path (use as-is) OR a bare project name. If the user gives just a name and ambiguity exists in their captured projects, surface the matching cwds and ask which.

For `auto-detect`, accept optional flags:
- `-TopN N` — number of projects to promote (default from config.weighting.auto_promote.top_n, or 3)
- `-MinRecords N` — minimum captured records to qualify (default from config.weighting.auto_promote.min_records, or 100)
- `-Apply` — actually write to config; without, dry-run preview only

## Output

Mirror the script's stdout; don't reformat. Examples:

```
Current homes (2):
  - C:\Projects\My habits  [path]
  - dotfiles  [name]

Weights: home=1  other=0.3
```

```
Auto-detect — projects with >= 100 records, top 3:

project       cwd                              records sessions
-------       ---                              ------- --------
My habits     C:\Projects\My habits            1287    23
dotfiles      C:\Users\Magerash\dotfiles       412     8
sandbox       C:\Projects\sandbox              156     5

Re-run with -Apply to add the above to weighting.homes.
```

## Config takes effect immediately

Capture scripts re-read `config.json` on every hook fire. No Claude Code restart needed after `/hae:home` writes the config.

## Don't

- Don't run `auto-detect -Apply` without showing the preview first — user should see what gets promoted
- Don't add a path that doesn't exist in captured records — warn the user, offer to add anyway
- Don't write empty strings or null entries to homes
- Don't recommend setting `auto_promote.enabled = true` without explaining tradeoff (config gets mutated automatically each time /hae:status runs)
