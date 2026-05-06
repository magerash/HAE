# Consolidate

## Quick Reference

- Driver: `scripts/consolidate.ps1`
- Skill: `/hae:consolidate` -> `skills/consolidate/SKILL.md`
- Input: `<dataRoot>\prompts\raw\<date>__<sid>.jsonl` (per-session)
- Output: `<dataRoot>\prompts\raw\<date>.jsonl` (combined daily)
- Related chunks: `features/capture.md`, `architecture/classify-pipeline.md`

## Overview

Optional housekeeping: merges per-session raw files into a single dated file. Useful before bulk classify on a large historical backlog, where 1000s of small files slow `Get-ChildItem` enumeration.

Live capture continues to write per-session files (one writer per file invariant). Consolidate runs only on past dates - never on the current UTC date.

## Behavior

1. Enumerate `*__*.jsonl` files older than today (UTC).
2. For each date, concatenate all `<date>__<sid>.jsonl` files into `<date>.jsonl`.
3. Verify line count matches sum of inputs.
4. Move source files to `<dataRoot>\prompts\raw\.archive\<date>\` (or delete if `-Delete` flag).

Idempotent: existing `<date>.jsonl` is appended to or skipped based on contents.

## When to run

- Backlog has 100+ session files for a single date.
- Before `/hae:classify-bulk` on historical data (faster enumeration).
- Periodic monthly cleanup.

## When NOT to run

- For the current UTC date (would conflict with live capture).
- Before debugging a specific session's capture (you'll lose the per-session boundary).

## Common Issues

- **Live capture wrote to a "consolidated" date file**: the consolidator must skip `<date>.jsonl` itself when re-running; only merge `*__*.jsonl` shapes.
- **Line count mismatch**: a source file had a non-newline-terminated last line. Consolidator should append `\n` defensively when reading.
- **Archive grows unbounded**: prune `.archive/` after a retention window (e.g. 90 days).
