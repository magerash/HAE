---
description: Review current release scope and present for approval
---

Review and present the current release scope for user approval.

## Instructions

1. **Read scope files:**
   - `docs/release/current_scope.md`
   - `docs/release/next_scope.md`
   - `docs/release/rice_backlog.md`
   - `docs/release/roadmap.md`

2. **Present summary table:**
   ```
   | Feature | RICE | Agent(s) | Effort | Status |
   |---------|------|----------|--------|--------|
   ```

3. **Highlight:**
   - Total estimated effort for current scope
   - Any items missing research or with low confidence
   - Dependencies between scoped items
   - Refactoring items (if any)

4. **Show next release preview:**
   - What's queued for the release after this one
   - Items that almost made the cut (just below the RICE threshold)

5. **Ask the user:**
   - Approve scope as-is?
   - Remove any items?
   - Add items from backlog?
   - Reprioritize?
   - Change agent assignments?

6. **Twin pre-flight gates (HAE Phase 5):** before applying user decisions in step 7, fire the matching twin gate per the pattern at `docs/chunks/patterns/twin-gate.md`. Two gates apply here:

   - **`on_scope_cut`** - fires when user requests removing one or more items from `current_scope.md`. Question template: `"About to cut <item_id> (<title>, RICE <score>) from v<version> scope. Approve / push-back / expand / trim?"`. Skip silently if gate flag false in `<dataRoot>/config.json` OR persona missing.
   - **`on_mid_release_scope_add`** - fires when user adds work to an in-flight release (current_scope already has shipped or in-progress items). Question template: `"About to add <item_id> (<title>, RICE <score>) to in-flight v<version>. Approve / push-back / defer / trim?"`.

   For each fired gate:
   - Resolve data root (`$env:HAE_DATA_DIR` or `%USERPROFILE%\.hae`).
   - Run `powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/twin.ps1" "<question>"` via Bash.
   - Compose twin take inline (Twin take / Why / Risk / Confidence / sign-off).
   - Render ⚠ banner if push-back/expand/trim, ✓ if approve.
   - Append to `current_scope.md` header `twin_preflight:` list with format `<verdict> | <YYYY-MM-DD> | confidence: <level> (<gate_name>: <item_id>)`.

   If twin pushes back, surface the take to the operator and wait for their decision (proceed anyway, apply twin conditions, or abort) before step 7.

7. **Update files** based on user decisions (and any applied twin conditions):
   - Move approved items to status `scoped` in rice_backlog.md
   - Update current_scope.md status to APPROVED
   - Update roadmap.md
