# Capture Pipeline

## Quick Reference

- Hook bindings: `hooks/hooks.json` (binds UserPromptSubmit + Stop)
- Hot path scripts: `scripts/capture_prompt.ps1`, `scripts/capture_response.ps1`
- Output: `<dataRoot>\prompts\raw\<UTC-date>__<sid8>.jsonl`
- Config keys: `capture.enabled`, `capture.max_prompt_chars`, `capture.redact_patterns`, `capture.include_response`, `privacy.*`, `weighting.*`
- Schema: `schema/record.schema.json`
- Related chunks: `features/capture.md`, `features/redaction.md`, `features/weighting.md`, `patterns/hot-path.md`, `patterns/jsonl-records.md`

## Overview

Two hooks fire per round trip:

1. `UserPromptSubmit` -> `capture_prompt.ps1` records the operator's prompt.
2. `Stop` -> `capture_response.ps1` records the assistant's response tail (gated by `capture.include_response`).

Both are hot-path: must complete fast, never block Claude Code, swallow all exceptions, exit 0.

## Steps (UserPromptSubmit)

1. Read stdin as raw bytes -> decode UTF-8 -> parse JSON. Console encoding independence is mandatory.
2. Load config via `Get-HaeConfig` (`_lib.ps1`). Bail if `capture.enabled = false`.
3. Truncate prompt at `capture.max_prompt_chars` (append `...[TRUNCATED]`).
4. Apply `capture.redact_patterns` (regex list) -> `[REDACTED]`.
5. Compute `is_home_project` + `project_weight` from `cwd` against `weighting.homes` (path prefix or basename match).
6. Hash + tail `cwd` and `transcript_path` if `privacy.store_full_paths = false`.
7. Build ordered record (id, ts, event, session_id, cwd*, transcript*, project, is_home_project, project_weight, prompt, prompt_chars, hae_phase, source).
8. Append one JSON line to `<dataRoot>\prompts\raw\<date>__<sid8>.jsonl` via `[System.IO.File]::AppendAllText` with UTF-8 no-BOM encoder.

## Steps (Stop)

Same skeleton, but:
- Reads transcript tail (default 50 lines) inline from the transcript file.
- `event = "Stop"`.
- Gated by `capture.include_response`.

## Failure mode

`$ErrorActionPreference = 'SilentlyContinue'`, outer `try { } catch { }`, always `exit 0`. A capture failure must never surface to the operator.

## Common Issues

- **Empty file** for a session: `capture.enabled` flipped off, or `capture_prompt.ps1` failed silently. Check `<dataRoot>` path resolution via `Resolve-HaeDataRoot`.
- **Redaction missed a secret**: extend `capture.redact_patterns` in `config.default.json` (and in user config if the project owner overrides). See `features/redaction.md`.
- **Wrong project weight**: confirm `weighting.homes` entry shape (path prefix needs slash; basename has no slash). See `features/weighting.md`.
- **Mojibake / UTF-16 BOM** in JSONL: a writer used `Out-File` defaults instead of the UTF-8 no-BOM encoder. Stick to `[System.IO.File]::AppendAllText`.
