# Pattern: Twin Pre-Flight Gate

## Quick Reference

Reusable bash + powershell snippet that fires HAE twin before a release-manager mutation (scope cut, mid-release add, backlog add). Slash commands inline this snippet at the mutation point.

**When to fire:** before any RM-side write that mutates `docs/release/*.md`. Read-only reviews (status, list) skip the gate.

**Cost:** ~2-5s when gate is on. Zero cost when gate is off (skip without spawning twin.ps1).

## Overview

Twin gates live in `<dataRoot>/config.json` `twin.gates.*` (operator-private overrides over `${CLAUDE_PLUGIN_ROOT}/config.default.json`). Default: only `before_user_approval=true`. Operator opts in to wider coverage by toggling other gates. No restart needed - config re-read on every gate check.

| Gate | Fires on | Default | Wired in |
|------|----------|---------|----------|
| `before_locking_scope` | `/release-plan` Phase 5 lock | off | (not yet) |
| `before_user_approval` | `/release-plan` Phase 8 final approval | **on** | `release-plan.md` |
| `on_backlog_add` | `/rice-score` writes new hypothesis to `rice_backlog.md` | off | `rice-score.md` (v0.5.0) |
| `on_scope_cut` | `/scope-review` removes item from `current_scope.md` | off | `scope-review.md` (v0.5.0) |
| `on_mid_release_scope_add` | `/scope-review` adds work to in-flight release | off | `scope-review.md` (v0.5.0) |
| `on_backlog_reorder` | reorder without add/cut | off | (not yet) |

## Key Functions

`scripts/twin.ps1` is the only callable. It reads persona + principles + override exemplars + topical exemplars from `<dataRoot>/profile/` and `<dataRoot>/prompts/structured/`, returns a markdown context block to stdout. The slash command composes the twin take inline using that context, applies operator's persona axes + principles + exemplars to the question, takes a clear position.

`scripts/_lib.ps1` `Get-HaeConfig` returns the merged config (defaults + user overrides). Used by every gate check.

## Code Patterns

### Standard gate wiring (copy-paste into slash command)

```markdown
**Twin pre-flight (`<gate_name>` gate):**

1. Resolve data root: `$env:HAE_DATA_DIR` or fallback to `%USERPROFILE%\.hae`.
2. Read merged config via `${CLAUDE_PLUGIN_ROOT}/scripts/_lib.ps1` `Get-HaeConfig` helper, OR inline-check by reading `<dataRoot>/config.json`'s `twin.gates.<gate_name>` over `${CLAUDE_PLUGIN_ROOT}/config.default.json` value.
3. If gate flag is false OR `<dataRoot>/profile/persona.md` missing: skip silently, proceed with mutation.
4. If both true:
   - Compose one-line twin question summarizing the mutation (e.g. `"About to cut H4 from current_scope.md (RICE 0.48). Approve / push-back / expand?"`).
   - Run via Bash:
     ```
     powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/twin.ps1" "<question>"
     ```
   - Compose twin take inline using returned context (Twin take / Why / Risk / Confidence / sign-off format).
   - Render banner: ⚠ if push-back/expand/trim, ✓ if approve.
   - Persist to mutation target's header for audit trail (e.g. `current_scope.md` `twin_preflight: <verdict> | <date> | confidence: <level>`).
5. Apply operator decision (proceed, modify, abort).
```

### Question composition rules

- One sentence, < 200 chars.
- Lead with the mutation: `"About to <verb> <target>"`.
- End with the choice menu: `"Approve / push-back / expand / trim?"`.
- Include the RICE score or score delta when relevant - twin uses it to anchor evidence-axis judgment.

Examples:
- `"About to cut H4 (AST chunking, RICE 0.48) from v0.5.0 scope. Approve / push-back / expand / trim?"`
- `"About to add H99 (new hypothesis, RICE 5.2) to mid-flight v0.5.0 release. Approve / push-back / defer / trim?"`
- `"Adding H100 to backlog: <one-line description>, proposed RICE 8.0. Approve score / adjust / reject?"`

### Audit trail line shape

```
twin_preflight: <approve|push-back|expand|trim> | <YYYY-MM-DD> | confidence: <low|med|high>
```

Append (don't overwrite) when multiple gates fire on the same scope file across one /release-plan cycle. Use a list:

```
twin_preflight:
  - approve | 2026-05-07 | confidence: med (before_user_approval)
  - push-back | 2026-05-09 | confidence: high (on_scope_cut: H4)
```

## Common Issues

- **Gate fires but twin question lacks RICE context** - include the score in the question; twin uses score deltas to detect "scope-bias" override patterns.
- **Banner color noise** - use ⚠ and ✓ only; no other emoji per CLAUDE.md "no emoji in code or generated content" rule. (These two are the documented exception in `release-plan.md` Phase 8.)
- **Persona missing** - if `<dataRoot>/profile/persona.md` doesn't exist, gate skips silently. This is intended - operator hasn't run `/hae:profile` yet so twin has no signal.
- **Slow on cold start** - first `twin.ps1` call after Windows reboot takes ~5s (PowerShell host warmup + module load). Subsequent calls ~1-2s. Future optimization: H13 persistent PS host research.

## Related Chunks

- `docs/chunks/architecture/twin-pipeline.md` - twin context composition + few-shot retrieval
- `docs/chunks/features/twin.md` - `/hae:twin` skill usage
- `docs/chunks/patterns/data-root-resolution.md` - how `<dataRoot>` resolves
- `.claude/commands/release-plan.md` - reference implementation of `before_user_approval` gate
