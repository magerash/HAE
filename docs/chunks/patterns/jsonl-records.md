# JSONL Record Format

## Quick Reference

- Schema: `schema/record.schema.json`
- Raw output: `<dataRoot>\prompts\raw\<date>__<sid8>.jsonl`
- Structured output: `<dataRoot>\prompts\structured\<yyyy-MM>.jsonl` + `overrides.jsonl`
- Writers: `capture_prompt.ps1`, `capture_response.ps1`, `classify.ps1` (`Write-StructuredRecord`)
- Related chunks: `features/capture.md`, `features/classify.md`, `architecture/capture-pipeline.md`

## Overview

All HAE persistence is line-delimited JSON (JSONL): one record per line, UTF-8 no-BOM, newline-terminated. Records are append-only within a file.

## Common fields (all records)

| Field | Type | Notes |
|-------|------|-------|
| `id` | UUID string | unique per record; classifier dedupe key |
| `ts` | ISO 8601 UTC | `2026-05-06T14:32:01.1234567Z` |
| `event` | string | `UserPromptSubmit` \| `Stop` \| `StopMarker` |
| `session_id` | string | full Claude Code session id |
| `project` | string | basename of cwd; `unknown` if cwd missing |
| `is_home_project` | bool | result of weighting match |
| `project_weight` | number | usually 0.3 / 1.0 / override |
| `source` | string | `hook` \| `backfill` |
| `hae_phase` | int | phase that produced the record |

## Path PII fields

When `privacy.store_full_paths = false` (default):

| Field | Type | Notes |
|-------|------|-------|
| `cwd` | null | full path elided |
| `cwd_hash` | 16-hex | SHA-256 of lowercased cwd, first 16 hex |
| `cwd_tail` | string | last `path_segments_kept` segments joined by `/` |
| `transcript_path` | null | elided |
| `transcript_hash` | 16-hex | as above for transcript path |
| `transcript_tail` | string | as above |

When `privacy.store_full_paths = true`, `cwd` and `transcript_path` carry the original values; hash + tail still emitted.

## Raw-only fields (UserPromptSubmit)

- `permission` (permission_mode)
- `prompt` (post-redaction text)
- `prompt_chars` (length after truncation)

## Raw-only fields (Stop)

- `transcript_tail_lines` (last N lines of transcript)
- `assistant_text` (extracted assistant message text from transcript tail, if any)

## Structured-only fields (added by classifier)

| Field | Type | Range / Values |
|-------|------|---------------|
| `category` | string | FEATURE / BUG / RESEARCH / RELEASE_OPS / CODE_QA / REFACTOR / META / PLANNING |
| `subcategory` | string | free, but stable per category |
| `intent_verbs` | string[] | extracted from prompt |
| `entities` | object | `{ files: string[], features: string[], libs: string[], agents: string[] }` |
| `scope_signal` | string | `expand` \| `hold` \| `trim` |
| `evidence_demand` | int | 0..5 |
| `risk_appetite` | int | -3..3 |
| `urgency` | string | `low` \| `normal` \| `high` |
| `decision_made` | string | what operator chose (overrides only typically) |
| `decision_rationale` | string | why |
| `operator_overrode_agent` | bool | true -> dual-write to `overrides.jsonl` |
| `override_axis` | string \| null | `scope` \| `approach` \| `evidence` \| `risk` \| `priority` |
| `agent_proposal_summary` | string | what agent had proposed |
| `retrieval_text` | string | dense paraphrase used by twin keyword ranker |
| `classifier_version` | string | `v0.1.0-auto` for auto, `v0.1.0-llm` for LLM |
| `persona_version` | string \| null | persona snapshot id when classified |
| `embedding` | number[] \| null | reserved for future vector retrieval |

## Schema invariants

- `id` is the dedupe key. Don't rewrite ids on re-classify.
- `ts` always UTC ISO 8601.
- `operator_overrode_agent = true` MUST be accompanied by `override_axis` not null.
- `retrieval_text` is the only field twin's relevance scorer relies on heavily; classifiers MUST populate it (1-3 sentence paraphrase).
- Adding fields is non-breaking. Removing or renaming requires schema `$id` bump + migration plan.

## File naming

| Path | Pattern |
|------|---------|
| Raw, per-session | `<dataRoot>\prompts\raw\YYYY-MM-DD__<sid8>.jsonl` |
| Raw, consolidated daily | `<dataRoot>\prompts\raw\YYYY-MM-DD.jsonl` |
| Structured, monthly | `<dataRoot>\prompts\structured\YYYY-MM.jsonl` |
| Structured, override pool | `<dataRoot>\prompts\structured\overrides.jsonl` |

## Writing pattern

```powershell
$json = $record | ConvertTo-Json -Compress -Depth 10
[System.IO.File]::AppendAllText($file, $json + "`n", [System.Text.UTF8Encoding]::new($false))
```

Always `-Compress` (one line per record), `-Depth 10` (don't truncate nested entities).

## Common Issues

- **Multi-line JSON in JSONL**: writer forgot `-Compress`. Reader breaks. Fix the writer; don't add a multi-line parser.
- **Duplicate ids across files**: legitimate after consolidate + raw retained, or after re-importing. `Get-AllRawRecords` dedupes by `id`; rely on it.
- **`embedding` becomes large**: reserve for future; current pipelines tolerate `null`. When introduced, store as separate file or compressed binary - JSONL bloats fast.
