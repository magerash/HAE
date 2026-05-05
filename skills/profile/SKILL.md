---
name: profile
description: Run the HAE personality + decision-style questionnaires (PAEI 30Q + HEXACO Brief 24Q + Custom 8Q + free-form principles), score the responses, persist to .hae/profile/, and regenerate persona.md. Use when user invokes /hae:profile, asks to "set up HAE profile", "run HAE questionnaire", or "build my operator profile".
---

# /hae:profile — operator profile builder

You are running the HAE profile questionnaire. Your job is to take the user through four short instruments, score their responses, persist them, and generate a `persona.md` system-prompt block that the Phase 4 twin agent will use.

## Inputs (read these files before starting)

1. `.hae/tests/paei.md` — 30-item PAEI inventory
2. `.hae/tests/hexaco_brief.md` — 24-item HEXACO Brief
3. `.hae/tests/custom_decision.md` — 8-item custom decision-style inventory + free-form principles prompt
4. `.hae/config.json` — for any profile-related flags

## Procedure

### Phase 1 — confirm intent

Tell the user: "Profile takes ~10 minutes total: PAEI (30 items, 1–7 scale, ~5 min), HEXACO Brief (24 items, 1–5 scale, ~3 min), Custom decision-style (8 items, 1–7 anchored, ~2 min), then 3–8 free-form principles you operate by." Ask if they want to do all four now, just one, or resume an in-progress profile (check if any of `profile/paei.json`, `profile/hexaco.json`, `profile/custom.json` already exist).

### Phase 2 — administer each instrument (AskUserQuestion per item)

For each instrument the user opted into, loop per item using the `AskUserQuestion` tool. **One question fired at a time, multiple-choice UI, no batching.**

Procedure per instrument:

1. Read the test file (`tests/paei.md` for PAEI, `tests/hexaco_brief.md` for HEXACO, `tests/custom_decision.md` for Custom).
2. Parse items into an ordered list with: number, statement, scale-anchor labels.
3. Loop through items. For each:
   - Show a one-line progress hint before the call: `Item N/M (instrument)`
   - Fire `AskUserQuestion` with:
     - **header**: `Profile (PAEI 4/30)` or `Profile (HEXACO 12/24)` or `Profile (Custom 3/8)` — keep under 40 chars
     - **question**: the item statement verbatim (and for Custom, both anchors visible: `Risk tolerance — 1: ship smaller / 7: ship bigger with upside`)
     - **multiSelect**: false
     - **options** (PAEI / Custom 1-7 scale, build all 7):
       - `1` label: left anchor short text (e.g. "strongly disagree" or for Custom the 1-anchor)
       - `2` label: `2`
       - `3` label: `3`
       - `4` label: `4 — neutral`
       - `5` label: `5`
       - `6` label: `6`
       - `7` label: right anchor short text (e.g. "strongly agree" or 7-anchor)
       - Plus an `Other` slot the user can fill with `skip` to abort instrument or a literal value if they prefer typed answer.
     - **options** (HEXACO 1-5 scale): build 5 options similarly with neutral at 3.
   - Capture the chosen number (1-7 or 1-5). If user selects `Other`, parse their text:
     - `skip` / `quit` / `cancel` -> abort instrument; offer to save partial.
     - Bare integer in range -> use that.
     - Anything else -> re-fire the same question with a one-line note.
   - Persist progress incrementally (in scratch). Don't lose answers if user aborts.
4. After all items in an instrument: score per Phase 3 rules and write the JSON.

**Why per-item, not batch:** native Claude Code multiple-choice UX (matches the planning-mode question pattern). Cost: ~62 AskUserQuestion fires for full battery (30 PAEI + 24 HEXACO + 8 Custom). Acceptable for one-shot setup.

**Limitations:** AskUserQuestion is single-shot, no prev/next navigation between fired questions. User cannot change item 5's answer after seeing item 6. To allow review/edit, switch to web wizard (planned `/hae:profile -Wizard` for a future version) — not in this version.

### Phase 3 — scoring

After all items in an instrument are collected:

- **PAEI:** average per-role scores per the formulas in `tests/paei.md`. Compute Adizes 4-letter code (uppercase ≥5, lowercase 3.5–4.9, omit <3.5)
- **HEXACO:** invert reverse-keyed items, average per factor, classify high (≥3.75) / low (≤2.25)
- **Custom:** no scoring transform; persist as-is. Generate a one-sentence `summary` synthesizing the 8 ratings into an operator descriptor

Write each instrument's results to its respective `profile/*.json` file (UTF-8, no BOM, pretty-printed).

### Phase 4 — free-form principles

Principles are TEXT, not multiple-choice. Use a regular text prompt (not AskUserQuestion):

> "Write 3-8 short principles you operate by, in your own voice. One per line. Examples: 'always run codex review before shipping', 'mockups before code', 'ship dev channel before debug'."

Wait for the user's free-text response. Save verbatim to `profile/principles.md` exactly as typed (one line per principle, no editorial reformatting).

### Phase 5 — generate persona.md

Synthesize PAEI scores + HEXACO highs/lows + Custom summary + Principles into a single operator persona block, ~200–350 tokens, structured as:

```markdown
# Operator persona — auto-generated from HAE profile

**Last generated:** <ISO timestamp>

## Managerial archetype (PAEI)
<Adizes code> — <one sentence interpretation>

## Personality factors (HEXACO Brief)
- High: <factors with brief interpretation>
- Low: <factors with brief interpretation>

## Decision-style snapshot
<the custom-summary sentence>

| Axis | Score | Implication |
|------|-------|-------------|
| Risk tolerance | N/7 | ... |
| Scope bias (trim ↔ expand) | N/7 | ... |
| Evidence threshold | N/7 | ... |
| Abstraction tolerance | N/7 | ... |
| Refactor appetite | N/7 | ... |
| Review strictness | N/7 | ... |
| Research depth | N/7 | ... |
| Parallelism comfort | N/7 | ... |

## Operator-authored principles

<verbatim from principles.md>
```

Save to `profile/persona.md`.

### Phase 6 — confirm + offer next step

Tell user: "Profile done. Files written: <list>. Run `/hae:twin` to invoke an agent that emulates you, or `/hae:status` to see capture stats."

## Don't

- Don't reveal item answer keys before scoring (no "this item probes Conscientiousness, reverse-keyed")
- Don't editorialize on the user's answers ("interesting choice" — skip it)
- Don't auto-share or commit `profile/*.json` — they're gitignored on purpose
- Don't proceed past Phase 1 without explicit user confirmation per instrument
- Don't use AskUserQuestion for Phase 4 (principles are free-text, not multiple-choice)
- Don't combine multiple items into one AskUserQuestion call — one item per fire so progress is visible
- Don't re-fire the same item if the user already answered it; treat the captured number as final unless user explicitly says "change item N"
