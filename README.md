# HAE - Human Agent Emulator

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Plugin: Claude Code](https://img.shields.io/badge/plugin-Claude%20Code-orange.svg)](https://github.com/anthropics/claude-code)
[![Phase: 5.5](https://img.shields.io/badge/phase-5.5%20active-blue.svg)](#status)
[![Version: v0.6.3](https://img.shields.io/badge/version-v0.6.3-informational.svg)](docs/CHANGELOG.md)

> Captures your decisions, builds your judgment profile, serves a twin agent that thinks like you.

HAE is a Claude Code plugin. It captures the deltas between what an agent proposes and what you actually decide, builds a personality + decision-style profile from your real history, and serves a twin agent that emulates your judgment for backlog grooming, scope decisions, and release control.

Existing AI "twin" products (Personal.ai, Delphi, Replika) imitate *voice*. HAE imitates *judgment*. Existing agent observability tools (Langfuse, claude-code-otel, Anthropic /insights) log activity. HAE captures the operator's overrides on top of that activity. The override exemplars become high-signal few-shot training data no other tool collects.

---

## Quick start

```
/plugin marketplace add Magerash/HAE
/plugin install hae@hae
/hae:setup
```

Three slash commands inside Claude Code. Capture starts on your next prompt.

To see what was captured:

```
/hae:status
```

---

## What HAE does

- **Captures every prompt + response** via Claude Code hooks. Sub-50ms async (no user-visible block since v0.6.2).
- **Redacts secrets + PII** before write. 25 regexes cover GitHub PATs, OpenAI keys, AWS, JWTs, PEM, DB URLs with creds, emails, generic password/token assignments.
- **Builds operator profile** through PAEI (Adizes 4 roles) + HEXACO Brief (6 factors) + 8 custom decision-style items + free-form principles. Persona auto-generated from all four.
- **Classifies prompts** into 8-category taxonomy with scope_signal, evidence_demand, risk_appetite, urgency, override-axis detection.
- **Twin agent** loads persona + principles + override exemplars + topical exemplars. Emulates your judgment in standard format (Twin take / Why / Risk / Confidence / sign-off).
- **Override-rate drift signal** in `/hae:status`: trailing 4-week sparkline as a personal Anthropic-change detector. Spots silent model changes the way Anthropic billing dashboards cannot.
- **Cost tracker** (`/hae:cost`): weekly token spend per project, Opus/Sonnet/Haiku 2026 pricing, schema-additive non-breaking. No org-admin API key needed.
- **Auto-promote home projects** by capture volume. The list of "what matters" updates itself.
- **Cross-project install:** one plugin instance, every project's Claude Code session lands in a shared data dir.

## Why HAE

Five forum-confirmed pain points (see `docs/research/forum_userpain_2026-05-07.md`) HAE was designed against:

| Pain | What HAE does |
|------|---------------|
| Context loss between sessions | Captures every prompt + response in JSONL; twin agent retrieves past decisions on demand |
| Cost opacity (no per-project breakdown) | `/hae:cost` aggregates token spend by week + project + model tier |
| Undocumented model changes break workflows | Override-rate drift sparkline in `/hae:status` surfaces unilateral Anthropic changes via your own behavior delta |
| Prompt repetition fatigue | Classifier identifies prompts you keep typing (planned v0.7.0) |
| Vendor lock-in anxiety | Local JSONL only. No cloud. Open schema. MIT licensed. Data portability tool planned (v0.7.0) |

---

## Install

### Windows (supported)

**Option A: Marketplace UI (recommended, v0.6.0+)**

```
/plugin marketplace add Magerash/HAE
/plugin install hae@hae
/hae:setup
```

Three slash commands inside Claude Code. Claude Code clones the repo, registers the marketplace, installs the plugin from `plugins/hae/`, then `/hae:setup` bootstraps `%USERPROFILE%\.hae\` data dir + `HAE_DATA_DIR` env + statusline.

**Option B: Local install script (suits dev / live-edit)**

```powershell
git clone https://github.com/Magerash/HAE C:\Projects\HAE
powershell -File C:\Projects\HAE\plugins\hae\scripts\install_plugin.ps1 -PersistEnv
# restart Claude Code
```

Robocopies plugin to `C:\Plugins\hae` (override with `-CopyTo`), bootstraps data dir, persists `HAE_DATA_DIR` user-scope, rewires statusline, registers local marketplace `hae-local`. Idempotent. Use `-Mode Junction` for live dev (edits propagate without re-copy).

See `INSTALL.md` for `-CopyTo`, `-DataDir`, `-Mode Junction`, and uninstall details.

### macOS (planned, v0.8.0+)

```
# planned - tracked as H16 cross-platform install
# blocked: capture scripts are PowerShell-only today
# follow: https://github.com/Magerash/HAE/issues  (label: cross-platform)
```

Marketplace UI install (`/plugin marketplace add Magerash/HAE`) clones the repo successfully on macOS, but capture hooks fail because they invoke `powershell.exe`. Cross-platform port (bash hooks or Go binary) tracked as backlog item H16. Watch the issues tag for progress, or open one with your use case to bump priority.

### Linux (planned, v0.8.0+)

Same status as macOS. Tracked under the same H16 cross-platform port. Bash + zsh shells targeted; PowerShell Core (pwsh) on Linux is a possible bridge if community signal supports it.

### Codex CLI (planned)

Tracked as H15 Codex CLI integration. Blocked on Codex CLI exposing equivalent `UserPromptSubmit` / `Stop` hook events. Once landed, captures from any Codex session will join the same shared data dir, and the twin agent reads regardless of which CLI invoked it.

### Uninstall

```powershell
# Windows
powershell -File C:\Projects\HAE\plugins\hae\scripts\install_plugin.ps1 -Uninstall
```

Removes plugin junction + registry entries. Operator data dir at `%USERPROFILE%\.hae\` is preserved (your captures are never auto-deleted).

---

## Usage

Capture is automatic post-install. Slash commands surface what was captured.

| Command | Purpose |
|---------|---------|
| `/hae:status` | Dashboard: capture stats, profile state, override-rate drift sparkline, auto-promote candidates, backfill state |
| `/hae:cost [-Weeks N]` | Token spend per week + project + model tier (Opus/Sonnet/Haiku pricing) |
| `/hae:home` | Manage home-project list (`list` / `add` / `remove` / `auto-detect`) |
| `/hae:profile` | Run questionnaires (PAEI 30Q + HEXACO 24Q + Custom 8Q + principles); generates `persona.md` |
| `/hae:twin <question>` | Invoke twin to emulate your judgment on a question |
| `/hae:backfill` | One-shot import of historical Claude Code sessions from `~/.claude/projects/` |
| `/hae:classify` | Single-batch classifier pass (raw -> structured) |
| `/hae:classify-bulk` | Spawn subagent that loops batches in fresh context |
| `/hae:consolidate` | Merge per-session JSONL into combined daily files |
| `/hae:setup` | Bootstrap data dir + env + statusline (post-install or post-Claude-Code-update) |
| `/hae:statusline` | Install / preview / restore HAE statusline (standalone or composed with another HUD) |

Sample `/hae:status` output:

```
## HAE status - phase 5 - capture: ON

### Plugin
- enabled: True (hae@hae-local)
- response capture: off
- privacy.store_full_paths: False

### Homes
- C:\Projects\My habits  [path]
- HAE  [name]
- weights: home=1.0  active=0.7  other=0.3

### Raw captures
- Date range:     2026-04-08 09:00 -> 2026-05-10 03:11 UTC
- Total:          1869 records
- Top projects:   habits=1241, Findar=253, buy=93, ...

### Override-rate drift (4-week trailing vs prior 4-week baseline)
- Overall:    --.=*#  recent 71 vs prior 18, delta 53 +294%  [ALERT]
- By axis:
    evidence        . #*-  recent 25 vs prior 1 (delta 24 +2400%)
    approach       =#.#**  recent 32 vs prior 15 (delta 17 +113%)
    scope          .   -*  recent 8 vs prior 1 (delta 7 +700%)
    priority        -- *#  recent 6 vs prior 1 (delta 5 +500%)
  legend: sparkline grades=' . - = # *' (5 levels by max in series); recent on right

### Profile
| File           | Exists | Modified         |
| paei.json      | yes    | 2026-05-05 20:31 |
| hexaco.json    | yes    | 2026-05-05 20:31 |
| ...
```

The +2400% spike on the evidence axis above is real operator data. Either Anthropic changed serving parameters or the operator started demanding more rigorous verification. Either way, HAE surfaces it before you can articulate why something feels off.

---

## How it works

```
[Claude Code session]
       |
       | UserPromptSubmit hook (async, sub-50ms)
       v
capture_prompt.ps1  ->  redact secrets  ->  hash paths  ->  weight by home/active/other
       |
       v
prompts/raw/<date>__<sid>.jsonl    (per-session, single writer, no contention)
       |
       | Stop hook (async)
       v
capture_response.ps1  ->  parse transcript tail  ->  extract tokens + model  ->  redact response
       |
       v
[same per-session file, paired record]
       |
       | /hae:classify (manual or batch)
       v
prompts/structured/<yyyy-MM>.jsonl  +  overrides.jsonl  (high-signal subset)
       |
       v
twin.ps1  ->  load persona + principles + override exemplars + topical exemplars  ->  markdown context
       |
       v
hae-twin agent  ->  Twin take / Why / Risk / Confidence / sign-off
```

Per-session direct writes mean no spool, no scheduler, no daemon. Each session has its own filename so cross-session contention is zero.

For the full architecture deep-dive, see `docs/chunks/architecture/`.

---

## Configuration

Two-file split:

- **`plugins/hae/config.default.json`** - universal defaults shipped with plugin (capture flags, redact patterns, classifier categories, twin gates, pricing).
- **`<dataRoot>/config.json`** - operator-private overrides (homes, project overrides, statusline previous command, gate toggles).

Operator config is bootstrapped from `config.user.example.json` on first install. Edit freely; no restart needed (capture re-reads config on every fire).

Common knobs:

```json
{
  "capture": {
    "enabled": true,
    "include_response": false,
    "include_tokens": true
  },
  "privacy": {
    "store_full_paths": false,
    "path_segments_kept": 2
  },
  "weighting": {
    "homes": ["C:\\Projects\\my-app"],
    "auto_promote": { "enabled": false, "top_n": 3, "min_records": 100 }
  },
  "twin": {
    "gates": { "before_user_approval": true }
  }
}
```

Full reference + every field documented inline in `plugins/hae/config.default.json`.

---

## Data location

Default: `%USERPROFILE%\.hae\` on Windows. Override with `$env:HAE_DATA_DIR`.

```
<dataRoot>\
  config.json                operator-private overrides
  prompts\raw\               JSONL captures from ALL projects
  prompts\structured\        classifier output
  profile\                   PAEI + HEXACO + custom + persona.md
  state\                     backfill + classifier + auto_promote audit log
```

Data dir is **never** auto-deleted by uninstall. Your captures survive plugin reinstalls, Claude Code updates, and disk migrations as long as the env var or default path resolves.

---

## Privacy

- Raw prompts gitignored (may contain unredacted PII despite the redact pass).
- Profile JSON + `persona.md` + `principles.md` gitignored.
- Backup files (`*.hae-backup-*.json`) gitignored.
- 25 redact regexes applied before write. Extend `config.capture.redact_patterns` for new secret families.
- Path PII control via `privacy.store_full_paths` (default false): paths SHA-256-hashed + last 2 segments kept.
- All capture scripts wrap in try/catch + exit 0 on every error path - hot path can never block Claude Code.
- No cloud. No telemetry. Local JSONL only. MIT licensed. Operator owns the data.

---

## Status

**Done (v0.1.0 -> v0.6.2):**

- Phase 0-1: scaffold + plugin manifest + live capture (UserPromptSubmit + Stop hooks, async since v0.6.2, redaction, path hashing, per-session writes).
- Phase 2: profile - PAEI 30Q + HEXACO Brief 24Q + Custom 8Q + 6 principles + persona generation. Behavioral calibration validated against captured records.
- Phase 3: classifier - raw -> structured 8-cat taxonomy (FEATURE / BUG / RESEARCH / RELEASE_OPS / CODE_QA / REFACTOR / META / PLANNING) + scope_signal + evidence_demand + risk_appetite + override-axis detection. Auto-classifier handles 5 system patterns inline (40-55% LLM cycle savings).
- Phase 4: twin agent - persona + principles + override exemplars + topical exemplars; few-shot retrieval; standard answer format.
- Phase 5: release-manager loop integration + standalone repo + global cross-project install + config split + Path A twin invocation.
- Phase 5.5 (v0.5.0): twin gates expansion (`on_scope_cut` + `on_mid_release_scope_add` + `on_backlog_add`); CLAUDE.md tightening + chunk-breadcrumb pattern; auto-promote homes wired (`weighting.auto_promote.enabled`).
- Phase 5.5 (v0.6.0): marketplace UI install (`/plugin marketplace add Magerash/HAE` works); override-rate drift signal in `/hae:status`; cost skill (`/hae:cost`) with schema-additive token fields + Opus/Sonnet/Haiku 2026 pricing.
- v0.6.1: MIT LICENSE.
- v0.6.2: capture hooks async (zero user-visible block).

**Active (v0.7.0):**

- `/hae:export` skill (CSV + markdown summary by project; data-portability + anti-lock-in messaging).
- v1.0 OSS publish completion (CONTRIBUTING.md, marketplace listing submission, README polish for external audience).
- `report.ps1` formatter rewrite (TOC + section anchors + takeaway blockquotes + trend tracking + blind-spot interpretation).
- Repetition-candidate classifier (prompts typed 10+ times surface as CLAUDE.md/hook promotion candidates).

**Planned (v0.8.0+):**

- Phase 6: cross-project intelligence - twin few-shot retrieval upgrade to semantic embeddings (`fastembed` / all-MiniLM-L6-v2 ONNX, local, ~5ms query); exemplar staleness detection.
- PostToolUse hook capture + `/hae:trace <session-id>` for session audit trail.
- Cross-platform install (macOS + Linux). Bash hooks or Go binary candidate.
- Codex CLI integration (depends on Codex hook contract).
- Phase 6 dashboards: entity rollups, drift detection, project velocity.

**RICE backlog + roadmap:** `docs/release/rice_backlog.md`, `docs/release/roadmap.md`, `docs/release/current_scope.md`.

---

## Documentation

- `INSTALL.md` - install paths in detail (UI, local script, legacy hooks-only)
- `docs/CHANGELOG.md` - per-version shipped changes
- `docs/chunks/` - progressive-disclosure documentation (features / architecture / patterns)
- `docs/release/` - RICE backlog, current + next scope, roadmap, research queue
- `plugins/hae/.claude-plugin/plugin.json` - plugin manifest (declares hooks/commands/agents/skills paths)
- `plugins/hae/schema/record.schema.json` - JSONL record schema (additive evolution since v0.1.0)

---

## Contributing

External contributions welcome (planned formal CONTRIBUTING.md in v0.7.0 H12). For now:

- Issues + feature requests: GitHub Issues.
- Cross-platform port (H16) is the highest-impact contribution opportunity if you have macOS or Linux + Claude Code.
- Forum-pain-driven hypotheses (Theme A-E from `docs/research/forum_userpain_2026-05-07.md`) explicitly invite community proposals.

The repo is RICE-scored. New ideas get RICE-evaluated via `/rice-score` slash command before scoping.

---

## License

[MIT](LICENSE). Copyright (c) 2026 Magerash. See `LICENSE` for full text.
