---
name: backfill
description: One-shot import of historical Claude Code session transcripts into HAE raw store. Optional. Walks ~/.claude/projects/, extracts user prompts + (optionally) assistant responses, applies same redaction/weighting/PII pipeline as live capture. Idempotent — tracks processed sessions in .hae/state/backfilled_sessions.json. Use when user invokes /hae:backfill, asks "import history", "backfill HAE", or wants to seed twin training data from past sessions.
---

# /hae:backfill — import history (one-shot, optional)

Imports already-on-disk Claude Code session transcripts into the HAE raw store so the twin agent has training signal from day 1 instead of day 30.

## Procedure

### 1. Confirm intent + scope

Ask the user:
- Run dry-run first to see how many sessions + records would be imported? (Recommended if first time.)
- Limit to N most recent sessions, or import all?
- Include assistant responses too? (Larger output; controlled by `config.capture.include_response`.)

Based on answers, build the command:

```powershell
# Dry run (no writes)
powershell "C:\Projects\My habits\.hae\scripts\backfill_history.ps1" -DryRun

# Real run, all sessions
powershell "C:\Projects\My habits\.hae\scripts\backfill_history.ps1"

# Real run, limit to first 50 unprocessed sessions
powershell "C:\Projects\My habits\.hae\scripts\backfill_history.ps1" -MaxSessions 50

# Force reprocess (ignores .hae/state/backfilled_sessions.json)
powershell "C:\Projects\My habits\.hae\scripts\backfill_history.ps1" -ForceReprocess
```

### 2. Run + capture summary

Execute the chosen command. Surface the script's summary block:

```
Backfill summary
  Sessions processed this run: N
  Sessions skipped (already done): N
  Records written: N
  Total sessions backfilled (lifetime): N
  Total records backfilled (lifetime): N
```

### 3. Suggest next step

After successful import:
- Run `/hae:consolidate` to merge per-session backfill files into combined dated files (optional)
- Run `/hae:status` to see the new totals
- Run `/hae:classify` (when implemented) to categorize the imported records

## What backfill captures

- One record per user prompt in each session transcript
- One record per assistant message (only if `config.capture.include_response = true`)
- Records carry `source: "backfill"` to distinguish from live `source: "hook"` records
- Per-session file naming: `prompts/raw/<date>__bf-<sid8>.jsonl` (the `bf-` prefix marks backfill origin)
- Same redaction + path-PII + weighting pipeline as live capture
- `is_home_project` derived from decoded project-dir slug (`-C--Projects-My-habits` → `C:\Projects\My habits`)

## What backfill cannot capture

- `permission_mode` per turn (not in transcript schema; only set on live hook payload)
- Hook-injected metadata (was the prompt amended by a UserPromptSubmit hook? unknowable post-hoc)
- Operator-overrode-agent flag — Phase 3 classifier infers this from prompt+prior-assistant pairing, which IS available in transcripts

## Privacy

- Same redaction patterns as live capture — secrets stripped before write
- Same path-PII rules — full paths only if `privacy.store_full_paths = true`
- Project decoding from slug is best-effort — drives + repo names ARE inferrable from `~/.claude/projects/` directory names regardless of HAE config; backfill respecting `store_full_paths = false` still leaks project names through `project` field (intentional — needed for weighting)

## Don't

- Don't run repeatedly without `-ForceReprocess` — state file makes re-runs cheap (skips known sessions)
- Don't run when capture is disabled — backfill respects `config.capture.enabled` (set true first)
- Don't suggest backfill before the user has asked. It's optional. Some users may not want past data imported.
