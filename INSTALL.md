# INSTALL

Three install paths: (A) marketplace UI (recommended), (B) full bootstrap script, (C) Codex CLI (coming soon).

## A. Claude Code marketplace UI (recommended, v0.6.0+)

```
/plugin marketplace add Magerash/HAE
/plugin install hae@hae
/hae:setup
```

Three slash commands. Claude Code clones the repo, registers the marketplace from `.claude-plugin/marketplace.json`, installs the `hae` plugin from `plugins/hae/`, then `/hae:setup` bootstraps the `%USERPROFILE%\.hae\` data dir + `HAE_DATA_DIR` env + statusline.

Re-run `/hae:setup` after any Claude Code update that resets settings.json.

## B. Local install script (Windows-only, suits dev / junction mode)

```powershell
# 1. Clone the dev repo
git clone https://github.com/Magerash/HAE C:\Projects\HAE

# 2. Run installer (default: Copy to C:\Plugins\hae, data at %USERPROFILE%\.hae)
powershell -File C:\Projects\HAE\plugins\hae\scripts\install_plugin.ps1 -PersistEnv

# 3. Restart Claude Code
```

Capture starts on next prompt. Data lands in `%USERPROFILE%\.hae\prompts\raw\` from any project's Claude Code session.

The installer:
1. Robocopies plugin source from `plugins/hae/` -> `C:\Plugins\hae` (or `-CopyTo <path>`).
2. Creates local marketplace `hae-local` with junction to install dir.
3. Registers in `~/.claude/plugins/{known_marketplaces,installed_plugins}.json`.
4. Enables `hae@hae-local` in `~/.claude/settings.json`.
5. Bootstraps `%USERPROFILE%\.hae\` (or `-DataDir <path>`) data dir tree + config.
6. Persists `HAE_DATA_DIR` env (with `-PersistEnv`).
7. Rewires statusline to plugin's `statusline_universal.ps1`.

If steps 5-7 ever drift out of sync (e.g. settings.json reset by Claude Code update), run `/hae:setup` or `scripts/setup_data.ps1 -PersistEnv` to re-bootstrap.

Use Path B over Path A when you need `-Mode Junction` (live dev — install junctions to source repo, edits visible immediately) or non-default `-CopyTo` / `-DataDir` paths.

## C. Codex CLI

*Coming soon.* Codex CLI capture lands when Codex exposes equivalent `UserPromptSubmit` / `Stop` hook events. The data dir + redaction pipeline + twin agent are CLI-agnostic — the only missing piece is the hook contract.

Until then: install via **A** for Claude Code; Codex sessions will not capture, but the twin agent (when invoked from any CLI) reads the shared `~/.hae/` records.

## What gets installed

```
~/.claude/plugins/marketplaces/hae-local/             marketplace registration
                  └── plugins/hae/                     junction -> install path
~/.claude/plugins/installed_plugins.json              hae@hae-local entry
~/.claude/plugins/known_marketplaces.json             hae-local entry
~/.claude/settings.json                                enabledPlugins.hae@hae-local: true
                                                       statusLine.command (rewired to junction)

C:\Plugins\hae\                                       plugin code (default install path)
%USERPROFILE%\.hae\                                   operator data dir (cross-project)
  ├── config.json                                     operator-private overrides
  ├── prompts/raw/                                    captures from ALL projects
  ├── prompts/structured/                             classifier output
  ├── profile/                                        PAEI + HEXACO + custom + persona.md
  └── state/                                          backfill + classifier state
```

## Installer options

```powershell
powershell -File C:\Projects\HAE\scripts\install_plugin.ps1 `
  [-PluginPath <source-dir>]      `   # default: parent of scripts/
  [-CopyTo <install-target>]      `   # default: C:\Plugins\hae
  [-DataDir <data-root>]          `   # default: %USERPROFILE%\.hae
  [-Mode Copy|Junction]           `   # default: Copy. Junction = live dev
  [-PersistEnv]                       # writes HAE_DATA_DIR to user-scope env
```

`Copy` mode (default) robocopies dev -> install path, junctions marketplace at install path. Reinstall to update.

`Junction` mode skips the copy step; marketplace junction -> dev repo. Edits in dev are immediately live. Use for plugin development; not recommended for stable use.

`-DataDir` lets you put captures + profile + state on a different drive. The installer creates the dir if absent and copies `config.user.example.json` -> `<DataDir>/config.json` only on first run (preserves existing operator config).

## Configure homes

After install, tag the projects you actively work on so capture weights them at 1.0:

```
/hae:home add C:\Projects\my-app
/hae:home add C:\Projects\other-app
/hae:home list
```

Or auto-detect after a week of capture:

```
/hae:home auto-detect -Apply
```

Homes live in `<DataDir>/config.json`. Other projects get `weighting.other_weight` (default 0.3).

## Profile

Run the questionnaire to seed the twin agent:

```
/hae:profile
```

~10 minutes: PAEI 30Q + HEXACO Brief 24Q + Custom 8Q + free-form principles. Files written to `<DataDir>/profile/`.

## Backfill (optional)

Import historical Claude Code session transcripts:

```
/hae:backfill
```

Reads `~/.claude/projects/`, applies same redaction + weighting + path-PII pipeline as live capture. Idempotent.

## Verify

```
/plugin list                # hae@hae-local enabled
/reload-plugins             # 0 errors, 7 hooks, 15 agents
/hae:status                 # capture stats
/hae:twin "test"            # twin take (if persona built)
```

Type any prompt -> record at `%USERPROFILE%\.hae\prompts\raw\<date>__<sid8>.jsonl` within 1s.

## Plugin commands

After install, all skills available under `/hae:` namespace:

| Command | Purpose |
|---------|---------|
| `/hae:setup` | Re-bootstrap data dir + env + statusline if state drifts (idempotent; auto-runs in path A). |
| `/hae:status` | Capture stats + profile completeness + hook state. |
| `/hae:home` | Manage `weighting.homes` — list / add / remove / auto-detect. |
| `/hae:profile` | Run questionnaires (PAEI + HEXACO + custom) + generate persona. |
| `/hae:backfill` | Import historical Claude Code session transcripts. |
| `/hae:consolidate` | Merge per-session raw files into combined dated files. |
| `/hae:classify` | Phase 3 classifier pass (raw -> structured). |
| `/hae:twin` | Twin emulator subagent (requires Phase 2 profile + Phase 3 records). |
| `/hae:statusline` | Install / preview / restore HAE statusline. |

## Uninstall

```powershell
powershell -File C:\Projects\HAE\scripts\install_plugin.ps1 -Uninstall
```

Removes junction + registry entries. **Data dir preserved** (operator data survives).

## Migrating from in-project layout

If you previously had `.hae/` inside a host project, see [MIGRATION.md](MIGRATION.md).

## Privacy

- Hooks redact secrets before write (PAT, API key, JWT, PEM, DB URL, email, generic password/token assignments).
- Path-PII: `privacy.store_full_paths` defaults false -> cwd hashed + last 2 segments kept.
- All data dirs gitignored from this repo. Operator data NEVER committed.
- Capture failures swallow exceptions silently — never blocks Claude Code.

## Troubleshooting

- **Plugin not loading after install:** restart Claude Code (registry + statusline need fresh process).
- **No records writing:** verify `$env:HAE_DATA_DIR` set; check `<DataDir>/prompts/raw/` exists; verify `config.default.json` `capture.enabled = true`.
- **Statusline missing:** check `~/.claude/settings.json` `statusLine.command`; should point at marketplace junction `/scripts/statusline_universal.ps1`.
- **Twin says "low confidence":** profile not built or persona thin. Run `/hae:profile`.
- **`/hae:twin` hangs:** classifier pool too large for `-JsonOutput` mode. Always use markdown mode (default) — never call `twin.ps1 -JsonOutput`.
