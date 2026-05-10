# Next Release Scope - v0.8.0 (forward look)

**Theme:** Twin intelligence depth (semantic retrieval) + capture audit trail + cross-platform reach. Builds on v0.7.0 OSS publish + portability messaging.

## Candidate items

| ID | Title | RICE | Owner | Status |
|----|-------|------|-------|--------|
| (carry) H8 code | report.ps1 formatter | 5.6 | UI | Carries from v0.7.0 if Gate 1 trips (mockup not approved) |
| H10 | Twin few-shot retrieval: semantic over keyword overlap | 5.0 | RA -> SA+OB | YELLOW research; bumped to 5.0 from 3.2 per H14 + Mem0 industry-confirm; RA spawning during v0.7.0 |
| H21 | PostToolUse hook capture + `/hae:trace <session-id>` skill | 3.0 | OB+SA | Twin-deferred from v0.7.0; batch with H10 schema work; reuse H18 StopTokens slim-record pattern (effort revised from 2.0w to 1.5w) |
| H13 | Capture hook perf: persistent PS host (470ms cold -> <100ms) | 4.0 | RA -> OB | RED research; RA spawning during v0.7.0 |
| H16 | Cross-platform install (macOS + Linux paths, shell, hooks) | 5.0 | RA -> SA+OB | YELLOW research; 4.0w effort; needs port plan |
| H15 | Codex CLI integration | 2.56 | RA -> OB | GREEN research; depends on Codex hook contract availability |
| H11 | Phase 6 cross-project intelligence dashboard | 1.0 | RA | GREEN research |
| H7 | install_plugin.ps1 refactor (marketplace/copy/registry split) | 1.6 | OB | Idea; 296 lines could split into 3 concerns |

## Pre-conditions

- v0.7.0 close determines carry-overs (H8 code if Gate 1 trips)
- H10 + H13 RA outputs needed before scope lock
- H21 + H10 schema work coordinated (additive, non-breaking, schema $id bump only if shape changes)

## Suggested v0.8.0 scope (assuming H10 + H13 research land)

1. **H10** semantic retrieval (5.0) - 2.0w (post-research effort confirmed)
2. **H21** PostToolUse capture w/ H18 pattern reuse (3.0) - 1.5w
3. **H13** persistent PS host if research positive (4.0) - 2.0w

Total: ~5.5w. Aggressive cycle; trim based on research outcomes.

## Likely scope cuts if effort overruns

- H13 (riskiest; deferred to v0.9.0 if persistent host feasibility marginal)
- H16 (largest effort; defer to v0.9.0 OSS-driven if external operators request macOS support)

## Forward signals to watch

- H22 export usage post-v0.7.0 -> validates portability value prop, drives H12 messaging refinement
- H12 OSS publish lands -> external user feedback may reshape v0.8.0+ priorities
- H10 RA findings (mid-v0.7.0) -> if Mem0-style approach feasible, scope-in for v0.8.0
- Cost data accumulation (4 weeks post-v0.6.0) -> may surface high-cost projects, drives H10/H21 prioritization
- Override-rate drift continues at +294%/+2400% trend -> reinforces value of HAE as personal-Anthropic-change-detector for H12 marketing
