# Backfill

## Quick Reference

- Driver: `scripts/backfill_history.ps1`
- Skill: `/hae:backfill` -> `skills/backfill/SKILL.md`
- Source: `~/.claude/projects/<project-slug>/<session-id>.jsonl` (Claude Code's transcript store)
- State: `<dataRoot>\state\backfilled_sessions.json`
- Output: appended to `<dataRoot>\prompts\raw\<date>__<sid>.jsonl` with `source: "backfill"`
- Related chunks: `features/capture.md`, `features/redaction.md`

## Overview

One-shot import of historical Claude Code session transcripts into the HAE raw store. Optional - HAE works on live capture alone, but backfill seeds the override + structured pool so twin has signal from day one.

## Behavior

1. Walk `~/.claude/projects/`.
2. For each `<session-id>.jsonl`, skip if `session-id` already in `state/backfilled_sessions.json`.
3. Extract user prompts (and optionally assistant responses, via flag).
4. Apply same redaction / weighting / PII pipeline as live capture.
5. Append to per-session HAE raw file. Stamp `source: "backfill"`, `phase: <current>`.
6. Add `session-id` to `backfilled_sessions.json`.

Idempotent: re-running only processes sessions not already in state.

## Flags

- `-IncludeResponses` - also import assistant turns (more storage, more context for twin)
- `-Limit N` - cap sessions imported (smoke test)
- `-Project <name>` - restrict to one project slug

## Effect on classifier

Backfilled records land in raw/ as a normal capture. `/hae:classify` then processes them (auto-rules absorb a large fraction since old transcripts contain many `[Request interrupted...]` and short approval prompts).

## Validation marker

After backfill, `/hae:status` should show non-zero raw count even if live capture is paused. Override pool grows materially after subsequent classify.

## Common Issues

- **Repeated runs grow state but not raw**: state file already contains the sessions. Delete `state/backfilled_sessions.json` only if you intentionally want a re-import (will produce duplicate ids - dedupe runs at classify time).
- **Source path missing**: Claude Code project store moved or differs by OS. Confirm `~/.claude/projects/` exists.
- **Encoding mojibake**: Claude Code transcripts are UTF-8; if your locale isn't, ensure backfill script uses `-Encoding UTF8`.
