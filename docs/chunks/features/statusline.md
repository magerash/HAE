# Statusline

## Quick Reference

- Standalone: `scripts/statusline.ps1`
- Composed (OMC + HAE): `scripts/statusline_universal.ps1`
- Installer: `scripts/install_statusline.ps1`
- Skill: `/hae:statusline` -> `skills/statusline/SKILL.md`
- Settings target: `~/.claude/settings.json` `statusLine` field

## Overview

HAE optionally exposes a Claude Code statusline showing capture stats (raw count, override count, project weight, phase). Two modes:

1. **Standalone** - HAE statusline only.
2. **Composed** - OMC HUD on the left, HAE block on the right (universal version).

## `/hae:statusline` actions

| Action | Effect |
|--------|--------|
| `preview` | print statusline output once, no install |
| `install` | back up settings.json (timestamp + GUID), set `statusLine` to HAE script |
| `compose` | install `statusline_universal.ps1` (OMC + HAE) |
| `restore` | restore prior settings.json from latest backup |

Backup format: `settings.json.bak.<timestamp>.<guid>`. Multiple backups retained; latest wins on restore.

## Output shape (standalone)

```
[HAE] raw=N | over=N | home=<proj>/<weight> | phase=N
```

Compact ASCII; no emoji. Driven by `Get-HaeRawDir` + `Get-HaeStructuredDir` reads.

## Performance

Statusline is invoked by Claude Code on every prompt -> sub-200ms target. Avoid full file reads; use file count + `Measure-Object -Line` on the latest monthly + overrides files only.

## Common Issues

- **Statusline missing after install**: settings.json edited but Claude Code session needs reload (`/reload-plugins` or restart).
- **Universal version doesn't show OMC HUD**: OMC not installed or its statusline command path drifted. Reinstall OMC, then re-run `compose`.
- **Backup not restored**: `restore` picks newest `*.bak.*` by mtime; if you renamed backups manually, restore the right one by hand.
