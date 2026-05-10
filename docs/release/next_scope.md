# Next Release Scope - v0.7.0 (forward look)

**Theme:** Cross-platform reach + twin intelligence depth + capture audit trail. Picks up gated v0.6.0 items if they trip + remaining H14 forum-research candidates + research-unblocked items.

## Candidate items

| ID | Title | RICE | Owner | Status |
|----|-------|------|-------|--------|
| (carry) H12 | v1.0.0 public OSS release | 7.2 | PM+SA | Carried from v0.6.0 if Gate 1 trips |
| (carry) H8 code | report.ps1 formatter (post-mockup) | 5.6 | UI | Carried from v0.6.0 if Gate 2 trips; mockup must approve before scope-in |
| H20 | Repetition-candidate classifier (prompts typed 10+ times) | 5.6 | OB | Classify-phase extension; no new infrastructure |
| H16 | Cross-platform install (macOS + Linux paths, shell, hooks) | 5.0 | RA -> SA+OB | YELLOW research needed before scope; 4.0w effort |
| H13 | Capture hook perf: persistent PS host (470ms -> <100ms cold) | 4.0 | RA -> OB | RED research first |
| H10 | Twin few-shot retrieval: semantic over keyword overlap | 3.2 | RA -> SA+OB | YELLOW research; H14 confirms keyword retrieval is industry-recognized failure mode |
| H21 | PostToolUse hook capture + `/hae:trace <session-id>` skill | 3.0 | OB+SA | Schema additive; new hook binding |
| H15 | Codex CLI integration | 2.56 | RA -> OB | GREEN research; depends on Codex hook contract |

## Pre-conditions

- v0.6.0 close determines carry-overs (H12 + H8 code)
- H13 RED research must complete before scope lock
- H16 + H10 YELLOW research recommended before scope lock
- H18 schema changes (from v0.6.0) determine whether H21's tool-call event fields can also be additive or require breaking bump

## Suggested v0.7.0 scope (assuming both v0.6.0 gates clear)

If H12 + H8 code ship in v0.6.0:
1. **H20** repetition classifier (5.6) - 0.5w
2. **H21** PostToolUse capture (3.0) - 2.0w
3. **H13** hook perf (post-research) - 2.0w
4. **H16** cross-platform (post-research) - 4.0w (or split: research + initial bash port)

Total: ~8.5w. Aggressive cycle; likely needs trimming based on research outcomes.

## Suggested v0.7.0 scope (if v0.6.0 gates trip)

If H12 + H8 code carry over:
1. **H12** v1.0 OSS (carry, 2.5w)
2. **H8 code** report formatter (carry, 0.4w)
3. **H20** repetition classifier (5.6, 0.5w)
4. **H13** hook perf (post-research, 2.0w if go)

Total: ~5.4w. More realistic.

## Forward signals to watch

- H1 ships clean -> H12 keeps schedule, OSS Q3 trajectory holds
- H19 surfaces undocumented model change -> validates personal-Anthropic-change-detector value prop, drives H12 messaging
- H18 schema additive merges cleanly -> H21 schema work follows same pattern
- H1 reveals plugin.json edge cases -> trigger H7 (install_plugin.ps1 refactor, RICE 1.6) promotion to scope
