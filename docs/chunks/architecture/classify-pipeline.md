# Classify Pipeline

## Quick Reference

- Driver: `scripts/classify.ps1` with subcommands `state | next-batch | append`
- Bulk loop: `scripts/classify_nightly.ps1`, `skills/classify-bulk/SKILL.md`
- Input:  `<dataRoot>\prompts\raw\*.jsonl`
- Output: `<dataRoot>\prompts\structured\<yyyy-MM>.jsonl` + `overrides.jsonl`
- State:  `<dataRoot>\state\classified_ids.json`
- Related chunks: `features/classify.md`, `architecture/twin-pipeline.md`, `patterns/jsonl-records.md`

## Overview

Classify converts raw prompt records into structured taxonomy entries. Two stages:

1. **Auto-classification** (no LLM, ~40% of backlog): pattern-match known system messages, approval lexicon, single-character menu picks, pure system-injected prompts.
2. **LLM batch**: emit JSON of next N unclassified records to stdout for an LLM caller; LLM returns the same shape with category + scope_signal + override fields filled; `append` writes them.

Idempotent: re-running `classify` is safe. State file tracks which `id`s are already classified.

## Subcommands

| Sub | Stdin | Stdout | Effect |
|-----|-------|--------|--------|
| `state` | - | counts to host | none |
| `next-batch [-N 20] [-MaxPromptChars 2000]` | - | JSON array | auto-classifies system patterns, writes them to structured/, marks done. Emits remaining LLM-needed records. |
| `append` | JSON array of classified records | summary | writes records to monthly file + overrides.jsonl, marks done |

## Auto-classification rules

| Trigger | Subcategory | Notes |
|---------|-------------|-------|
| `[Request interrupted by user for tool use]` | `user-interrupt` | flagged as override; high signal |
| `^Ultraplan terminated...` | `system-message` | agent = Ultraplan |
| `^Remote Ultraplan session failed` | `system-message` | agent = Ultraplan |
| short prompt in approval lexicon (`yes`, `ok`, `continue`, `stop`...) | `operator-approval` | <=30 chars |
| single `[A-Za-z0-9]` | `menu-pick` | numbered/lettered list pick |
| pure system blocks (only `<system-reminder>`, `<task-notification>`, `<local-command-*>`, `<command-*>`) | `system-noise` | no operator intent |

`Strip-SystemBlocks` removes embedded system blocks before LLM-bound prompts -> higher signal density per token.

## Structured record shape (extends raw)

Adds: `category` (FEATURE/BUG/RESEARCH/RELEASE_OPS/CODE_QA/REFACTOR/META/PLANNING), `subcategory`, `intent_verbs`, `entities` (files/features/libs/agents), `scope_signal` (expand/hold/trim), `evidence_demand` (0..5), `risk_appetite` (-3..3), `urgency` (low/normal/high), `decision_made`, `decision_rationale`, `operator_overrode_agent`, `override_axis`, `agent_proposal_summary`, `retrieval_text`, `classifier_version`, `persona_version`, `embedding`.

`operator_overrode_agent = true` -> record additionally appended to `overrides.jsonl` (high-signal training data for twin).

## Common Issues

- **Re-classification of done records**: `state` file corruption. Delete `state/classified_ids.json` and let auto-pass re-mark; LLM cost is paid only on truly unclassified records.
- **Duplicate ids across raw files** (e.g. after consolidate + raw both retained): `Get-AllRawRecords` dedupes by `id` first.
- **Stop records counted as user prompts**: classifier skips `event in (Stop, StopMarker)` and marks them done with no structured output.
