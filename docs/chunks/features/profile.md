# Profile

## Quick Reference

- Skill: `/hae:profile` -> `skills/profile/SKILL.md`
- Status skill: `/hae:status` -> `skills/status/SKILL.md`
- Questionnaire banks: `tests/paei.md` (30Q), `tests/hexaco_brief.md` (24Q), `tests/custom_decision.md` (8Q)
- Output dir: `<dataRoot>\profile\`
- Status script: `scripts/status.ps1`
- Report script: `scripts/report.ps1`
- Related chunks: `architecture/profile-system.md`, `features/twin.md`

## Overview

Profile collects the operator's behavioral fingerprint via three short questionnaires plus a free-form principles list, then regenerates `persona.md` as a single human-readable summary loaded verbatim by the twin.

## Files in `<dataRoot>\profile\`

| File | Purpose |
|------|---------|
| `paei.json` | Adizes role scores |
| `hexaco.json` | six personality factors |
| `custom.json` | scope/evidence/risk/urgency defaults |
| `principles.md` | non-negotiable rules (line per rule) |
| `persona.md` | regenerated summary; verbatim into twin context |

## Running `/hae:profile`

1. Walk PAEI -> HEXACO -> custom in order. Each question persisted incrementally so partial completion isn't lost.
2. Prompt for principles (free-form, ~6 rules typical).
3. Regenerate `persona.md` summarizing dominant axes + style cues + cross-refs.

Re-run is non-destructive: existing answers are shown as defaults; you can revise.

## Status dashboard (`/hae:status`)

`scripts/status.ps1` prints:
- Capture stats (raw / classified / unclassified / overrides counts; per-project breakdown for homes vs other)
- Profile completeness (PAEI / HEXACO / custom answered ratios; persona last-updated)
- Plugin install state (junction up to date, hooks registered)
- Backfill state (sessions imported, last run)
- Structured count + override count

## Behavioral report (`scripts/report.ps1`)

Computes axis trends across structured records: scope_signal distribution, evidence_demand average per category, risk_appetite over time. Used to validate that questionnaire-declared profile matches behavioral profile.

## Validation history

- v0.3.0: PAEI 30Q + HEXACO 24Q + Custom 8Q + 6 principles + persona regen; behavioral calibration validated against 1670 classified records.
- v0.2.0: V1 month-view A/B test - 18 vs 75 override exemplars; with 75, override-axis matches against new questions rose materially. Override pool size > topical pool size for twin quality.

## Common Issues

- **Persona missing**: `/hae:profile` not run yet, or persona regen step crashed. Re-run.
- **Status shows 0 classified despite raw records**: classifier never ran. `/hae:classify` once or `/hae:classify-bulk` for backlog.
- **Behavioral / declared mismatch**: report.ps1 surfaces gaps. Treat behavioral signal as ground truth and revise questionnaire answers, not vice versa.
