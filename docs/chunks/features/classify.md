# Classify

## Quick Reference

- Driver: `scripts/classify.ps1`
- Bulk loop: `scripts/classify_nightly.ps1` + `skills/classify-bulk/SKILL.md`
- Slash commands: `/hae:classify` (single batch), `/hae:classify-bulk` (loop)
- Output: `<dataRoot>\prompts\structured\<yyyy-MM>.jsonl` + `overrides.jsonl`
- State: `<dataRoot>\state\classified_ids.json`
- Related chunks: `architecture/classify-pipeline.md`, `features/twin.md`, `patterns/jsonl-records.md`

## Overview

Classify converts raw prompts into a structured taxonomy used by twin retrieval. Two stages: rule-based auto-classifier (no LLM cost) and an LLM batch for everything else.

## Subcommands

```powershell
# show counts
scripts\classify.ps1 state

# emit next N records that need LLM classification (after auto-pass)
scripts\classify.ps1 next-batch -N 20 -MaxPromptChars 2000

# stdin a JSON array of classified records, write to structured/, mark done
scripts\classify.ps1 append < classified.json
```

## Auto-classifier (saves ~40% LLM cycles)

Skips LLM for:

| Pattern | Subcategory | Marked override? |
|---------|-------------|------------------|
| `[Request interrupted by user for tool use]` | `user-interrupt` | yes |
| `^Ultraplan terminated` | `system-message` | no |
| `^Remote Ultraplan session failed` | `system-message` | no |
| short prompt in approval lexicon (`yes`, `ok`, `continue`, `stop`, ...) | `operator-approval` | no |
| single `[A-Za-z0-9]` (menu pick) | `menu-pick` | no |
| pure system blocks after stripping | `system-noise` | no |

`Strip-SystemBlocks` removes `<system-reminder>`, `<task-notification>`, `<local-command-*>`, `<command-*>` blocks before LLM-bound prompts to raise signal density.

## Adding an auto-rule

1. Add a branch to `Get-AutoClassification` in `classify.ps1` matching the pattern.
2. Set sensible defaults on the `$base` ordered hashtable (category, subcategory, scope_signal, etc).
3. Set `retrieval_text` so twin can find these by keyword.
4. Bump `classifier_version` in `_lib.ps1` defaults.
5. Run `state` then `next-batch` and confirm new bucket appears in stderr stats.

## Override exemplars

Records with `operator_overrode_agent = true` get appended to `overrides.jsonl` in addition to the monthly file. Twin retrieval boosts these by +5 baseline -> high-signal training data.

## Throughput

`/hae:classify-bulk` spawns a fresh-context subagent that loops `next-batch` -> LLM -> `append` until backlog drains. Returns summary only -> main conversation context stays clean.

## Common Issues

- **State drift** (state has ids no longer in raw): harmless; state is a "done" set, not a join.
- **Re-classifying same id twice**: `append` skips ids already in state. Append is idempotent per id.
- **Empty `next-batch` despite raw backlog**: every record matched auto-rules; check stderr `auto-classified: N` line.
- **LLM returns malformed JSON**: `append` requires top-level array. Wrap single object as `[obj]` before piping.
