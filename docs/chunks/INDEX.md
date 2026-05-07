# HAE Codebase Index

Machine-friendly navigation. File -> purpose -> chunk.

## Repo layout

```
C:\Projects\HAE\
  .claude-plugin\plugin.json    plugin manifest
  hooks\hooks.json              hook bindings (capture_*.ps1)
  schema\record.schema.json     JSON Schema for raw + structured records
  config.default.json           defaults (shipped, gitignored downstream)
  config.user.example.json      user overrides template
  scripts\                      PowerShell business logic
  skills\<name>\SKILL.md        slash-command skills (one per /hae:<name>)
  agents\hae-twin.md            twin subagent spec
  tests\                        questionnaire banks (PAEI, HEXACO, custom)
  docs\
    CHANGELOG.md
    chunks\                     this folder
    research\                   research notes / plans
    hidden\                     work-in-progress notes (gitignored)
```

Data lives outside repo at `%USERPROFILE%\.hae\` (or `$env:HAE_DATA_DIR`):

```
<dataRoot>\
  prompts\raw\<date>__<sid>.jsonl       per-session capture
  prompts\structured\<yyyy-MM>.jsonl    monthly classified output
  prompts\structured\overrides.jsonl    high-signal exemplars
  profile\persona.md + *.json + principles.md
  state\classified_ids.json             classifier checkpoint
  state\backfilled_sessions.json        backfill checkpoint
```

## Scripts

| File | Purpose | Chunk |
|------|---------|-------|
| `scripts/_lib.ps1` | shared helpers: `Get-HaeConfig`, `Resolve-HaeDataRoot`, `Get-Hae*Dir` | `patterns/data-root-resolution.md` |
| `scripts/capture_prompt.ps1` | UserPromptSubmit hook, write raw JSONL | `features/capture.md`, `patterns/hot-path.md` |
| `scripts/capture_response.ps1` | Stop hook, capture transcript tail | `features/capture.md` |
| `scripts/install_plugin.ps1` | register / uninstall plugin (Copy or Junction); reads version from plugin.json | `features/install.md`, `patterns/idempotent-installer.md` |
| `scripts/setup_data.ps1` | post-marketplace bootstrap: data dir + env + statusline | `features/install.md` |
| `scripts/install_hooks.ps1` | legacy direct-hook install (no skills) | `features/install.md` |
| `scripts/install_statusline.ps1` | install / preview / restore statusline | `features/statusline.md` |
| `scripts/manage_homes.ps1` | list/add/remove/auto-detect home projects | `features/weighting.md` |
| `scripts/backfill_history.ps1` | one-shot import from `~/.claude/projects/` | `features/backfill.md` |
| `scripts/consolidate.ps1` | merge per-session JSONL into combined daily files | `features/consolidate.md` |
| `scripts/classify.ps1` | classify state / next-batch / append | `features/classify.md`, `architecture/classify-pipeline.md` |
| `scripts/classify_nightly.ps1` | scheduled bulk classify | `features/classify.md` |
| `scripts/twin.ps1` | compose twin context (persona + exemplars) | `features/twin.md`, `architecture/twin-pipeline.md` |
| `scripts/report.ps1` | behavioral report from structured records | `features/profile.md` |
| `scripts/status.ps1` | dashboard for /hae:status | `features/profile.md` |
| `scripts/statusline.ps1` | HAE-only statusline | `features/statusline.md` |
| `scripts/statusline_universal.ps1` | composed OMC + HAE statusline | `features/statusline.md` |

## Skills

| Skill | Slash | Description | Chunk |
|-------|-------|-------------|-------|
| `skills/setup/SKILL.md` | `/hae:setup` | post-marketplace bootstrap (data dir + env + statusline) | `features/install.md` |
| `skills/profile/SKILL.md` | `/hae:profile` | run questionnaires, persist to `profile/`, regen `persona.md` | `features/profile.md` |
| `skills/status/SKILL.md` | `/hae:status` | capture stats + profile completeness dashboard | `features/profile.md` |
| `skills/home/SKILL.md` | `/hae:home` | manage `weighting.homes` | `features/weighting.md` |
| `skills/backfill/SKILL.md` | `/hae:backfill` | one-shot history import | `features/backfill.md` |
| `skills/consolidate/SKILL.md` | `/hae:consolidate` | merge per-session files | `features/consolidate.md` |
| `skills/classify/SKILL.md` | `/hae:classify` | one classify batch | `features/classify.md` |
| `skills/classify-bulk/SKILL.md` | `/hae:classify-bulk` | spawn subagent loop | `features/classify.md` |
| `skills/twin/SKILL.md` | `/hae:twin` | invoke twin emulator | `features/twin.md` |
| `skills/statusline/SKILL.md` | `/hae:statusline` | install / preview / restore | `features/statusline.md` |

## Schema

| File | Purpose | Chunk |
|------|---------|-------|
| `schema/record.schema.json` | JSON Schema for raw + structured records | `patterns/jsonl-records.md` |

## Config

| Key path | Purpose | Chunk |
|----------|---------|-------|
| `capture.enabled` | global on/off | `features/capture.md` |
| `capture.redact_patterns` | regex list applied before write | `features/redaction.md` |
| `capture.max_prompt_chars` | truncate cap | `features/capture.md` |
| `weighting.homes` | home-project list | `features/weighting.md` |
| `weighting.{home,other}_weight` | scoring multipliers | `features/weighting.md` |
| `weighting.project_overrides` | per-project weight overrides | `features/weighting.md` |
| `privacy.store_full_paths` | path PII control | `patterns/jsonl-records.md` |
| `privacy.path_segments_kept` | tail length for `*_tail` fields | `patterns/jsonl-records.md` |
| `phase` | phase tag stamped on each record | `architecture/overview.md` |

## Pipelines

```
UserPromptSubmit -> capture_prompt.ps1 -> raw/<date>__<sid>.jsonl ┐
Stop             -> capture_response.ps1 -------------------------┤
                                                                  v
              classify.ps1 (auto + LLM) -> structured/<yyyy-MM>.jsonl + overrides.jsonl
                                                                  v
                          twin.ps1 -> markdown / JSON context for hae-twin agent
                                                                  v
                            /hae:twin / release-plan inline twin invocation
```

See `architecture/overview.md` for the full pipeline diagram.

## Task -> chunks crossref

When working on a topic, read the listed chunks before editing.

| Working on... | Read also |
|---------------|-----------|
| capture hook (`capture_*.ps1`) | `features/capture.md`, `patterns/hot-path.md`, `features/redaction.md` |
| classifier (`classify.ps1`) | `features/classify.md`, `architecture/classify-pipeline.md`, `patterns/jsonl-records.md` |
| twin context (`twin.ps1`, `/hae:twin`) | `features/twin.md`, `architecture/twin-pipeline.md` |
| twin gates (slash commands) | `patterns/twin-gate.md` |
| profile (`profile/`, `/hae:profile`) | `features/profile.md`, `architecture/profile-system.md` |
| weighting / homes (`manage_homes.ps1`) | `features/weighting.md` |
| install / uninstall (`install_*.ps1`) | `features/install.md`, `patterns/idempotent-installer.md` |
| statusline | `features/statusline.md` |
| backfill (`backfill_history.ps1`) | `features/backfill.md` |
| consolidate (`consolidate.ps1`) | `features/consolidate.md` |
| record schema | `patterns/jsonl-records.md` |
| data root resolution | `patterns/data-root-resolution.md` |
| PowerShell conventions | `patterns/powershell-conventions.md` |
| auto-promote homes | `features/weighting.md` (after H9), `features/classify.md` |
