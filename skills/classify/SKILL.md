---
name: classify
description: Classify raw HAE records into structured taxonomy (FEATURE/BUG/RESEARCH/RELEASE_OPS/CODE_QA/REFACTOR/META/PLANNING) plus scope_signal, risk_appetite, evidence_demand, urgency, intent_verbs, entities. Phase 3. One batch (default 20) per invocation; idempotent via state file. Use when user invokes /hae:classify, asks "classify HAE prompts", "process HAE backlog", or "classify all".
---

# /hae:classify - classifier pass

Classifies one batch of unclassified raw records per invocation. The user's Claude Code model (you) does the actual classification; the helper script handles I/O + state.

`<haeRoot>` = `C:\Users\Magerash\.claude\plugins\marketplaces\hae-local\plugins\hae` (plugin install path) OR `C:\Projects\My habits\.hae` (dev path).

## Procedure

### 1. Check state

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<haeRoot>/scripts/classify.ps1" state
```

Surface the counts. If `Unclassified: 0`, tell user "All classified. Nothing to do." and stop.

### 2. Get next batch

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<haeRoot>/scripts/classify.ps1" next-batch -N 20
```

Captures JSON array. Each record has: `id, ts, session_id, project, is_home_project, project_weight, source, event, prompt`. (Stop-event records are auto-skipped + marked done.)

If the array is empty (`[]`), nothing left - report and stop.

### 3. Classify each record

For EACH record in the batch, build a structured object that:

**Passes through unchanged from input:**
- `id`, `ts`, `session_id`, `project`, `is_home_project`, `project_weight`, `source`

**Classified fields (analyze the `prompt` text):**

| Field | Type | Notes |
|-------|------|-------|
| `category` | enum | one of `FEATURE`, `BUG`, `RESEARCH`, `RELEASE_OPS`, `CODE_QA`, `REFACTOR`, `META`, `PLANNING` |
| `subcategory` | string\|null | short free-form tag e.g. "v2-month-redesign", "reminder-bug" |
| `intent_verbs` | array | top 1-3 verbs from prompt e.g. `["add", "fix"]` |
| `entities` | object | `{files: [], features: [], libs: [], agents: []}` - only what's mentioned |
| `scope_signal` | enum | `trim` cuts/removes scope, `hold` no scope change, `expand` adds/extends |
| `evidence_demand` | int 0-10 | "research carefully", "ultrathink" -> 8-9; "just do it" -> 1-2 |
| `risk_appetite` | int 0-10 | big bets, refactors, major changes -> 7-9; small fixes -> 2-4 |
| `urgency` | enum | `low`, `med`, `high` |
| `decision_made` | string\|null | if operator chose between options, e.g. "split into 2 PRs not 1" |
| `decision_rationale` | string\|null | if operator gave reason |
| `operator_overrode_agent` | bool | true ONLY when prompt contradicts a clear prior agent proposal evident in the prompt itself ("no, do X instead", "stop, change to Y"). Default false. (Full cross-turn override detection is Phase 3.5.) |
| `override_axis` | enum\|null | when override=true: `scope`, `evidence`, `risk`, `approach`, `priority`, `other` |
| `agent_proposal_summary` | string\|null | when override=true: 1-sentence recap of what was overridden |
| `retrieval_text` | string | 1-2 sentence compact summary for future embedding (operator intent + key entities) |
| `classifier_version` | string | `"v0.1.0-claude"` |
| `persona_version` | string\|null | null until profile exists |
| `embedding` | null | Phase 4 |

### 4. Append batch

Pipe the classified JSON array to:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<haeRoot>/scripts/classify.ps1" append
```

Script writes to `prompts/structured/<YYYY-MM>.jsonl` (one file per UTC month) and ALSO appends override records to `prompts/structured/overrides.jsonl` (high-signal exemplars for twin training).

### 5. Report

Print compact summary:

```
Classified N records (batch).
Categories: FEATURE=8 BUG=4 RELEASE_OPS=3 ...
Override deltas: 2 (saved to overrides.jsonl)
Remaining: M unclassified. Run /hae:classify again to continue.
```

## Loop policy

ONE batch per invocation by default. If user says "classify all" or "loop until done", repeat steps 2-5 up to **5 batches** per turn, then ask "Continue?". Don't blow context with hundreds of records in one go.

## Calibration tips

- `evidence_demand` high signals: "research first", "show me data", "compare options", "benchmark", "ultrathink"
- `evidence_demand` low signals: "just do it", "go", "yes", "proceed", "ship it"
- `risk_appetite` high: scope expansion, new architecture, killing features, "let's try", multi-system change
- `risk_appetite` low: "small fix", "minor tweak", "carefully", reverting changes
- `scope_signal: expand` cues: "also add", "while you're there", "let's also", "include X too"
- `scope_signal: trim` cues: "skip", "drop", "just", "only", "don't bother with", "minimal"
- `category: META` when prompt is about agent behavior itself: "always do X", "stop doing Y", "next time"

## Don't

- Don't classify Stop records (script auto-skips)
- Don't fabricate entities - only list what's in the prompt
- Don't editorialize prompt content in the report
- Don't print prompt text in the report (privacy)
- Don't write directly to `structured/` files - always pipe through `classify.ps1 append`
- Don't reclassify (state file dedupes; script ignores already-classified ids on append)
