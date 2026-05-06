# Twin

## Quick Reference

- Composer: `scripts/twin.ps1`
- Subagent: `agents/hae-twin.md`
- Slash command: `/hae:twin` -> `skills/twin/SKILL.md`
- Inline caller: `.claude/commands/release-plan.md` (Path A: bash subprocess)
- Inputs: `<dataRoot>\profile\persona.md`, `principles.md`, `prompts\structured\*.jsonl`, `overrides.jsonl`
- Related chunks: `architecture/twin-pipeline.md`, `features/profile.md`, `features/classify.md`

## Overview

Twin is an operator emulator. It loads the persona + principles verbatim, retrieves top-K override + topical exemplars relevant to the question, and produces a "twin take" answer in a fixed format.

## Calling

```powershell
# default markdown out (paste into a subagent system prompt)
.\scripts\twin.ps1 "should we add embeddings to twin retrieval now or ship v1 keyword-match first?"

# tune retrieval
.\scripts\twin.ps1 -K 8 -KOverrides 5 "release scope question..."

# JSON for programmatic consumers
.\scripts\twin.ps1 -JsonOutput "..."
```

`/hae:twin` does the same with a guided prompt.

## Retrieval

- Question tokens: split on `\W+`, length > 3, lowercased, deduped.
- Per-record relevance text: `retrieval_text + subcategory + decision_made + decision_rationale + entities.{features,libs,files,agents}`.
- Score: matched-token count * `project_weight`.
- Override pool baseline: +5.0 (so even non-keyword-matching overrides surface).
- Pick top `KOverrides` overrides, top `K - KOverrides` topical (default `K=6`, `KOverrides=3`).

## Output contract

Markdown form:

```
# Twin context for question: > <q>
## Operator persona (load verbatim)
## Operator-authored principles (verbatim, non-negotiable)
## Override exemplars (pool=N)
## Topical exemplars (pool=N)
## Twin instructions
```

JSON form: `{ question, persona_loaded, persona, principles, exemplars[], stats{} }`.

## Twin answer format (enforced in instructions block)

- **Twin take:** one-sentence position
- **Why this position:** 2-4 bullets
- **Risk in this call:** failure mode
- **Confidence:** low | medium | high
- Sign with: `- twin (low-confidence persona, partial profile)` if persona thin

## Path A integration (release-plan)

`.claude/commands/release-plan.md` invokes twin via bash subprocess at decision points:

```bash
pwsh -NoProfile -File scripts/twin.ps1 -JsonOutput "<scoped question>" | jq '...'
```

Twin output is injected inline as the operator surrogate when the operator is unavailable.

## Common Issues

- **Persona NOT YET BUILT**: `/hae:profile` not run. Twin falls back to overrides + topical only.
- **Empty override pool**: classify hasn't flagged any overrides yet. Backfill + classify history; or wait for live signal.
- **All scores 0**: question keywords too short or mismatch. Override pool still surfaces via baseline boost.
- **Stale persona**: persona.md not regenerated after questionnaire change. Re-run `/hae:profile`.
