# Current Release Scope - v0.6.0

twin_preflight: approve+gate (H12 gated on H1<=0.5w, H8 code gated on mockup approval) | 2026-05-10 | confidence: medium-high

**Theme:** Marketplace install ship + personal Anthropic-change detector + cost visibility + (conditional) v1.0 OSS publish + (conditional) report.ps1 formatter. Builds on v0.5.0 wave 1+2 shipped 2026-05-07.

**Target ship:** ~3-4 weeks at single-operator pace. Effort 4.2w max, 3.0w min if both gates trip.

## Items

| ID | Title | RICE | Owner | Effort | Status |
|----|-------|------|-------|--------|--------|
| H1 | Marketplace UI install (`plugins/hae/` subdir + `.claude-plugin/marketplace.json` at repo root + plugin.json hooks declaration) | 28.8 | SA+OB | 0.5w | **shipped 2026-05-10** - restructure done; install_plugin.ps1 auto-detects new layout; smoke-tested locally; marketplace UI install requires CB push to GitHub for `/plugin marketplace add Magerash/HAE` to resolve |
| H19 | Override-rate drift signal in `/hae:status`: trailing 4-week sparkline as personal Anthropic-change detector | 26.7 | OB | 0.3w | **shipped 2026-05-10** - new `_metrics_lib.ps1` with `Get-OverrideRateDrift` + `Format-Sparkline`; status.ps1 displays overall + per-axis sparklines + delta + alert tag. Live test: detected +294% overall drift (+2400% evidence axis) across operator's last 8 weeks - validates personal-Anthropic-change-detector value prop |
| H18 | `/hae:cost` skill: token spend tracker w/ additive schema fields | 14.4 | OB+SA | 0.5w | **shipped 2026-05-10** - H18 RA research confirmed Approach A (parse `message.usage` from transcript tail in Stop hook); schema additive 4 new + 1 nullable update (`tokens_in/out/cache_read/cache_create/model`); `cost.ps1` aggregates weekly + per-project + per-tier w/ Opus/Sonnet/Haiku 2026 pricing; new `/hae:cost` skill + `docs/chunks/features/cost.md`; `capture.include_tokens=true` default writes slim StopTokens record (privacy-preserving); smoke-test record yielded $0.22 for 1 turn (Opus, 113K tokens, math validated) |
| H12 | v1.0.0 public OSS release | 7.2 | PM+SA | 2.5w | **GATE 1 CLEARED** (H1 shipped <0.5w). Pending: LICENSE choice (MIT vs Apache 2.0), README polish, CONTRIBUTING.md, marketplace submission via clau.de/plugin-directory-submission. Awaits operator decision on LICENSE before kickoff. |
| H8 code | report.ps1 formatter implementation (post-mockup) | 5.6 | UI | 0.4w | pending - awaits mockup approval at `docs/research/report_formatter_mockup_2026-05-07.md` (deadline 2026-05-17) |

## Twin pre-flight (full block)

**Twin take:** Approve scope w/ explicit gate: H12 OSS proceeds only if H1 ships clean in <=0.5w; H8 code drops from cycle if mockup not approved by mid-cycle.

**Why:**
- H1 + H19 + H18 are clear ships - top 3 RICE, total 1.3w, all unblocked. H19 in particular serves operator's 35.5% evidence-axis override rate.
- H12 is 60% of cycle effort. Calculated-big-bets principle says regression risk acceptable IF surfaced. Surfaced: if H1 reveals additional plugin.json hooks-declaration work or marketplace.json edge cases, H12's 2.5w slips. Explicit gate preserves Producer-bias on H1+H19+H18 while protecting against scope-creep.
- H8 code has unmet pre-condition. Mockup written 2026-05-07; not approved as of 2026-05-10. Mockups-first principle is non-negotiable. Drop H8 code if mockup not approved by ~mid-cycle (2026-05-17).
- Effort budget realistic. 4.2w at single-operator pace = ~3-4 weeks. Scope-bias 5/7 + evidence threshold low (3/7) = "expand only when data backs it AND we can ship this cycle". 4.2w is at upper edge.

**Risk if approved as-is:** H12 OSS gets 60% of attention while H1 reveals layout edge cases (per H17 critical finding: hooks declaration). Operator ends up with a partial OSS push + stalled marketplace. Both ship as v0.7.0 instead of v0.6.0.

**Confidence:** medium-high (full profile v0.3, strong principle + exemplar match)

Sign: `- twin (medium-high confidence persona, full profile v0.3)`

## Gates (operator-approved)

### Gate 1: H12 effort gate (CLEARED 2026-05-10)
- **Trip condition:** H1 implementation exceeds 0.5w (effective: takes more than ~3-4 hours active work after mockup-equivalent design pass).
- **Status:** CLEARED. H1 restructure took ~30 min real time; install + capture smoke-tested.
- **Action:** H12 OSS proceeds. Awaits operator decision on LICENSE + CONTRIBUTING content before code work begins.

### Gate 2: H8 code mockup gate
- **Trip condition:** mockup at `docs/research/report_formatter_mockup_2026-05-07.md` status block not marked APPROVED or APPROVED WITH CHANGES by 2026-05-17.
- **Action on trip:** drop H8 code from v0.6.0; carry mockup forward to v0.7.0 with same gate.

## Out of scope (deferred)

- H20 repetition classifier - candidate for v0.7.0
- H21 PostToolUse capture - candidate for v0.7.0
- H16 cross-platform - YELLOW research; v0.7.0+
- H10 twin semantic retrieval - YELLOW research
- H13 hook perf - RED research
- H15 Codex CLI - GREEN research
- H11 Phase 6 dashboard - GREEN research

## Dependencies

- H1 must ship clean before H12 can proceed (Gate 1)
- H8 mockup must be approved before H8 code (Gate 2)
- H18 schema additive: bump `schema/record.schema.json` `$id` if `tokens_in`/`tokens_out`/`model` field shape changes; document migration in changelog
- All other items independent; can ship in parallel

## Test plan handoff

QA verifies per shipped item:

1. **H1** - fresh Claude Code install on second machine; run UI install path (`/plugin marketplace add Magerash/HAE` + `/plugin install hae@hae`); verify capture fires within 1s; verify `/plugin list` shows `hae@hae` enabled with 0 errors. Validate that hooks declared in plugin.json load correctly.
2. **H19** - run `/hae:status`; verify trailing 4-week sparkline renders for overall override rate + each axis (approach/evidence/scope/priority); verify delta vs prior 4-week baseline computed correctly; trigger delta-flag manually by setting baseline to known value.
3. **H18** - capture a new prompt with `/hae:cost` enabled; verify `tokens_in`, `tokens_out`, `model` fields appear in raw record; run `/hae:cost`; verify weekly spend table by project; old records without fields handled gracefully.
4. **H12** (if gate not tripped) - LICENSE present, README has install/quick-start sections, CONTRIBUTING.md present, marketplace submission filed; tag `v1.0.0` matches plugin.json version.
5. **H8 code** (if gate not tripped) - run `report.ps1`; verify TOC + section anchors + takeaway blockquotes + trend lines render in VS Code, Obsidian, GitHub markdown viewer; verify chunk file `docs/chunks/features/report.md` exists per chunk format contract.

## Mid-cycle review

**2026-05-17 (mid-cycle gate-check date):**
- Evaluate H1 status. If shipped or near-ship: H12 gate clears.
- Evaluate H8 mockup status. If APPROVED: H8 code proceeds. If not: drop.
- Re-run `/scope-review` if any gate trips.
