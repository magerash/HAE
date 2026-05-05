---
name: classify-bulk
description: Spawn a subagent that runs the HAE classifier in a loop across many batches, in its own fresh context. Returns a summary to the main conversation without polluting it with raw records. Use when user invokes /hae:classify-bulk, asks "classify all", "classify everything", "classify in bulk", "process the whole backlog", or wants throughput over inspection.
---

# /hae:classify-bulk - subagent classifier loop

The single-batch `/hae:classify` is good for learning/spot-checks. For thousands of records, spawn a subagent that runs the classify loop in its own context.

## Procedure

### 1. Pre-flight

Run state once to show user the workload:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<haeRoot>/scripts/classify.ps1" state
```

If `Unclassified: 0`, stop with "Nothing to do."

### 2. Determine batch parameters

Parse user intent:

| User says | Args |
|-----------|------|
| "/hae:classify-bulk" alone | 30 records per batch, 50 batches max (=1500 records ceiling per spawn) |
| "small batches" | -N 15 |
| "big batches" | -N 50 |
| "all" / "until done" | -BatchLimit 999 (subagent stops only when state shows 0) |
| "first 100" | -BatchLimit 4 with -N 25 |

Compute estimate: `unclassified / N` batches needed. If estimate > 50, warn user it may need multiple spawns and ask to confirm one spawn at a time.

### 3. Spawn the subagent

Use the Agent tool with `subagent_type: general-purpose` and the prompt below. Pass `<haeRoot>`, batch_size, batch_limit, max_prompt_chars (default 1500) substituted in.

```
You are the HAE bulk classifier. Your only job is to loop through unclassified records, classify each per the HAE taxonomy, and append results until the batch limit is hit OR the queue empties.

Plugin path: <haeRoot>
Batch size (-N): <batch_size>
Batch limit: <batch_limit>
Max prompt chars (-MaxPromptChars): <max_prompt_chars>

Loop until done OR limit hit:

  1. Run:
     powershell -NoProfile -ExecutionPolicy Bypass -File "<haeRoot>/scripts/classify.ps1" next-batch -N <batch_size> -MaxPromptChars <max_prompt_chars>

  2. If output is "[]" or empty, queue done. Break loop.

  3. Parse the JSON array. For EACH record build a structured object with these fields:

     PASS THROUGH UNCHANGED: id, ts, session_id, project, is_home_project, project_weight, source

     CLASSIFY (analyze the prompt text):
       category:                 one of FEATURE | BUG | RESEARCH | RELEASE_OPS | CODE_QA | REFACTOR | META | PLANNING
       subcategory:              short free-form tag, e.g. "v2-month-redesign", "reminder-bug", or null
       intent_verbs:             top 1-3 verbs from prompt
       entities:                 {files: [...], features: [...], libs: [...], agents: [...]} -- only what is mentioned
       scope_signal:             trim | hold | expand
       evidence_demand:          0-10 ("research", "ultrathink", "compare options" -> 7-9; "just do it" -> 1-2)
       risk_appetite:            0-10 (big bets, refactors, kills -> 7-9; small fixes -> 2-4)
       urgency:                  low | med | high
       decision_made:            string if operator chose between options, else null
       decision_rationale:       string if operator gave reason, else null
       operator_overrode_agent:  true ONLY when prompt explicitly contradicts a clear prior agent proposal (e.g. "no, do X", "stop, change to Y", "[Request interrupted]"). Default false.
       override_axis:            scope | evidence | risk | approach | priority | other (when override=true) else null
       agent_proposal_summary:   1-sentence recap when override=true, else null
       retrieval_text:           1-2 sentence compact summary (operator intent + key entities)
       classifier_version:       "v0.1.0-claude-bulk"
       persona_version:          null
       embedding:                null

     System-injected messages ("Ultraplan terminated...", "Remote Ultraplan session failed...", "[Request interrupted...]") -> category=META, subcategory="system-message" or "user-interrupt", evidence_demand/risk_appetite=0-2.

  4. Write the classified array to a temp JSON file (use Write tool to <USERPROFILE>/AppData/Local/Temp/hae_bulk_<UUID>.json).

  5. Pipe the temp file to:
     cat "<temp_file>" | powershell -NoProfile -ExecutionPolicy Bypass -File "<haeRoot>/scripts/classify.ps1" append

  6. Delete the temp file.

  7. Track running totals: batches done, records classified, categories histogram, overrides count, errors.

  8. If batches done >= <batch_limit>, break.

  9. Goto 1.

After loop, return ONE summary message to the main conversation:
  - Batches completed: N
  - Records classified: N
  - Categories: {FEATURE: N, BUG: N, ...}
  - Override deltas: N
  - Remaining unclassified: N (run /hae:classify-bulk again to continue)
  - Errors: N (with brief notes if any)
  - Elapsed: HH:MM:SS

Do NOT print prompt text in your summary (privacy). Do NOT enter loops shorter than 1 batch (always do at least one).
Failure mode: if any tool call returns an error, log to summary and continue with next batch (do not abort whole loop unless 3 consecutive failures).
```

### 4. Surface subagent output

When the Agent returns, just relay its summary verbatim. Add one line at end suggesting next step:
- If remaining > 0: "Run `/hae:classify-bulk` again to continue."
- If remaining == 0: "All classified. Phase 4 twin can now use the structured store."

## Don't

- Don't spawn the subagent before showing pre-flight state to user
- Don't pass huge batch sizes (>50) without warning context cost to subagent
- Don't run two subagent spawns in parallel - state file isn't designed for concurrent writes
- Don't include any user prompts in the summary (privacy)
- Don't fabricate progress numbers - they come from the subagent's running tally
