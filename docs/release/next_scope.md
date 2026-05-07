# Next Release Scope - v0.6.0 (forward look)

**Theme:** Marketplace install ship + personal Anthropic-change detector + cost visibility + cross-platform + twin intelligence depth. Builds on v0.5.0 wave 1+2 (twin gates wired, docs tightened, auto-promote wired, two RA research files landed).

## Candidate items (re-sorted post-research)

| ID | Title | RICE | Owner | Status |
|----|-------|------|-------|--------|
| H1 | Marketplace UI install (`plugins/hae/` subdir + `marketplace.json` + plugin.json hooks declaration) | 28.8 | SA+OB | **Top** - deferred from v0.5.0 by operator default; H17 research complete; 2-4 hour task |
| H19 | Override-rate drift signal in `/hae:status`: 4-week sparkline as personal Anthropic-change detector | 26.7 | OB | New from H14 forum research; near-free implementation; serves operator's evidence-dominant decision style |
| H18 | `/hae:cost` skill: token spend tracker w/ additive schema (tokens_in, tokens_out, model) | 14.4 | OB+SA | New from H14; non-breaking schema additive; uses existing capture infrastructure |
| H12 | v1.0.0 public OSS release | 7.2 | PM+SA | RICE up 3.2x post-H17; unblocked when H1 ships |
| H8 code | report.ps1 formatter (post-mockup) | 5.6 | UI | Mockup approved -> implement TOC + section anchors + chunk |
| H20 | Repetition-candidate classifier (prompts typed 10+ times) | 5.6 | OB | New from H14; classify-phase extension; no new infrastructure |
| H16 | Cross-platform install (macOS + Linux paths, shell, hooks) | 5.0 | RA -> SA+OB | YELLOW research; effort revised to 4w post-H17 |
| H13 | Capture hook perf: persistent PS host (470ms -> <100ms cold) | 4.0 | RA -> OB | RED research; needs feasibility spike |
| H10 | Twin few-shot retrieval: semantic over keyword overlap | 3.2 | RA -> SA+OB | YELLOW research; H14 confirms keyword retrieval is industry-recognized failure mode (Mem0 report) |
| H21 | PostToolUse hook capture + `/hae:trace` skill | 3.0 | OB+SA | New from H14; new hook binding; differentiated capability |
| H15 | Codex CLI integration | 2.56 | RA -> OB | GREEN research; depends on Codex hook contract |

## Pre-conditions

- v0.5.0 H8 mockup approval (operator review of `docs/research/report_formatter_mockup_2026-05-07.md`) before H8 code starts
- H1 must ship before H12 can be scoped
- H13, H10 research files needed before they can move to scope
- H18 + H21 require schema additive (`tokens_in`, `tokens_out`, `model` for H18; tool-call event fields for H21) - bump schema `$id` if breaking; document migration

## Suggested v0.6.0 scope (top 5 by RICE)

1. **H1** marketplace install (28.8) - 0.5w
2. **H19** override-rate drift signal (26.7) - 0.3w (likely fastest impact-per-effort item in the entire backlog)
3. **H18** `/hae:cost` skill (14.4) - 0.5w
4. **H12** v1.0 OSS release (7.2) - 2.5w
5. **H8 code** report.ps1 formatter (5.6) - 0.4w

**Total estimated effort:** ~4.2w. Re-rank via `/release-plan` when v0.5.0 closes.

## Likely scope cuts if effort overruns

- H12 OSS (largest E=2.5w; can defer to v0.7.0 if H1 reveals additional work)
- H8 code (mockup may surface scope expansion the operator wants in v0.7.0)

## Forward signals to watch

- H1 ships -> immediate path to OSS publish (H12) and external user signals
- Operator override rate trending up post-deploy of any new feature -> H10 priority increases
- Capture hook timing showing >1s tail under sustained load -> promote H13 to v0.6.0 patch
- H19 surfaces undocumented model change -> validates the personal-Anthropic-change-detector value prop, drives H12 messaging
