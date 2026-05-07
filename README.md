# HAE — Human Agent Emulator

Plugin that captures operator prompts + decisions across Claude Code sessions, builds a personality + decision-style profile of the operator, and serves a twin agent that emulates the operator for backlog grooming, scope decisions, and release control.

## Status

**v0.5.0 — Phases 0-5 done; phase 5.5 active.** Capture live, classifier shipped, full operator profile, twin agent at medium-high confidence. Plugin in own dev repo with global cross-project install + shared data directory. v0.4.1 adds progressive-disclosure documentation chunks under `docs/chunks/`. v0.4.2 bootstraps release-planning docs under `docs/release/`. v0.5.0 ships wave 1+2 of the planning cycle: twin gates expansion (scope-review + rice-score wired), CLAUDE.md tightening (240->188 lines + chunk-breadcrumb pattern), auto-promote homes (`weighting.auto_promote.enabled` wired through classify post-batch trigger + status display + audit log), report.ps1 formatter mockup awaiting approval, two research files (plugin distribution + forum user-pain) producing 4 v0.6.0 candidates. H1 marketplace install deferred to v0.6.0 (RICE jumped to 28.8 post-research; warrants own cycle).

## Why

Existing AI "twin" products (Personal.ai, Delphi, Replika) imitate *voice*. HAE imitates *judgment* — the deltas between what an agent proposes and what the operator decides. That's the highest-signal training data for a twin.

## Installation

HAE is a global cross-project plugin. One install, captures from every project's CLI session land in a shared data dir.

### Claude Code

```powershell
git clone https://github.com/Magerash/HAE C:\Projects\HAE
powershell -File C:\Projects\HAE\scripts\install_plugin.ps1 -PersistEnv
# restart Claude Code
```

Installer copies plugin to `C:\Plugins\hae`, registers a local marketplace (`hae-local`), bootstraps `%USERPROFILE%\.hae\` data dir, persists `HAE_DATA_DIR` env, and rewires statusline. Idempotent.

If you ever skip the installer (e.g. manual file copy), run `/hae:setup persist` to bootstrap data dir + env + statusline.

See `INSTALL.md` for `-CopyTo`, `-DataDir`, `-Mode Junction` (live dev), and uninstall details.

> **Note:** GitHub-marketplace install (`/plugin marketplace add Magerash/HAE`) requires a repo-layout refactor (plugin -> `plugins/hae/`, marketplace -> `.claude-plugin/marketplace.json`). Tracked as future work; current single-plugin layout cannot host both manifests in `.claude-plugin/` simultaneously.

### Codex CLI

*Coming soon.* HAE will support OpenAI Codex CLI sessions via the same hook contract once Codex CLI exposes equivalent `UserPromptSubmit` / `Stop` hook events. Tracking issue: TBD.

For now, Codex sessions are not captured. Claude Code captures land in `~/.hae/prompts/raw/` and the twin agent draws from those records regardless of which CLI invokes `/hae:twin` later.

## Plugin commands

User invokes via `/hae:<name>` (Claude Code namespaces plugin skills automatically).

| Command | Purpose |
|---------|---------|
| `/hae:setup` | Bootstrap data dir + env + statusline after marketplace install (idempotent). |
| `/hae:status` | Dashboard: capture stats, profile completeness, hook + scheduler state. |
| `/hae:home` | Manage `weighting.homes` list — list / add / remove / auto-detect top-volume projects. |
| `/hae:profile` | Run PAEI 30Q + HEXACO Brief 24Q + custom 8Q + free-form principles; generate `persona.md`. |
| `/hae:backfill` | One-shot import of historical Claude Code session transcripts from `~/.claude/projects/`. |
| `/hae:consolidate` | Merge per-session raw files into combined dated files. |
| `/hae:classify` | Phase 3 classifier pass — raw → structured (8-cat taxonomy + override deltas). |
| `/hae:twin` | Phase 4 emulator subagent. Requires Phase 2 profile + Phase 3 records. |
| `/hae:statusline` | Install / preview / restore HAE statusline (standalone or composed). |

Run `/plugin list` after install — `hae@hae-local` (or `hae@hae`) should appear enabled.

## Layout

**Plugin source (this repo, e.g. `C:\Projects\HAE\`):**

```
HAE/
├── .claude-plugin/
│   └── plugin.json               # plugin manifest (single-plugin layout; no marketplace.json yet)
├── README.md
├── INSTALL.md                    # install guide (Copy mode default, Junction for dev)
├── CHANGELOG.md
├── CLAUDE.md                     # AI instructions for working in this repo
├── config.default.json           # universal defaults (committed): capture, redact, classifier, twin gates
├── config.user.example.json      # template for operator-private user config
├── .gitignore
├── hooks/hooks.json              # hook bindings using ${CLAUDE_PLUGIN_ROOT}
├── scripts/
│   ├── _lib.ps1                  # shared helper (Resolve-HaeDataRoot, Get-HaeConfig, etc)
│   ├── capture_prompt.ps1        # UserPromptSubmit hook
│   ├── capture_response.ps1      # Stop hook
│   ├── classify.ps1              # Phase 3 classifier
│   ├── twin.ps1                  # Phase 4 twin context composer
│   ├── consolidate.ps1
│   ├── backfill_history.ps1
│   ├── manage_homes.ps1          # writes to user config in data dir
│   ├── status.ps1
│   ├── statusline.ps1
│   ├── statusline_universal.ps1
│   ├── install_statusline.ps1
│   ├── report.ps1
│   ├── install_plugin.ps1        # full install: marketplace + Copy + bootstrap
│   ├── setup_data.ps1            # post-marketplace bootstrap (data dir + env + statusline)
│   └── install_hooks.ps1         # legacy direct-hook installer
├── schema/record.schema.json
├── tests/                        # questionnaire banks (committed)
├── agents/hae-twin.md            # subagent spec
└── skills/                       # /hae:* slash commands
```

**Operator data dir (default `%USERPROFILE%\.hae\`, override via `$env:HAE_DATA_DIR`):**

```
%USERPROFILE%\.hae\
├── config.json                   # operator-private overrides (homes, project_overrides, statusline.previous_command)
├── prompts/raw/                  # JSONL captures from ALL projects (gitignored from any repo)
├── prompts/structured/           # classifier output
├── profile/                      # PAEI + HEXACO + custom + persona.md
├── state/                        # backfill tracking, classifier state
└── docs/internal-sessions/       # optional: hand-written session logs (operator's own memory)
```

## Phases

| Phase | Goal | Status |
|-------|------|--------|
| 0 | Scaffold + plugin manifest + script skeletons | ✅ done v0.1.0 |
| 1 | `UserPromptSubmit`+`Stop` capture, per-session JSONL writes, redaction + path hashing, `/hae:home` weighting, `/hae:backfill` for historical sessions, `/hae:consolidate` daily merge | ✅ done v0.1.0 |
| 2 | Profile: PAEI 30Q + HEXACO Brief 24Q + Custom 8Q + free-form principles + auto-generated `persona.md`. Captured via AskUserQuestion 4-bucket Likert flow + parallel batching. Behavioral calibration validated against captured records | ✅ done v0.3.0 |
| 3 | Classifier: raw → structured 8-cat taxonomy + scope_signal + evidence_demand + risk_appetite + override delta detection. Auto-classifier handles 5 system patterns inline (40-55% LLM-cycle savings). `/hae:classify` single-batch + `/hae:classify-bulk` subagent loop. 1670 records classified, 75 override exemplars captured | ✅ done v0.2.0 |
| 4 | `hae-twin`: `scripts/twin.ps1` context composer loads persona + principles + override exemplars (baseline-boosted) + topical exemplars (keyword × project_weight ranked). `/hae:twin` answers in Twin-take / Why / Risk / Confidence format. Validated A/B with same V1-month-view question and 18 vs 75 override pools | ✅ done v0.2.0 |
| 5 | Plug `hae-twin` into release-manager loop as operator surrogate (RICE votes, scope picks, codex-review gates) + split plugin into own repo + global cross-project install + config split | 🔄 in progress v0.4.0 |

## Scope progression

**Global cross-project install (v0.4.0+).** Plugin lives once at install path (default `C:\Plugins\hae`). Captures from every project's Claude Code session funnel into a single shared data directory. Records carry `project` + `is_home_project` + `project_weight` fields so the classifier and twin can weight home work over drive-by sessions.

## Capture mechanics

**Per-session direct write** — no spool, no scheduler, no daemon. Each Claude Code session has its own dated file: `prompts/raw/<UTC-date>__<sid8>.jsonl`. Within a session, hooks fire sequentially (Claude Code processes one prompt at a time), so each file has a single writer. Across sessions, different filenames mean zero contention. No mutex, no append race.

1. `UserPromptSubmit` hook → reads stdin (raw bytes, UTF-8), redacts secrets, hashes paths, appends one record line to `prompts/raw/<date>__<sid>.jsonl`. Sub-50ms.
2. `Stop` hook → reads `transcript_path` tail (last 50 lines), extracts last assistant message, redacts, appends paired record to the same per-session file. Sub-50ms (bounded read, bounded write).
3. **Consolidation** (optional, lazy) → `scripts/consolidate.ps1` merges per-session files into combined `prompts/raw/<date>.jsonl` for downstream consumers that prefer one file per day. Run on demand by `/hae:consolidate`, `/hae:status`, or `/hae:classify`. Per-session files kept by default (use `-Cleanup` to delete after merge).

Hooks installed at `~/.claude/settings.json` so capture works from **any cwd / any project**. All records land in this plugin's `prompts/raw/` regardless of which project triggered them — single sink, easy to query.

## Backfill (optional)

`scripts/backfill_history.ps1` — one-shot import of historical Claude Code session transcripts from `~/.claude/projects/`. Same redaction / weighting / PII pipeline as live capture. Idempotent — tracks processed sessions in `state/backfilled_sessions.json`. Records carry `source: "backfill"` (vs live `source: "hook"`). Filename prefix `bf-` distinguishes them: `prompts/raw/<date>__bf-<sid8>.jsonl`.

User opts in by running `/hae:backfill` — never auto-runs. Some users will skip this and only collect forward.

## Project weighting

Not every prompt is equal training data. Twin retrieval prioritizes high-signal records when emulating operator decisions. Three tiers, decided at capture time from two signals: `homes` membership (curated) and capture `source` (live vs imported).

### Tiers

| Tier | Weight | When | Meaning |
|------|--------|------|---------|
| `home` | **1.0** | cwd matches `weighting.homes` entry | Curated primary project. Defines operator identity. Slow-change. |
| `active` | **0.7** | live capture (`source=hook`), not in homes | Currently being worked on. Recent signal. The project you're typing in right now. |
| `other` | **0.3** | imported history (`source=backfill`), not in homes | Older drive-by sessions. Useful but diluted persona signal. |

Decision logic at capture (capture_prompt.ps1, capture_response.ps1, backfill_history.ps1):

```
if cwd matches homes:        tier=home,    weight=home_weight
elif source == 'hook':       tier=active,  weight=active_weight
else (source == 'backfill'): tier=other,   weight=other_weight
```

Each record carries: `project`, `is_home_project`, `project_weight`, `tier`, `source`.

### Why three tiers, not two?

`home` is a manual stamp — "this project IS the operator surface." Curated, stable, opt-in. Auto-detection is volume-based, and volume ≠ value: a 3-week research detour produces high volume but low persona signal. Home is the anchor; active is the wind.

The active/other split is automatic via `source`. Live captures are recent by definition (you're typing now), so they get the active tier without any list to maintain. Backfilled records are historical imports — older focus, lower weight unless homed.

### Homes list — the only thing you manage

`weighting.homes` lives in your user config (`<dataRoot>/config.json`). Each entry is either:

- **Path prefix** — e.g. `C:\Projects\my-app` — matches any cwd starting with this prefix
- **Bare basename** — e.g. `my-app` — matches any cwd whose basename equals this

Empty `homes` = nothing is home. Live captures still get active (0.7), backfill stays other (0.3). Default ships empty.

```
/hae:home list                  # see current homes
/hae:home add C:\Projects\X     # manually add
/hae:home add my-app            # add by bare name
/hae:home remove my-app         # remove
/hae:home auto-detect           # preview top-volume projects from captured records
/hae:home auto-detect -Apply    # write to config
```

Capture scripts re-read config on every hook fire — no Claude Code restart needed when homes change.

### Examples

| cwd | source | homes match? | tier | weight |
|-----|--------|--------------|------|--------|
| `C:\Projects\My habits` (live) | hook | yes | home | 1.0 |
| `C:\Projects\HAE` (live, not in homes) | hook | no | active | 0.7 |
| `C:\Projects\HAE` (backfilled) | backfill | no | other | 0.3 |
| `C:\Projects\My habits` (backfilled) | backfill | yes | home | 1.0 |
| Random one-off cwd (live) | hook | no | active | 0.7 |

Note: weight is **frozen at capture time**. If you later add a project to homes, existing records keep their original tier. Re-tagging old records is a separate opt-in operation (not yet implemented).

### Used by

- **Phase 3 classifier** — can skip records below a weight threshold to keep structured set lean
- **Phase 4 twin few-shot** — retriever multiplies similarity score by `project_weight` so home + active exemplars outrank backfilled drive-bys
- **Phase 2 persona regen** — weighted aggregation prevents off-topic projects from skewing inferred decision style

### Recency / time-decay

Tier reflects "is this project relevant right now," not "how old is the record." Age-based decay (e.g. records from 6 months ago weighted lower than today's) is a Phase 4 retrieval-time concern, not a capture-time concern. Capture stores `ts` per record; the twin can apply time-decay multipliers when ranking exemplars without changing stored weights.

### Escape hatch

`weighting.project_overrides` (object) — set explicit per-project weights when a project doesn't fit the home/active/other model. Example: a research project that should always be 0.5 regardless of source. Use sparingly.

## Personality stack

- **PAEI** (Adizes 4 roles) — coarse managerial archetype
- **HEXACO-60** (free, public-domain, validated) — 6 personality factors
- **8 custom items** — risk tolerance, scope-bias, evidence threshold, abstraction tolerance, refactor-vs-ship, review strictness, research depth, parallelism comfort

Skipped: MBTI/DISC (low validity, license friction).

## Prompt taxonomy (8 categories)

`FEATURE` · `BUG` · `RESEARCH` · `RELEASE_OPS` · `CODE_QA` · `REFACTOR` · `META` · `PLANNING`

Schema for structured records: see `schema/record.schema.json`.

## Privacy

- Raw prompts may contain unredacted PII despite the redact pass — `prompts/raw/` is **gitignored**
- Profile JSON files (`profile/*.json`, `profile/persona.md`) are gitignored
- Backups from `install_hooks.ps1` are gitignored
- `prompts/structured/` is committable (categorized only, not raw text — depending on Phase 3 implementation)

## Next

See `INSTALL.md` for activation steps. See `CHANGELOG.md` (Phase 1+) for capture-enable history.
