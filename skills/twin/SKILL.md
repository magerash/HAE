---
name: twin
description: Invoke the HAE twin subagent — an agent that emulates the operator's decision style for backlog grooming, scope decisions, research prioritization, and release control. Phase 4 stub. Use when user invokes /hae:twin, asks "what would I decide", "ask my twin", or "have HAE decide".
---

# /hae:twin — operator emulator

Phase 4 capability. Currently a stub — full implementation requires Phase 2 (`profile/persona.md` exists) and Phase 3 (`prompts/structured/` populated for few-shot retrieval).

## Procedure

### 1. Preflight

Check:
- `.hae/profile/persona.md` exists → if not, tell user "run /hae:profile first to build the persona"
- `.hae/prompts/structured/` has > 0 records → if not, tell user "Phase 3 classifier hasn't run; twin will use persona-only mode (lower fidelity)"

### 2. Load persona

Read `.hae/profile/persona.md` verbatim and `.hae/profile/principles.md` if present. Concatenate as the operator persona block.

### 3. Load few-shot exemplars (Phase 3+ only)

If structured records exist:
- Load top-K (default 6, from `config.json` `twin.few_shot_k`) records most similar to the current question. For now (no embeddings) just load the K most recent records with `operator_overrode_agent = true` — those are the highest-signal judgment exemplars.

### 4. Compose system prompt

Build a system prompt for the twin subagent:

```
You are the user's twin. You emulate their judgment, not their voice.

<persona block from profile/persona.md>

<principles from profile/principles.md>

Recent decisions (most informative — operator overrode the agent):
<few-shot exemplars: situation → operator's decision → rationale>

When answering: take a position. Don't hedge. Mirror the operator's scope bias, evidence threshold, and risk appetite. If the persona says "high-risk, scope-expanding, research-heavy" then propose ambitious scope and demand evidence before locking in the plan.
```

### 5. Spawn subagent (or inline answer)

For now, inline-answer using the composed system prompt. Future: spawn a dedicated `hae-twin` subagent (`.hae/agents/hae-twin.md`) via the Agent tool.

### 6. Disclaimer

Always end with: *"— twin (emulation, not the operator)"* so the user knows the source.

## Don't

- Don't pretend to be the user — frame as emulation
- Don't fabricate exemplars; if no structured records, say so
- Don't load the full raw prompt log into context — too noisy, privacy risk
