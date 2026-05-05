---
name: twin
description: Invoke the HAE twin subagent — an agent that emulates the operator's decision style for backlog grooming, scope decisions, research prioritization, and release control. Use when user invokes /hae:twin, asks "what would I decide", "ask my twin", or "have HAE decide".
---

# /hae:twin — operator emulator

Returns a structured "twin take" on a decision question. Loads the operator persona, principles, and high-signal override exemplars from the data dir, then composes the take inline.

## Procedure

### 1. Preflight

Check:
- `<dataRoot>/profile/persona.md` exists → if not, tell user "run /hae:profile first to build the persona"
- `<dataRoot>/prompts/structured/` has > 0 records → if not, tell user "Phase 3 classifier hasn't run; twin will use persona-only mode (lower fidelity)"

`<dataRoot>` resolves to `$env:HAE_DATA_DIR` or default `%USERPROFILE%\.hae`. Scripts handle paths.

### 2. Run twin context script

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/twin.ps1" "<the question passed in by the user>"
```

The script returns a markdown block with:
- Operator persona (PAEI + HEXACO + custom decision-style + principles)
- Operator-authored principles (verbatim, non-negotiable)
- Override exemplars (highest-signal training data — past cases where operator overrode an agent)
- Topical exemplars (related decisions from structured pool, keyword-relevance scored)

Use markdown mode (default), NOT `-JsonOutput` — JsonOutput hangs on large structured pools (1000+ records, ConvertTo-Json bottleneck). Markdown returns top-K only, ~4s.

### 3. Compose twin take inline

Apply persona axes + principles + exemplars to the question. Take a clear position. Mirror operator's scope-bias, evidence-demand, risk-appetite. Cite specific principles + exemplars.

### 4. Output format

Return EXACTLY:

```
**Twin take:** <one-sentence position>

**Why this position:**
- <persona/principle/exemplar citation>
- <persona/principle/exemplar citation>

**Risk in this call:** <what could go wrong if the operator follows the twin>

**Confidence:** <low | medium | high>  (low = thin profile signal, high = strong principle + exemplar match)

— twin (emulation, not the operator)
```

## Don't

- Don't pretend to be the operator — frame as emulation
- Don't fabricate exemplars; if no structured records, say so
- Don't load the full raw prompt log into context — too noisy, privacy risk
- Don't use `-JsonOutput` mode (perf bottleneck on large pools)
