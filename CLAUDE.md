# HAE - AI Assistant Instructions

Plugin instructions for Claude Code when working inside the HAE dev repo (`C:\Projects\HAE` typical) or its installed copy. Standalone plugin; data lives in operator's data dir, not in the repo.

## Core Rules

- **Privacy first** - never bypass redaction patterns or `privacy.store_full_paths` default; raw prompts can contain unredacted PII before scrubbing.
- **Hot path < 50ms** - capture scripts (`scripts/capture_*.ps1`) must never block Claude Code. Wrap everything in `try { } catch { }`, exit 0 on all errors.
- **No silent schema breaks** - changes to `schema/record.schema.json` require migration plan for existing `prompts/raw/` records.
- **No emoji in code or generated content** - per habits project rule. Markdown docs and skill output use plain text only.
- **No em-dash characters in PowerShell sources** - Windows PowerShell 5.1 with non-Latin locale mangles them. Use `-` or `:` instead.
- **ASCII-safe paths** - never hardcode user-specific paths in source. Scripts derive plugin root from `$PSCommandPath` and data root from `Resolve-HaeDataRoot` helper (env > user config > %USERPROFILE%\.hae).
- **One writer per file** - per-session JSONL filename `<date>__<sid>.jsonl` enforces single-writer guarantee. Don't introduce shared write paths.
- **Idempotent installers** - `scripts/install_*.ps1` must be safe to re-run. Always backup with timestamp + GUID suffix before touching settings.json or registry files.
- **No git ops without ask** - HAE is gitignored from habits repo; will become its own repo later. Don't `git add` / `git commit` unless explicitly asked.
- **always setup task list to go through** arer approving plans
- **Always delegate simple tasks to codex:rescue**, arround 10% of our tasks (let's try it; we need to save tokens if it possible)
- **Always check results** of delegated work
- **Always read relevant chunks** (`docs/chunks/`) before feature work (Don't forget!)
- **Always update/create chunks** after modify/add features (Don't forget!)
- **No version bump until "let's finish"** - capture changes accumulate in current scope; bump only on explicit close.
- **Read topics/files before plan + do** All docs in `docs/`
- Don't re-ask bash script actions in project folder same session
- **Always give test instructions** w/ accept criteria for QA handoff

## Commands

- **"Let's finish"** → "Version Workflow"
- **"CB"** or **"NB"** → "Git Workflow"
- **"Night work"** → Ask ALL questions/permissions first, plan no interrupt
- **"dev"** → Build debug APK + run `upload_apk_dev.sh` (uploads `development/` self-test, release notes auto-prefix `[DEV]`)
- **"debug"** → Build debug APK + run `upload_apk.sh` (uploads `debug/` testers)
- **Channel separation rule** — NEVER cross-upload:     
  - `development/` channel ONLY visible to dev via **Developer Settings → "Check Dev Update"** (orange banner). Code: `checkForDevUpdate()` filters `channel = "development"`.
  - `debug/` channel auto-checked at startup + About screen update button for testers. Code: `checkForUpdate()` filters `channel = "debug"`.
  - Before `upload_apk.sh` for testers, validate build on dev channel first.
  - Main update dialog shows **DEBUG** badge; dev UI shows **DEV** orange banner — stay visually distinct.
- **"Release plan"** → full release planning cycle (RM agent)
- **"Health check"** → codebase analysis (CA agent)
- **"Research [topic]"** → hypothesis research (RA agent)
- **Agent shortcuts:** SA=system-architect, OB=backend-orchestrator, UI=ui-frontend-specialist, QA=tester, PM=product-manager, RM=release-manager, CA=codebase-analyst, RA=research-analyst


## Version Workflow

1. Update `.claude-plugin/plugin.json` (`version` field) and `config.json` (`version`).
2. Update CLAUDE.md `Current Version` block.
3. Update CHANGELOG.md with new entry. Format: `### Changelog v0.X.Y YYYY-MM-DD`. Style: professional, minimalistic.
4. Update README.md `Status` section (phase + version).
5. If schema changed: bump `schema/record.schema.json` `$id` if breaking; document migration in changelog.
6. If hook command shape changed: re-run `scripts/install_plugin.ps1` (idempotent) and verify `/reload-plugins` reports 0 errors.
7. Update chunks
8. Add checklist or update status in plan/research file if no plan
9. Git command optional here

### Semantic Versioning

- `v0.0.x` - bug fix, doc tweak, redact pattern addition
- `v0.x.0` - new skill, new script, schema additive change, new phase reached
- `v1.0.0` - public release / open-source publish (not yet)

## Git Workflow (don't forget)

### "Current branch (or CB shortly)"
1. Commit all changes w/ message from changelog updates in CLAUDE.md
2. Message format: `vX.Y.Z YYYY-MM-DD\nEmoji1 Update1 name — Update1 description\nEmoji2 Update2 name — Update2 description`
3. Push
4. Ready for new tasks

### "New branch (or NB shortly)"
1–3. All "Current branch" points
4. Create new branch: name starts w/ next iteration number from current branch, then `-` + short word for next feature (e.g. current `7-panel` → next `8-feature`). If no feature name, use generic `feature`, `fixes`, etc.
5. `/clear` to clean conversation history + free context
6. Ready for new tasks

## Release Workflow (don't forget)
1. RM reads codebase health (CA) + existing plans
2. RM updates RICE backlog w/ new ideas from PM/user
3. Unscored hypotheses → RA for research
4. Top RICE items → current/next release scope
5. Empty backlog? → CA generates refactoring scope
6. Scope items assigned to SA/BO/UI/QA for impl
7. User approves scope
8. Save to Notion page via MCP (https://www.notion.so/HAE-35890b0621e180468ca9f400bd087db4 "Учеба/Hae app/Release workflow" in "Planning results section). If Notion not authorized, do together (Don't forget!)
9. Dev begins
8. On "Let's finish" → version workflow as usual

### Release Documentation
| File | Purpose |
|------|---------|
| `docs/release/roadmap.md` | Long-term product roadmap |
| `docs/release/rice_backlog.md` | RICE-scored hypothesis backlog |
| `docs/release/current_scope.md` | Current release scope |
| `docs/release/next_scope.md` | Next release forward scope |
| `docs/release/research_queue.md` | Hypotheses needing research |

### Documentation Chunks (Self-Maintaining)
- Feature docs: `docs/chunks/features/`
- New feature: create/update chunk file
- Chunk format: Quick Reference → Overview → Key Functions → Code Patterns
- Keep chunks under 500 lines, one topic
- Cross-reference related chunks w/ links

## Plugin commands

User invokes skills via `/hae:<name>`. Plugin must be installed (see `INSTALL.md`).

- **`/hae:setup`** - post-marketplace bootstrap: data dir tree, `HAE_DATA_DIR` env, config copy, statusline rewire. Idempotent. Run after `/plugin install hae@hae`; not needed when using `install_plugin.ps1`.
- **`/hae:profile`** - run PAEI + HEXACO Brief + custom decision-style questionnaires, persist to `profile/`, generate `persona.md`.
- **`/hae:status`** - dashboard: capture stats, profile completeness, hook + scheduler state.
- **`/hae:home`** - manage `weighting.homes` list (add / remove / list / auto-detect).
- **`/hae:backfill`** - one-shot import historical sessions from `~/.claude/projects/`.
- **`/hae:consolidate`** - merge per-session raw files into combined dated files.
- **`/hae:classify`** - Phase 3 classifier pass (currently stub).
- **`/hae:twin`** - Phase 4 emulator subagent (requires Phase 2 profile + Phase 3 records).
- **`/hae:statusline`** - install / preview / restore HAE statusline (standalone or composed with OMC HUD).

Install / uninstall:

- `scripts/install_plugin.ps1` - full install: marketplace + Copy mode + bootstrap. Reads version from `.claude-plugin/plugin.json`.
- `scripts/install_plugin.ps1 -Uninstall` - remove (data dir preserved)
- `scripts/setup_data.ps1` - bootstrap-only (data dir + env + statusline). Same as `/hae:setup`.
- `scripts/install_hooks.ps1` - legacy direct-hook only (capture, no skills)
- `scripts/manage_homes.ps1 list|add|remove|auto-detect` - same as `/hae:home`

Marketplace UI install (`/plugin marketplace add Magerash/HAE`) NOT supported - Claude Code can't load a plugin when both `plugin.json` + `marketplace.json` live in same `.claude-plugin/` dir. Repo restructure (plugin -> `plugins/hae/` subdir) needed first; tracked as future work.


## Architecture

### Layers

```
hooks (capture_*.ps1)  ->  prompts/raw/<date>__<sid>.jsonl  ->  classify  ->  prompts/structured/  ->  twin agent
                                                              ->  consolidate (optional)
                                                              ->  manage_homes auto-detect

profile/ (persona.md + paei.json + hexaco.json + custom.json + principles.md)  ->  twin agent
state/ (backfilled_sessions.json)  ->  backfill_history.ps1
```

### Components

- **`.claude-plugin/plugin.json`** - plugin manifest (loaded by Claude Code).
- **`hooks/hooks.json`** - hook bindings using `${CLAUDE_PLUGIN_ROOT}` placeholder.
- **`config.json`** - capture flags, redact patterns, weighting, taxonomy. Read on every hook fire (no restart needed for changes).
- **`schema/record.schema.json`** - JSON Schema for structured records.
- **`scripts/`** - capture, install, backfill, consolidate, manage_homes.
- **`skills/<name>/SKILL.md`** - one per slash command. Frontmatter: `name`, `description`. No `hae:` prefix in name (plugin auto-namespaces).
- **`agents/<name>.md`** - subagent specs. Frontmatter: `name`, `description`, `model`, `tools`.
- **`tests/`** - questionnaire banks (PAEI, HEXACO Brief, custom).
- **`prompts/raw/`** - per-session JSONL files (gitignored).
- **`prompts/structured/`** - Phase 3 classified output.
- **`profile/`** - operator profile data (gitignored).
- **`state/`** - plugin state (backfill tracking, etc).

### Capture pipeline

1. User types prompt -> Claude Code fires `UserPromptSubmit` hook
2. `capture_prompt.ps1` reads stdin (raw bytes, UTF-8), parses JSON
3. Apply redact patterns to prompt text
4. Compute `is_home_project` + `project_weight` against `weighting.homes`
5. Hash paths if `privacy.store_full_paths = false`
6. Append one JSONL line to `prompts/raw/<date>__<sid8>.jsonl`
7. Exit 0

Symmetric for `Stop` hook (`capture_response.ps1`), gated by `capture.include_response` flag, reads transcript tail (50 lines) inline.

### Schema invariants

- All records carry `id` (UUID), `ts` (ISO UTC), `event`, `session_id`, `project`, `is_home_project`, `project_weight`, `source`.
- `cwd` / `transcript_path` are `null` in privacy mode; `cwd_hash` / `transcript_hash` (16-hex) and `cwd_tail` / `transcript_tail` (last N segments) always present.
- `source: "hook"` for live capture, `source: "backfill"` for imported history.

### Weighting

- `weighting.homes` is a list. Each entry is path-prefix (contains `/` or `\`) or basename (no slash).
- Match wins -> `home_weight` (default 1.0); else `project_overrides[<name>]` if set; else `other_weight` (default 0.3).
- Empty list = nothing is home.

## Testing

- Smoke: type any prompt -> file appears in `prompts/raw/<date>__<sid8>.jsonl` within 1s.
- Synthetic: pipe a JSON payload through `capture_prompt.ps1` directly. Use `Write` tool for the test file (Bash heredoc mangles backslashes).
- Plugin load: `/reload-plugins` reports 0 errors. `/doctor` clean. `/plugin list` shows `hae@hae-local` enabled.
- Privacy: search any raw record for the redact patterns - should be `[REDACTED]` placeholders only.
- Idempotency: re-run `install_plugin.ps1` - "junction up to date" + clean re-write of registry, no duplication.

## Privacy + Safety

- Default `privacy.store_full_paths: false` - paths hashed + tailed.
- `prompts/raw/*.jsonl` gitignored.
- `profile/*.json` and `profile/persona.md` and `profile/principles.md` gitignored - personal questionnaire data.
- `state/backfilled_sessions.json` gitignored - contains session UUIDs.
- Redact patterns cover GitHub PATs, OpenAI keys, AWS keys, JWTs, PEM blocks, DB URLs with creds, emails, generic password/token assignments. Extend list before adding capture for new secret families.
- All scripts swallow exceptions to never block Claude Code.

## Phases Roadmap

| Phase | Goal | Status |
|-------|------|--------|
| 0 | Scaffold, plugin manifest, scripts | done v0.1.0 |
| 1 | Live capture (hooks + per-session writes) | done v0.1.0 |
| 2 | Profile (PAEI + HEXACO Brief + custom + principles + persona generation) | done v0.3.0 (PAEI 30Q + HEXACO 24Q + Custom 8Q + 6 principles + persona regen; behavioral calibration validated) |
| 3 | Classifier (raw -> structured with category + scope_signal + override delta) | done v0.2.0 (classify.ps1 + auto-classifier 5 patterns + bulk subagent loop; 1670/1670 classified; 75 overrides) |
| 4 | Twin agent (persona + few-shot retrieval + override exemplars) | done v0.2.0 (twin.ps1 + /hae:twin; validated via V1 month-view A/B test with 18 vs 75 overrides) |
| 5 | Plug into release-manager loop as operator surrogate + standalone repo + global cross-project install + config split + Path A twin invocation | done v0.4.0 |

## Current Version

- **Version:** v0.4.2
- **Phase:** 5 done. Plugin lives in own repo at C:\Projects\HAE; installs to C:\Plugins\hae; data at %USERPROFILE%\.hae. Path A twin (Bash + inline) wired into /release-plan. Config split (defaults + user). All scripts use _lib.ps1 helper. Documentation chunks under docs/chunks/. Release planning docs bootstrapped under docs/release/ (rice_backlog, current_scope, next_scope, research_queue, roadmap). v0.5.0 scope locked w/ twin pre-flight approval.
- **Last Updated:** 2026-05-07

## Quick Reference

| Topic | Location |
|-------|----------|
| Install | `INSTALL.md` |
| User docs | `README.md` |
| Plugin manifest | `.claude-plugin/plugin.json` |
| Capture config | `config.json` |
| Hook bindings | `hooks/hooks.json` |
| Record schema | `schema/record.schema.json` |
| Skills | `skills/<name>/SKILL.md` |
| Capture script | `scripts/capture_prompt.ps1` |
| Response script | `scripts/capture_response.ps1` |
| Plugin installer | `scripts/install_plugin.ps1` |
| Data bootstrap | `scripts/setup_data.ps1` |
| Home manager | `scripts/manage_homes.ps1` |
| Backfill | `scripts/backfill_history.ps1` |
| Consolidator | `scripts/consolidate.ps1` |
| Classifier | `scripts/classify.ps1` |
| Twin context | `scripts/twin.ps1` |
| Behavioral report | `scripts/report.ps1` |
| Status dashboard | `scripts/status.ps1` |
| Statusline | `scripts/statusline.ps1` + `statusline_universal.ps1` |
| Twin agent | `agents/hae-twin.md` |
| Changelog | `CHANGELOG.md` |
