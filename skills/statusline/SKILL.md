---
name: statusline
description: Manage HAE statusline integration. Show preview, install standalone HAE statusline, install wrapper that composes OMC + HAE, or restore prior statusLine. Use when user invokes /hae:statusline, asks "show HAE status bar", "enable HAE statusline", "wrap OMC with HAE", or "restore old statusline".
---

# /hae:statusline - manage statusline integration

HAE ships two statusline scripts:

- `scripts/statusline.ps1` - HAE-only segment (replaces whatever you had)
- `scripts/statusline_with_omc.ps1` - composes OMC HUD + HAE segment with " | " separator

## Procedure

Parse user intent into a subcommand:

| User says | Action |
|-----------|--------|
| "preview", "show" | Run `scripts/statusline.ps1` and print output |
| "preview wrapper", "show with omc" | Run `scripts/statusline_with_omc.ps1` and print output |
| "install standalone", "use HAE only" | Set settings.json statusLine.command to `powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/statusline.ps1"` |
| "install wrapper", "compose with omc", "use both" | Set to `statusline_with_omc.ps1` (assumes OMC HUD at `~/.claude/hud/omc-hud.mjs`) |
| "restore", "revert" | Find latest `~/.claude/settings.json.hae-backup-*.json` whose statusLine differs and restore that statusLine value |
| "uninstall" | Remove statusLine entry entirely |

Always backup `settings.json` with timestamp suffix before modifying.

## What the segment shows

```
[hae#0.1.0] cap:ON 12r/3s/127t home:My habits prof:PHCr* str:42 next:/hae:classify
```

| Token | Meaning |
|-------|---------|
| `[hae#X.Y.Z]` | Plugin version from manifest |
| `cap:ON` / `cap:OFF` | `config.capture.enabled` flag |
| `Nr/Ms/Tt` | N records today (UTC), M distinct sessions today, T total records all-time |
| `home:<name>` | First entry in `weighting.homes`, or `homes:N` if multiple |
| `!nohome` | Warning when `weighting.homes` is empty |
| `prof:PHCr*` | Profile completeness: P=PAEI / H=HEXACO / C=Custom / r=pRinciples / `*`=persona-generated; `-` if missing |
| `str:N` | Structured records count (Phase 3+); omitted if 0 |
| `next:<hint>` | Actionable next step (omitted when nothing pressing) |

## Don't

- Don't modify `statusLine.command` without backing up settings.json first
- Don't auto-overwrite without checking if user already has a custom (non-OMC, non-HAE) statusline; ask first if so
- Don't include emoji in the status output - keep ASCII only
- Don't make the segment longer than ~80 chars - status bars truncate
