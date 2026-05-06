# Architecture Overview

## Quick Reference

- Plugin manifest: `.claude-plugin/plugin.json`
- Hook bindings: `hooks/hooks.json`
- Config (defaults): `config.default.json`
- Config (user): `%USERPROFILE%\.hae\config.user.json` (or `$env:HAE_DATA_DIR\config.user.json`)
- Data root: `%USERPROFILE%\.hae\` by default; override via `$env:HAE_DATA_DIR`
- Related chunks: `architecture/capture-pipeline.md`, `architecture/classify-pipeline.md`, `architecture/twin-pipeline.md`, `architecture/profile-system.md`

## Overview

HAE (Habits AI Emulator) is a Claude Code plugin that captures the operator's prompts + responses, classifies them into a structured taxonomy, builds a behavioral profile, and exposes a "twin" subagent that can stand in for the operator on scope/release decisions.

Standalone plugin: code lives in `C:\Projects\HAE`, ships to `C:\Plugins\hae`, data lives at `%USERPROFILE%\.hae`. No personal data crosses repo boundaries.

## Layers

```
+----------------------------------------------------+
| Claude Code (host)                                 |
|   UserPromptSubmit hook --+                        |
|   Stop hook --------------|--+                     |
|   /hae:* slash commands --|--|--+                  |
+---------------------------|--|--|------------------+
                            v  v  v
+----------------------------------------------------+
| HAE plugin (PowerShell + Markdown)                 |
|   scripts/capture_*.ps1   <- hot path (<50ms)      |
|   scripts/classify.ps1    <- batch classifier      |
|   scripts/twin.ps1        <- context composer      |
|   scripts/install_*.ps1   <- idempotent installers |
|   skills/<n>/SKILL.md     <- slash command surface |
|   agents/hae-twin.md      <- subagent persona      |
+----------------------------------------------------+
                            |
                            v
+----------------------------------------------------+
| Data root (%USERPROFILE%\.hae or $env:HAE_DATA_DIR)|
|   prompts/raw/<date>__<sid>.jsonl                  |
|   prompts/structured/<yyyy-MM>.jsonl               |
|   prompts/structured/overrides.jsonl               |
|   profile/persona.md + paei.json + hexaco.json     |
|   profile/custom.json + principles.md              |
|   state/classified_ids.json                        |
|   state/backfilled_sessions.json                   |
+----------------------------------------------------+
```

## Phases (current = 5 done @ v0.4.0)

| Phase | Goal | State |
|-------|------|-------|
| 0 | scaffold + manifest | done v0.1.0 |
| 1 | live capture | done v0.1.0 |
| 2 | profile (PAEI + HEXACO + custom + principles + persona) | done v0.3.0 |
| 3 | classifier (auto + LLM) | done v0.2.0 |
| 4 | twin agent (persona + exemplar retrieval) | done v0.2.0 |
| 5 | release-manager integration + standalone repo + global install + config split | done v0.4.0 |

## Hot path vs cold path

- **Hot path** (sub-50ms, fires on every prompt): `capture_prompt.ps1`, `capture_response.ps1`. Must `try { } catch { }` everything and `exit 0`. See `patterns/hot-path.md`.
- **Cold path** (manual / scheduled / on-demand): classify, consolidate, twin, report, status, install, manage_homes. May error loudly.

## Key invariants

- One writer per file: per-session filename `<date>__<sid8>.jsonl` guarantees no append race within a session and no cross-session contention.
- Privacy default: `privacy.store_full_paths = false` -> `cwd` and `transcript_path` blanked, replaced by `*_hash` (16-hex SHA-256) + `*_tail` (last N segments).
- Redaction always runs on prompt text before write: GitHub PATs, OpenAI keys, AWS keys, JWTs, PEM blocks, DB URLs with creds, emails, generic password/token assignments.
- `phase` field on every raw record tags which phase produced it - used for migration tracking.
