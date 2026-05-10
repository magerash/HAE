---
description: Run the full release planning cycle — analyze codebase, update statuses, review RICE backlog, scope releases, present for approval
---

You are the Release Manager running the **full release planning cycle**. Execute all 8 phases:

## Instructions

1. **Read current state:**
   - `docs/release/rice_backlog.md`
   - `docs/release/roadmap.md`
   - `docs/release/current_scope.md`
   - `docs/release/next_scope.md`
   - `docs/release/research_queue.md`
   - `CLAUDE.md` (current version + recent changelog)

2. **Analyze codebase health:**
   - Scan for file size violations (ViewModel>200, UseCase>100, Repository>150, Screen>300)
   - Count TODO/FIXME/HACK comments
   - Check for missing feature chunks in `docs/chunks/features/`
   - Summarize findings

3. **Update plan statuses:**
   - Find all `*plan*.md` and `*research*.md` in `docs/research/`
   - Cross-reference with CLAUDE.md changelog to mark completed items
   - Update stale statuses

4. **Review RICE backlog:**
   - Re-sort by RICE score descending
   - Flag items needing research (status=`idea`, no research file)
   - Add any new ideas from codebase analysis (tech debt items)

5. **Update research queue:**
   - Unresearched ideas → `research_queue.md`
   - Set priorities (RED/YELLOW/GREEN)

6. **Scope current + next release:**
   - Top 3-5 RICE items → `current_scope.md`
   - Next 2-3 items → `next_scope.md`
   - If backlog empty → scope refactoring from health findings
   - Assign agents (SA/BO/UI/QA/PM) to each item

7. **Update roadmap:**
   - Update `docs/release/roadmap.md` with scope summaries
   - Update quarterly goals

8. **Twin pre-flight (operator surrogate via HAE Phase 5):**
   - Twin gate config and persona live in the HAE data dir (default `%USERPROFILE%\.hae\`, override via `$env:HAE_DATA_DIR`).
   - Check: does `<dataRoot>\config.json` `twin.gates.before_user_approval` resolve to true (merged over `${CLAUDE_PLUGIN_ROOT}\config.default.json`)? Does `<dataRoot>\profile\persona.md` exist?
   - If either false: skip silently.
   - If both true:
     a. **Compose twin question:** one-line summary of what's being approved (e.g. `"Operator about to approve v0.94 release scope: V2 splits, R45 ReminderRepository, R77 CloudBackup, R76 SettingsViewModel — approve / push-back / expand / trim?"`).
     b. **Run twin context script via Bash:**
        ```powershell
        powershell -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/scripts/twin.ps1" "<question>"
        ```
        Returns markdown block: persona + principles + override exemplars + topical exemplars.
     c. **Compose twin take inline** using returned context. Apply operator's persona axes + principles + exemplars to the scope question. Take a clear position. Render in standard format (Twin take / Why / Risk / Confidence / sign-off).
     d. Use ⚠ banner if push-back/expand/trim, ✓ if approve.

9. **Present for approval:**
   - **Twin pre-flight banner** (if twin fired): show twin block ABOVE scope table. Visual cue: ⚠ banner if push-back/expand/trim, ✓ banner if approve.
   - Show scope summary table
   - Show research needs
   - Show health highlights
   - **Ask user to approve, reject items, or reprioritize**
   - Persist twin take into `docs/release/current_scope.md` header as `twin_preflight: <take> | <YYYY-MM-DD> | confidence: <low|med|high>` for audit trail.

If `rice_backlog.md` is empty, start by collecting ideas from CLAUDE.md changelog patterns, codebase health findings, and `docs/research/` research files.
