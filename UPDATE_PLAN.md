# Plan: Split HAE plugin from habits project + global cross-project install

## Context

HAE (Human Agent Emulator) is a Claude Code plugin currently living at `C:\Projects\My habits\.hae\` (gitignored). Phase 4 done: live capture + classifier + twin agent + full operator profile shipped. Phase 5 in progress (twin pre-flight wired into `/release-plan`).

**Problem:** plugin source is mixed into habits project, plugin data (raws, profile, state) is colocated with code, and configuration includes operator-private fields (homes list, project overrides). This blocks:
- Sharing plugin to another machine or another user.
- Capture working from non-habits projects (data sink is per-project today).
- Iterating plugin code in its own git history without polluting habits.

**Goal:** plugin becomes its own dev repo at `C:\Projects\HAE\`. Users install it from the dev repo to a chosen path (default `C:\Plugins\hae`) via Copy-mode installer. Plugin captures from EVERY project into a single global data directory (default `%USERPROFILE%\.hae\`). Habits project gets cleaned of `.hae/` and updated to reference plugin via plugin-resolved paths.

**Outcome:** one global plugin install + one global data directory; clean separation between committed defaults and operator-private overrides; habits and any future project capture into the same sink with project-tagged records.

---

## Locked decisions

| # | Decision | Locked value |
|---|----------|--------------|
| D1 | Dev repo location | `C:\Projects\HAE\` (own git repo) |
| D2 | Install target | `C:\Plugins\hae` default, user-configurable via installer prompt or `-CopyTo` flag |
| D3 | Install mode | **Copy** — installer robocopies dev repo → install path, then junctions marketplace at install path. Reinstall to update. |
| D4 | Data dir | `%USERPROFILE%\.hae\` default. Override: `$env:HAE_DATA_DIR`. Resolution: env > user-config field > default. |
| D5 | Config layout | **Split.** `config.default.json` (committed in dev repo: capture flags, redact patterns, twin gates defaults, classifier categories). `config.json` (private, lives in data dir: homes, project_overrides, statusline.previous_command). Loader deep-merges user over default. |
| D6 | Twin spawn path | **Path A — Bash + inline.** `/release-plan` runs `${CLAUDE_PLUGIN_ROOT}\scripts\twin.ps1 "<q>"` via Bash, main loop composes twin block inline. No project mirror. No subagent spawn. Works for any user. |
| D7 | Project mirror at habits' `.claude/agents/hae-twin.md` | **Remove.** Public flow does not require it. Phase 6 tests `Task(subagent_type="hae-twin")` against plugin registry; if works, document upgrade path. |
| D8 | Cutover sequencing | Sequential: snapshot data → uninstall old → install new → restart. ~1 min capture downtime, accepted. Rollback by re-running old installer. |

---

## Architecture after split

```
DEV REPO (git)                    INSTALL TARGET                MARKETPLACE JUNCTION
C:\Projects\HAE\                  C:\Plugins\hae\               ~/.claude/plugins/marketplaces/hae-local/plugins/hae
  scripts\, hooks\, skills\,  --[Copy on install]-->  scripts\,...  <--[Junction]-->  (this is ${CLAUDE_PLUGIN_ROOT})
  agents\, schema\,
  config.default.json,
  README, INSTALL, CHANGELOG
                                                                                              |
                                                                                              | hooks fire from any project
                                                                                              ↓
                                                                       DATA DIR (operator-private, gitignored)
                                                                       %USERPROFILE%\.hae\  (or $env:HAE_DATA_DIR)
                                                                         config.json   (homes, overrides)
                                                                         prompts\raw\
                                                                         prompts\structured\
                                                                         profile\
                                                                         state\
```

Records from project A, project B, project C all land in the same data dir, tagged with `project`, `cwd_hash`, `is_home_project`, `project_weight`.

---

## Phasing

Six phases. Each is non-destructive until Phase 4 (cutover). Stop at any boundary.

### Phase 0 — Stand up dev repo (no functional change)
**Effort:** 30 min.

- `git init C:\Projects\HAE`, branch `main`.
- Robocopy `C:\Projects\My habits\.hae\` → `C:\Projects\HAE\` excluding `prompts\raw\*`, `prompts\structured\*`, `profile\*`, `state\*`, `*.hae-backup-*.json`. **Keep `seeds/sessions/`** — curated bootstrap training data for the classifier, belongs in dev repo.
- Initial commit: `chore: import HAE plugin source from habits .hae`.
- Add `C:\Projects\HAE\.gitignore`: `prompts/raw/*`, `prompts/structured/*`, `profile/*.json`, `profile/persona.md`, `profile/principles.md`, `state/`, `node_modules/`, `*.log`, `.vscode/`.
- Old `C:\Projects\My habits\.hae\` left untouched.

**Verify:** `git -C C:\Projects\HAE log --oneline` shows one commit; `git status` clean; old install still works.

### Phase 1 — Refactor data-path resolution
**Effort:** 2-3 hrs.

Goal: every script reads/writes data through helper, never via hardcoded `"$haeRoot\prompts\..."`.

**New file:** `C:\Projects\HAE\scripts\_lib.ps1`. Functions:
- `Resolve-HaePluginRoot` — `Split-Path -Parent (Split-Path -Parent $PSCommandPath)`.
- `Resolve-HaeDataRoot` — env var > user config field > `Join-Path $env:USERPROFILE '.hae'`.
- `Get-HaeConfig` — load `<plugin>\config.default.json`, deep-merge `<dataRoot>\config.json` over it.
- `Get-HaeRawDir`, `Get-HaeStructuredDir`, `Get-HaeProfileDir`, `Get-HaeStateDir` — Join-Path against data root.
- `Ensure-HaeDataRoot` — mkdir -p the four subdirs on first use.

**Refactor scripts (dot-source `_lib.ps1`):**

| Script | Current pattern | New pattern |
|--------|-----------------|-------------|
| `capture_prompt.ps1` | `Join-Path $haeRoot $config.sink.raw_dir` | `Get-HaeRawDir` |
| `capture_response.ps1` | same | same |
| `backfill_history.ps1` | `Join-Path $haeRoot 'prompts\raw'` + `state` literal | `Get-HaeRawDir` + `Get-HaeStateDir` |
| `classify.ps1` | `"$haeRoot\prompts\raw"` etc literals | `Get-HaeRawDir` + `Get-HaeStructuredDir` + `Get-HaeStateDir` |
| `classify_nightly.ps1` | `Join-Path $haeRoot 'prompts\raw'` | helpers |
| `consolidate.ps1` | `Join-Path $haeRoot $config.sink.raw_dir` | `Get-HaeRawDir` |
| `manage_homes.ps1` | reads/writes `<plugin>\config.json` | reads/writes `<dataRoot>\config.json` (user file only) |
| `status.ps1` | `"$haeRoot\prompts\raw"`, `"$haeRoot\profile"` | helpers |
| `twin.ps1` | `"$haeRoot\prompts\structured"`, `"$haeRoot\profile"` | helpers |
| `report.ps1` | all four literal | helpers |
| `statusline.ps1` | three literals | helpers |
| `statusline_universal.ps1` | reads previous_command from plugin config | reads from merged config (user override wins) |

**Hot path test:** `_lib.ps1` dot-source + helper resolution + JSON merge must keep capture_prompt.ps1 under 50ms. Benchmark on 10 fires; if it regresses, inline the resolution into capture scripts (they only need raw_dir, can skip the full merge).

**Config split (D5):**
- `C:\Projects\HAE\config.default.json` = current `config.json` MINUS `weighting.homes`, `weighting.project_overrides`, `statusline.previous_command`. Add explicit `_doc` keys explaining each section.
- `<dataRoot>\config.json` = these three operator-private fields. Created on first install (installer copies a starter from dev repo's `config.user.example.json`).
- `Get-HaeConfig` deep-merges with operator file winning.

**Verify:**
- `$env:HAE_DATA_DIR=C:\temp\hae-test`; pipe stub stdin to `capture_prompt.ps1` → record at `C:\temp\hae-test\prompts\raw\<date>__<sid>.jsonl`.
- Unset env, set `haeDataRoot` field in test user config → same.
- Unset both → default `%USERPROFILE%\.hae`.
- Old install in habits `.hae/` untouched, still works.
- New `C:\Projects\HAE\` not registered yet — staged only.

### Phase 2 — SKILL.md and agent path templating
**Effort:** 1 hr.

Sweep every file under `C:\Projects\HAE\skills\*\SKILL.md` and `C:\Projects\HAE\agents\*.md`. Replace literal user paths with placeholders.

**Replace:**
- `C:\Users\Magerash\.claude\plugins\marketplaces\hae-local\plugins\hae` → `${CLAUDE_PLUGIN_ROOT}`
- `C:\Projects\My habits\.hae` → `${CLAUDE_PLUGIN_ROOT}`
- Hardcoded data paths in prose → "data lives at `$env:HAE_DATA_DIR` (default `%USERPROFILE%\.hae`)"

**Files to verify (all SKILL.md files have hardcoded paths per exploration):**
- `skills/status/SKILL.md` (lines 13-19: marketplace + dev path embedded)
- `skills/backfill/SKILL.md` (lines 23-32: 4 occurrences of dev path)
- `skills/consolidate/SKILL.md` (line 12)
- `skills/classify/SKILL.md` (line 10)
- `skills/twin/SKILL.md` (verify, no current findings)
- `skills/profile/SKILL.md` (verify)
- `skills/home/SKILL.md` (verify)
- `skills/statusline/SKILL.md` (verify)
- `skills/classify-bulk/SKILL.md` (verify)
- `agents/hae-twin.md` (already uses `.hae/scripts/twin.ps1` — change to `${CLAUDE_PLUGIN_ROOT}/scripts/twin.ps1`)

**Verify:** `grep -ri 'Magerash\|My habits\|\\.hae\\\\\|\\.hae/' C:\Projects\HAE` returns ZERO hits except CHANGELOG history, README example blocks (clearly marked as historical), MIGRATION.md (Phase 6).

### Phase 3 — Installer overhaul
**Effort:** 2 hrs.

Rewrite `C:\Projects\HAE\scripts\install_plugin.ps1` for Copy-mode + data-dir handling.

**New parameter surface:**
```
param(
    [string]$PluginPath,           # source (default: parent of scripts/)
    [string]$CopyTo = 'C:\Plugins\hae',  # install target
    [string]$DataDir,              # data root (default: %USERPROFILE%\.hae)
    [string]$MarketplaceName = 'hae-local',
    [string]$PluginName = 'hae',
    [string]$PluginVersion = '0.4.0',
    [switch]$PersistEnv,           # write HAE_DATA_DIR to user-scope env vars
    [switch]$Uninstall,
    [switch]$Force
)
```

**Logic:**
1. Resolve `$PluginPath` (caller or auto from `$PSCommandPath`).
2. Prompt user for `$CopyTo` if interactive and not provided (default `C:\Plugins\hae`); same for `$DataDir`.
3. **Copy:** robocopy `$PluginPath` → `$CopyTo` /MIR /XD prompts profile state seeds\sessions /XF *.hae-backup-*.json. Set `$EffectivePath = $CopyTo`.
4. **Marketplace:** create `~/.claude/plugins/marketplaces/hae-local/.claude-plugin/marketplace.json` if missing; junction `~/.claude/plugins/marketplaces/hae-local/plugins/hae` → `$EffectivePath`.
5. **Data dir:** create `$DataDir` and four subdirs (`prompts/raw`, `prompts/structured`, `profile`, `state`). Copy `$EffectivePath\config.user.example.json` → `$DataDir\config.json` ONLY if absent (preserve existing operator config).
6. **Env var:** if `-PersistEnv`, `[Environment]::SetEnvironmentVariable('HAE_DATA_DIR', $DataDir, 'User')`. Otherwise just set for current process and tell user to add to PowerShell profile.
7. **Registry updates:** `installed_plugins.json` → `hae@hae-local` entry with `installPath` = marketplace junction path. `known_marketplaces.json` → `hae-local` entry. `~/.claude/settings.json` → `enabledPlugins.hae@hae-local: true`. All with backup-before-write (existing pattern).
8. **Statusline rewire:** `~/.claude/settings.json` `statusLine.command` → `${marketplace junction}\scripts\statusline_universal.ps1`. (Junction-relative, survives dev repo move.)
9. Print summary: source, install target, data dir, env-var status, registry entry.

**Uninstall path:** remove marketplace junction, registry entries, statusLine command (or restore previous if backup present). **Never** delete `$DataDir` (operator data preserved).

**`scripts/install_hooks.ps1`:** legacy direct-hook installer — refactor for new helper paths but keep as fallback. Mark deprecated in skill docs.

**Verify:**
- `C:\Projects\HAE\scripts\install_plugin.ps1` (no args) → prompts, defaults `C:\Plugins\hae` + `%USERPROFILE%\.hae`. Plugin runs from `C:\Plugins\hae`. Data lands in `%USERPROFILE%\.hae`.
- Re-run idempotency: "junction up to date", no duplicates.
- `-Uninstall` removes junction + registry; data dir intact.
- `-CopyTo D:\plugins\hae -DataDir D:\hae-data` works.
- Smoke: type prompt in habits → record at `<DataDir>\prompts\raw\<date>__<sid>.jsonl` within 1s.
- Smoke from other project: `cd C:\Projects\some-other-repo`, type prompt → record lands in same dir, `project` field tags it.

### Phase 4 — Migration cutover
**Effort:** 1 hr (mostly verification).

Pre-flight (read-only):
- Confirm `C:\Projects\My habits\.hae\` install is current (junction at `~/.claude/plugins/marketplaces/hae-local/plugins/hae`).
- Baseline counts: `/hae:status` numbers (raw, structured, overrides).
- Confirm `C:\Projects\HAE\` is Phase 0-3 complete.

Sequence (single PowerShell session):

1. **Snapshot data** (no destructive op yet):
   ```
   robocopy "C:\Projects\My habits\.hae\prompts" "$env:USERPROFILE\.hae\prompts" /MIR /COPY:DAT
   robocopy "C:\Projects\My habits\.hae\profile" "$env:USERPROFILE\.hae\profile" /MIR /COPY:DAT
   robocopy "C:\Projects\My habits\.hae\state" "$env:USERPROFILE\.hae\state" /MIR /COPY:DAT
   ```
2. **Snapshot user config:** copy `C:\Projects\My habits\.hae\config.json` → `$env:USERPROFILE\.hae\config.json` verbatim. (Preserves homes, overrides, previous_command.)
3. **Verify counts** match baseline. Diff record file counts.
4. **Uninstall old:**
   ```
   powershell -File "C:\Projects\My habits\.hae\scripts\install_plugin.ps1" -Uninstall
   ```
   Removes marketplace junction + registry entries. Old `.hae\` files untouched on disk.
5. **Install new:**
   ```
   powershell -File "C:\Projects\HAE\scripts\install_plugin.ps1" -CopyTo "C:\Plugins\hae" -DataDir "$env:USERPROFILE\.hae" -PersistEnv
   ```
6. **Restart Claude Code** (statusline + plugin registry need fresh process pickup).

Post-migration verification (must all pass):
- `/plugin list` shows `hae@hae-local` enabled.
- `/reload-plugins` reports 0 errors.
- `/hae:status` shows record counts identical to baseline.
- Type prompt in habits → new record in `%USERPROFILE%\.hae\prompts\raw\` within 1s.
- Type prompt in different project → record lands in same dir, `project` field tags it.
- `/hae:home list` shows previous homes from snapshot config.
- `/hae:twin "test"` returns twin block.
- Statusline renders both rows.

**Rollback** (if anything fails):
1. `C:\Projects\HAE\scripts\install_plugin.ps1 -Uninstall`.
2. `C:\Projects\My habits\.hae\scripts\install_plugin.ps1` (re-installs old).
3. Restore statusLine from `~/.claude/settings.json` backup file.
4. Old data sink (`C:\Projects\My habits\.hae\prompts\`) untouched throughout — safe to fall back to.

### Phase 5 — Habits project cleanup
**Effort:** 30 min.

Update files referencing `.hae/` paths:

| File | Change |
|------|--------|
| `C:\Projects\My habits\.gitignore` line 76 | Remove `.hae` (dir gone) |
| `C:\Projects\My habits\.claude\settings.local.json` line 128 | Update permission path: `C:\Projects\My habits\.hae\scripts\install_hooks.ps1` → `C:\Plugins\hae\scripts\install_hooks.ps1` (or remove if unused) |
| `C:\Projects\My habits\.claude\agents\hae-twin.md` | **Delete** (D7 — drop mirror) |
| `C:\Projects\My habits\.claude\agents\release-manager.md` lines 106, 112, 129, 153, 175 | Path refs: `.hae/config.json` → "twin gates in `${CLAUDE_PLUGIN_ROOT}\config.default.json` (defaults) merged with `<dataRoot>\config.json` (user)". `.hae/profile/persona.md` → "operator persona at `<dataRoot>\profile\persona.md`". `.hae/scripts/twin.ps1` → "via plugin install — main loop runs `${CLAUDE_PLUGIN_ROOT}\scripts\twin.ps1` through Bash". Drop spawn-twin instructions; clarify main loop owns it. |
| `C:\Projects\My habits\.claude\commands\release-plan.md` step 8 | Replace mirror-spawn block with **Path A**: Bash run `${CLAUDE_PLUGIN_ROOT}\scripts\twin.ps1 "<question>"`, capture markdown, compose twin block inline. Drop `subagent_type="hae-twin"` Task call. Drop fallback (it IS the path now). Update `.hae/config.json` reference to `<dataRoot>\config.json` for gate flag check. |
| Memory: `feedback_hae_scope.md` | Update body: "post-2026-05 split: HAE plugin now at `C:\Projects\HAE\` (dev repo). Install at `C:\Plugins\hae`. Data at `%USERPROFILE%\.hae\`. `.hae/` removed from habits project." Keep historical context. |
| Memory: `reference_hae_install_methods.md` | Update install paths + procedure to match new flow. |
| Memory: `reference_hae_twin_integration.md` | Update path refs from `.hae/...` to `${CLAUDE_PLUGIN_ROOT}\...` and `<dataRoot>\...`. |
| `C:\Projects\My habits\.hae\` directory | Leave for 1-2 weeks as cold backup, then delete. |

**Verify:**
- `git -C "C:\Projects\My habits" status` → expected diffs only (gitignore, settings.local, release-manager, release-plan, deleted hae-twin.md).
- `/release-plan` runs end-to-end with twin pre-flight banner working via Path A.
- `grep -r '\.hae[\\/]' "C:\Projects\My habits"` returns hits only in memory entries' historical text.

### Phase 6 — Polish, docs, first release, optional Path C test
**Effort:** 1-2 hrs.

- Update `C:\Projects\HAE\README.md`: install instructions for new flow. Drop habits framing. Mention env var, default paths, how all-projects capture works.
- Update `C:\Projects\HAE\INSTALL.md`: walk through default install + custom paths + uninstall.
- Update `C:\Projects\HAE\CHANGELOG.md`: `v0.4.0 — split into own repo + global cross-project data + Copy-mode installer + config split + Path A twin`. Document breaking change (data dir moved).
- Add `C:\Projects\HAE\MIGRATION.md`: Phase 4 sequence as runnable script for any user coming from in-project layout.
- Bump `.claude-plugin/plugin.json` and `config.default.json` `version: 0.4.0`. Bump CLAUDE.md current-version block.
- Optional `scripts/migrate_from_inproject.ps1`: encapsulates Phase 4 sequence for reuse on other machines.
- Tag git: `git -C C:\Projects\HAE tag v0.4.0`.

**Optional Path C test (D6 follow-up):**
- From clean Claude Code session post-install, attempt `Task(subagent_type="hae-twin")` with no `hae:` prefix. If resolves → plugin agent registry works for plain names. Document in INSTALL.md as "available named-twin spawn method". If fails → keep Path A as canonical, file Claude Code feedback.

**Verify:**
- HAE plugin works from any project: open Claude Code in `C:\Projects\some-other-repo`, prompt fires, record lands in shared data dir.
- `git -C C:\Projects\HAE log --oneline` reads as clean history.
- Smoke `/release-plan` end-to-end one more time.

---

## Critical files

**To create:**
- `C:\Projects\HAE\scripts\_lib.ps1` (helper)
- `C:\Projects\HAE\config.default.json` (committed defaults)
- `C:\Projects\HAE\config.user.example.json` (template copied to data dir on first install)
- `C:\Projects\HAE\MIGRATION.md` (operator's runbook)
- `C:\Users\Magerash\.hae\config.json` (post-Phase-4: snapshot of habits' current config minus committed defaults)

**To modify (HAE dev repo):**
- `C:\Projects\HAE\scripts\install_plugin.ps1` (Phase 3 overhaul)
- `C:\Projects\HAE\scripts\capture_prompt.ps1` (hot path — refactor + benchmark)
- `C:\Projects\HAE\scripts\capture_response.ps1`
- `C:\Projects\HAE\scripts\classify.ps1`
- `C:\Projects\HAE\scripts\classify_nightly.ps1`
- `C:\Projects\HAE\scripts\consolidate.ps1`
- `C:\Projects\HAE\scripts\backfill_history.ps1`
- `C:\Projects\HAE\scripts\manage_homes.ps1`
- `C:\Projects\HAE\scripts\status.ps1`
- `C:\Projects\HAE\scripts\twin.ps1`
- `C:\Projects\HAE\scripts\report.ps1`
- `C:\Projects\HAE\scripts\statusline.ps1`
- `C:\Projects\HAE\scripts\statusline_universal.ps1`
- `C:\Projects\HAE\skills\*\SKILL.md` (path templating, all files)
- `C:\Projects\HAE\agents\hae-twin.md` (path templating)
- `C:\Projects\HAE\.claude-plugin\plugin.json` (version bump v0.4.0)
- `C:\Projects\HAE\CLAUDE.md` (Phase 5 done, version bump)
- `C:\Projects\HAE\CHANGELOG.md`
- `C:\Projects\HAE\README.md`
- `C:\Projects\HAE\INSTALL.md`

**To modify (habits project):**
- `C:\Projects\My habits\.gitignore` (remove `.hae` line)
- `C:\Projects\My habits\.claude\settings.local.json` (update permission entry)
- `C:\Projects\My habits\.claude\agents\release-manager.md` (lines 106, 112, 129, 153, 175 path rewrites)
- `C:\Projects\My habits\.claude\commands\release-plan.md` (step 8 rewrite to Path A only)

**To delete (habits project):**
- `C:\Projects\My habits\.claude\agents\hae-twin.md` (mirror, D7)
- `C:\Projects\My habits\.hae\` (after 1-2 week verification window)

**To modify (memory):**
- `C:\Users\Magerash\.claude\projects\C--Projects-My-habits\memory\feedback_hae_scope.md`
- `C:\Users\Magerash\.claude\projects\C--Projects-My-habits\memory\reference_hae_install_methods.md`
- `C:\Users\Magerash\.claude\projects\C--Projects-My-habits\memory\reference_hae_twin_integration.md`
- `C:\Users\Magerash\.claude\projects\C--Projects-My-habits\memory\MEMORY.md` (entry descriptions if changed)

**To modify (global config — done by Phase 3 installer):**
- `C:\Users\Magerash\.claude\settings.json` (statusLine.command path + enabledPlugins)
- `C:\Users\Magerash\.claude\plugins\installed_plugins.json` (path stays, junction target moves)
- `C:\Users\Magerash\.claude\plugins\known_marketplaces.json` (no change — marketplace dir same)

---

## Risk register

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Capture downtime during cutover | High during Phase 4 | Low (~1 min) | Snapshot first, fast cutover, rollback ready |
| Helper dot-source slows hot path | Med | Med (>50ms hook = lag) | Benchmark `_lib.ps1` in capture path. If regress: inline raw_dir resolution into capture scripts only |
| `${CLAUDE_PLUGIN_ROOT}` doesn't expand inside SKILL.md prose (only inside hooks.json command strings) | Med | Med (skills give wrong paths) | Verify on one skill first. If unexpanded: fallback to marketplace junction literal path in skill text, document as stable cross-machine for any user |
| Path A twin spawn missing from HUD agent tree | Low | Low | Documented trade-off (D6). Phase 6 tests Path C as upgrade. |
| Old `.hae/` accidentally re-engaged via stale settings | Low | Low | Phase 4 step 4 explicitly uninstalls old; Phase 5 cleans habits permission |
| Data-dir env var unset, default writes to `%USERPROFILE%\.hae` silently — user surprised | Low | Low | Installer prints resolved data dir prominently; first capture writes to known path |
| Config merge bug — user config silently ignored | Med | Med | Smoke `/hae:home list` post-Phase-4 to verify homes survived |
| Habits `release-plan.md` regresses twin behavior after Path A rewrite | Med | High (RM is operator's main interface) | Full `/release-plan` smoke after Phase 5; rollback restores prior `.claude/commands/release-plan.md` from git |
| Some skill SKILL.md missed in path sweep | Low | Low | Final grep step in Phase 2 for literal user/path strings |
| Backfill state file stale at old location post-cutover | Low | Med | Phase 4 step 1 robocopies state dir; helper resolves only to data dir |
| Public users without `git` CLI can't clone dev repo | Low | Low | INSTALL.md offers ZIP-download fallback path |

---

## Effort summary

| Phase | Effort |
|-------|--------|
| 0. Stand up dev repo | 30 min |
| 1. Refactor data-path resolution | 2-3 hrs |
| 2. SKILL.md / agent path templating | 1 hr |
| 3. Installer overhaul | 2 hrs |
| 4. Migration cutover | 1 hr (mostly verify) |
| 5. Habits cleanup | 30 min |
| 6. Polish + first release + Path C test | 1-2 hrs |
| **Total** | **8-10 hrs** |

Phases 0-3 non-destructive (habits install untouched). Stop after any of the first three is safe; resume later.

---

## Verification — end-to-end smoke test

After Phase 6, run this from a clean Claude Code session:

1. `cd C:\Projects\My habits`; type any prompt → record lands in `%USERPROFILE%\.hae\prompts\raw\<date>__<sid>.jsonl`. Project field = `My habits`. is_home_project = true. project_weight = 1.0.
2. `cd C:\Projects\some-other-repo`; type any prompt → record in same dir. Project field tags it. is_home_project = false. project_weight = 0.3.
3. `/hae:status` → shows totals across all projects, breakdown per-project.
4. `/hae:home list` → shows habits as home; other repo as `other`.
5. `/hae:twin "should I cut feature X?"` → returns twin block with persona + exemplars from global pool.
6. `/release-plan` → end-to-end runs; Phase 8 surfaces twin pre-flight banner above scope table; user picks option.
7. `/plugin list` → `hae@hae-local` enabled, source resolves through marketplace junction to `C:\Plugins\hae`.
8. `/reload-plugins` → 0 errors.
9. Restart Claude Code → all of the above still works (statusline survives, env var persisted, registry stable).
10. `git -C C:\Projects\HAE status` → clean. `git tag` shows `v0.4.0`.
