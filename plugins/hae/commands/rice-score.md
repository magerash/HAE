---
description: RICE-score a hypothesis and add it to the backlog
---

Score the given hypothesis using the RICE framework.

## Instructions

1. **Read context:**
   - Read `docs/release/rice_backlog.md` for existing scores and format
   - Read related chunks from `docs/chunks/features/` if applicable
   - Search `docs/analysis/` for prior research on this topic

2. **Score each component with evidence:**
   - **Reach (1-10):** How many users affected? Broad appeal or niche?
   - **Impact (0.25/0.5/1/2/3):** How much value per user? (3=massive, 2=high, 1=medium, 0.5=low, 0.25=minimal)
   - **Confidence (0.5/0.8/1.0):** How sure are we? (1.0=high evidence, 0.8=some evidence, 0.5=speculation)
   - **Effort (1-10):** Person-sessions to implement? Break down if > 5.

3. **Calculate:** `RICE = (Reach x Impact x Confidence) / Effort`

4. **Twin pre-flight (`on_backlog_add` gate, HAE Phase 5):** before writing the new row, fire the gate per the pattern at `docs/chunks/patterns/twin-gate.md`.

   - Resolve data root (`$env:HAE_DATA_DIR` or `%USERPROFILE%\.hae`).
   - Read merged config; check `twin.gates.on_backlog_add`. If false OR `<dataRoot>/profile/persona.md` missing, skip silently.
   - If both true, compose question: `"Adding H<id> to backlog: <one-line description>, proposed RICE <score> (R=<r> I=<i> C=<c> E=<e>). Approve score / adjust / reject?"`.
   - Run `powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/twin.ps1" "<question>"` via Bash.
   - Compose twin take inline (Twin take / Why / Risk / Confidence / sign-off).
   - Render ⚠ banner if push-back/adjust/reject, ✓ if approve.
   - If twin pushes back, surface the take to the operator and wait for their decision before step 5.

5. **Add to backlog:**
   - Insert into `docs/release/rice_backlog.md` in sorted position (by RICE score descending)
   - Set status to `idea` (or `researched` if evidence is strong)
   - Note the source (user-request, PM-roadmap, tech-debt, etc.)
   - If twin gate fired, append to backlog row notes: `twin: <verdict> <YYYY-MM-DD>`

6. **Present the score** with a brief table showing each component and reasoning. Include twin verdict if gate fired.

The hypothesis to score: $ARGUMENTS
