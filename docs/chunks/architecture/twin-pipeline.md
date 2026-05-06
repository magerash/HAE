# Twin Pipeline

## Quick Reference

- Composer: `scripts/twin.ps1` (default markdown; `-JsonOutput` for programmatic use)
- Subagent spec: `agents/hae-twin.md`
- Slash command: `/hae:twin` -> `skills/twin/SKILL.md`
- Inputs: `<dataRoot>\profile\persona.md`, `profile\principles.md`, `prompts\structured\*.jsonl`, `prompts\structured\overrides.jsonl`
- Related chunks: `features/twin.md`, `features/profile.md`, `architecture/classify-pipeline.md`

## Overview

Twin builds a focused system prompt for the operator emulator subagent. Combines persona + principles (verbatim) with retrieved exemplars (top-K override + top-K topical) ranked by keyword relevance and project weight.

Two callers:
- `/hae:twin` interactive prompt (default markdown out).
- `/release-plan` inline (Path A): bash subprocess invokes `twin.ps1 -JsonOutput` to inject twin take into release planning.

## Inputs

| Source | Use |
|--------|-----|
| `profile/persona.md` | verbatim persona block (decision-style scores, axis summary) |
| `profile/principles.md` | verbatim non-negotiable rules |
| `prompts/structured/*.jsonl` | topical exemplar pool (excluding `overrides.jsonl`) |
| `prompts/structured/overrides.jsonl` | high-signal override exemplars (baseline +5 boost) |

## Ranking

For each candidate record, build relevance text from `retrieval_text + subcategory + decision_made + decision_rationale + entities.{features,libs,files,agents}`. Tokenize question (>3 chars). Score = matched-token-count * `project_weight`. Override pool gets baseline 5.0 + score boost.

Pick top `KOverrides` (default 3) overrides, top `K - KOverrides` topical (default 3).

## Output (markdown)

```
# Twin context for question:
> <question>

## Operator persona (load verbatim)
<persona.md>

## Operator-authored principles (verbatim, non-negotiable)
- principle 1
- principle 2

## Override exemplars (highest signal: pool=N)
- **<project> | <ts> | axis: <axis> | score=X.X**
  Agent proposed: ...
  Operator decided: ...
  Rationale: ...
  Context: ...

## Topical exemplars (keyword-relevance scored; pool=N)
- **<project> | <category>/<subcategory> | scope=... ev=N risk=N | score=X.X**
  <retrieval_text>

## Twin instructions
<answer-format spec for twin agent>
```

## Output (JSON)

```jsonc
{
  "question": "...",
  "persona_loaded": true,
  "persona": "...",
  "principles": "...",
  "exemplars": [
    { "kind": "override", "project": "...", "score": 7.4, ... },
    { "kind": "topical",  "project": "...", "score": 2.1, ... }
  ],
  "stats": { "structured_pool": N, "overrides_pool": N, "topical_returned": N, "override_returned": N }
}
```

## Twin answer contract

Twin replies in:
- **Twin take:** one-sentence position
- **Why this position:** 2-4 bullets citing principle/exemplar/persona axis
- **Risk in this call:** what could go wrong
- **Confidence:** low | medium | high
- Sign with: `- twin (low-confidence persona, partial profile)` if persona thin

## Common Issues

- **No persona**: emits "NOT YET BUILT - run /hae:profile" notice; twin downgrades to low-confidence.
- **Empty override pool**: prints `(no override deltas captured yet)` -> twin leans more on persona + topical.
- **All scores = 0**: question has no keywords > 3 chars matching exemplars; twin still loads persona + overrides (baseline boost).
