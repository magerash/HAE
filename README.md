# `.hae` — Human Agent Emulator

Plugin that captures operator prompts + decisions across Claude Code sessions, builds a personality + decision-style profile of the operator, and serves a twin agent that emulates the operator for backlog grooming, scope decisions, and release control.

## Status

**v0.3.0 — Phases 0-4 done.** Capture live, classifier shipped (1670 records / 75 overrides), full operator profile captured (PAEI 30Q + HEXACO Brief 24Q + Custom 8Q + 6 principles + persona.md), twin agent answering at medium-high confidence. Only Phase 5 (release-manager loop integration) remains.

## Why

Existing AI "twin" products (Personal.ai, Delphi, Replika) imitate *voice*. HAE imitates *judgment* — the deltas between what an agent proposes and what the operator decides. That's the highest-signal training data for a twin.

## Layout

```
.hae/
├── .claude-plugin/plugin.json    # plugin manifest
├── README.md                     # this file
├── INSTALL.md                    # one-time setup guide
├── config.json                   # capture flags, redact rules, taxonomy
├── .gitignore                    # protects raw prompts + profile from commits
├── hooks/hooks.json              # template hook bindings (not auto-loaded)
├── scripts/
│   ├── capture_prompt.ps1        # UserPromptSubmit hook
│   ├── capture_response.ps1      # Stop hook
│   ├── classify.ps1              # Phase 3 classifier (state/next-batch/append)
│   ├── twin.ps1                  # Phase 4 twin context composer
│   ├── consolidate.ps1           # daily merge of per-session files
│   ├── backfill_history.ps1      # one-shot historical import
│   ├── manage_homes.ps1          # weighting.homes editor
│   ├── status.ps1                # /hae:status dashboard
│   ├── statusline.ps1            # multi-row statusline segment
│   ├── statusline_universal.ps1  # composes with OMC/gstack/any prior statusLine
│   ├── install_statusline.ps1    # statusline installer/uninstaller
│   ├── report.ps1                # operator behavioral report generator
│   ├── install_plugin.ps1        # one-command plugin install via local marketplace
│   └── install_hooks.ps1         # legacy direct-hook installer (capture only, no skills)
├── schema/record.schema.json     # JSON Schema for structured records
├── prompts/
│   ├── raw/                      # JSONL append-log per UTC-day (gitignored)
│   └── structured/               # categorized, scored records (committable)
├── profile/                      # PAEI + HEXACO + custom test results (gitignored)
├── tests/                        # questionnaire banks (committed)
├── agents/                       # hae-twin subagent spec
├── skills/                       # /hae:* slash commands
└── seeds/sessions/               # hand-written session prompt logs (bootstrap data)
```

## Phases

| Phase | Goal | Status |
|-------|------|--------|
| 0 | Scaffold + plugin manifest + script skeletons | ✅ done v0.1.0 |
| 1 | `UserPromptSubmit`+`Stop` capture, per-session JSONL writes, redaction + path hashing, `/hae:home` weighting, `/hae:backfill` for historical sessions, `/hae:consolidate` daily merge | ✅ done v0.1.0 |
| 2 | Profile: PAEI 30Q + HEXACO Brief 24Q + Custom 8Q + free-form principles + auto-generated `persona.md`. Captured via AskUserQuestion 4-bucket Likert flow + parallel batching. Behavioral calibration validated against captured records | ✅ done v0.3.0 |
| 3 | Classifier: raw → structured 8-cat taxonomy + scope_signal + evidence_demand + risk_appetite + override delta detection. Auto-classifier handles 5 system patterns inline (40-55% LLM-cycle savings). `/hae:classify` single-batch + `/hae:classify-bulk` subagent loop. 1670 records classified, 75 override exemplars captured | ✅ done v0.2.0 |
| 4 | `hae-twin`: `scripts/twin.ps1` context composer loads persona + principles + override exemplars (baseline-boosted) + topical exemplars (keyword × project_weight ranked). `/hae:twin` answers in Twin-take / Why / Risk / Confidence format. Validated A/B with same V1-month-view question and 18 vs 75 override pools | ✅ done v0.2.0 |
| 5 | Plug `hae-twin` into release-manager loop as operator surrogate (RICE votes, scope picks, codex-review gates) | ⏳ pending |

## Scope progression

**Per-project first** — install `.hae/` inside any active project directory. Once stable, promote scripts/skills/agents to `~/.claude/plugins/hae/` for global use.

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

Not every prompt is equal training data. Active-dev focus produces dense, multi-turn, high-judgment traffic. Drive-by prompts in scratch projects, doc browsing, or one-off scripts produce diluted signal. Mixing 1:1 in twin training dilutes the persona toward generic helpfulness.

Each captured record carries:

- `project` — basename of cwd
- `is_home_project` — true when cwd matches an entry in `config.weighting.homes`
- `project_weight` — `home_weight` (1.0) for matched homes, `other_weight` (0.3) for everything else, or a `project_overrides[<name>]` value

`weighting.homes` is a list. Each entry is either:
- **Path prefix** (e.g. `C:\Projects\<your-project>`) — matches any cwd starting with this prefix
- **Bare basename** (e.g. `<your-project>`) — matches any cwd whose basename equals this

Empty `homes` = no project is home, everything gets `other_weight`. Default ships empty.

**Bootstrap your homes list:**

```
/hae:home auto-detect           # preview top-volume projects from captured records
/hae:home auto-detect -Apply    # actually write to config
/hae:home add "C:\Projects\X"   # manually add
/hae:home list                  # see current homes
```

Capture scripts re-read config on every hook fire — no Claude Code restart needed when homes change.

Used by:
- **Phase 3 classifier** — can skip records below a weight threshold to keep structured set lean
- **Phase 4 twin few-shot** — retriever multiplies similarity score by `project_weight` so home-project exemplars dominate
- **Phase 2 persona regen** — weighted aggregation prevents off-topic projects from skewing inferred decision style

## Seed data

`seeds/sessions/` holds hand-written session-prompt logs with timecodes + outcomes. Predates auto-capture. Phase 3 classifier ingests these as bootstrap training data so the twin has signal from day 1, not day 30.

Currently 2 sessions:
- `session-2026-05-04_v0.92_to_v0.93.1.md` (24 prompts, v0.92→v0.93.1 ship)
- `session-2026-05-04_v0.92_training_launcher.md` (9 prompts, V2 training launcher)

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
