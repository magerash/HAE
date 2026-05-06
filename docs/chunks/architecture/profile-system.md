# Profile System

## Quick Reference

- Skill: `/hae:profile` -> `skills/profile/SKILL.md`
- Questionnaires: `tests/paei.md`, `tests/hexaco_brief.md`, `tests/custom_decision.md`
- Output: `<dataRoot>\profile\` (paei.json, hexaco.json, custom.json, principles.md, persona.md)
- Status check: `scripts/status.ps1` (used by `/hae:status`)
- Related chunks: `features/profile.md`, `architecture/twin-pipeline.md`

## Overview

The profile is the operator's behavioral fingerprint, used as the system prompt seed for the twin agent. Three questionnaires + free-form principles, persisted as JSON + Markdown, regenerated into a single persona document.

## Components

| File | Source | Contents |
|------|--------|----------|
| `paei.json` | PAEI 30Q questionnaire | Adizes role scores (Producer/Administrator/Entrepreneur/Integrator) |
| `hexaco.json` | HEXACO Brief 24Q | six personality factors |
| `custom.json` | Custom decision-style 8Q | scope_signal bias, evidence_demand, risk_appetite, urgency floor |
| `principles.md` | free-form (~6 principles) | non-negotiable rules; loaded verbatim into twin context |
| `persona.md` | regenerated from above | human-readable persona block; loaded verbatim into twin context |

## Flow

1. Operator runs `/hae:profile`.
2. Skill walks PAEI -> HEXACO -> custom in turn, persisting per-question answers.
3. After all three, prompt for principles (free-form list).
4. Skill regenerates `persona.md` summarizing: top PAEI roles, dominant HEXACO axes, custom-axis defaults, key principles.
5. `/hae:twin` and `release-plan` Path A reload persona + principles on each invocation (no caching).

## Persona content

Persona is a short Markdown document (typically <100 lines) covering:
- Operator name (from system context) + last-updated date
- Decision-style summary: scope bias, evidence demand, risk appetite, urgency floor
- PAEI dominant pair (e.g. "PaEi" - producer + entrepreneur leaning)
- HEXACO standout factors
- Communication style cues (terseness, push-back appetite)
- Cross-references to `principles.md`

## Validation

V1 month-view A/B test (v0.2.0): twin invocation with 18 vs 75 override exemplars. With 75, override-axis matches against new questions rose materially -> override pool size matters more than topical pool size for twin quality.

## Common Issues

- **Persona stale after questionnaire re-run**: skill must regenerate `persona.md` on each run; if it didn't, run `/hae:profile` again to force regen.
- **Twin says "NOT YET BUILT"**: persona file missing or empty. Run `/hae:profile`.
- **Principles ignored by twin**: twin prompt expects `principles.md` line-per-rule; ensure file is line-separated (not paragraph blob).
