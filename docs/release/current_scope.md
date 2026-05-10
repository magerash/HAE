# Current Release Scope - v0.7.0

twin_preflight: push-back-trim (H21 dropped from v0.7.0; H10 RA spawn added) | 2026-05-10 | confidence: medium-high

**Theme:** Forum-driven user-pain follow-through + OSS publish completion + report formatter ship. v0.6.0+v0.6.1 closed: marketplace install live, drift signal validated (+2400% evidence-axis), cost tracker shipped, MIT licensed. v0.7.0 capitalizes on those rails by addressing remaining H14 forum themes (data portability E, repetition C/D) and finishing H12 OSS publish post-MIT.

**Target ship:** ~2-3 weeks at single-operator pace. Effort 2.2w max (after twin trim of H21).

## Items

| ID | Title | RICE | Owner | Effort | Status |
|----|-------|------|-------|--------|--------|
| H22 | `/hae:export` skill: CSV + markdown summary by project for portability + anti-lock-in OSS positioning | 17.5 | OB | 0.3w | NEW from H14 forum theme E (data portability); read raw + structured, emit operator-controlled summary; reuses _metrics_lib.ps1 helpers |
| H12 | v1.0.0 public OSS release completion (post-MIT) | 7.0 | PM+SA | 1.0w | Effort revised down from 2.5w post-v0.6.0+v0.6.1 (LICENSE + marketplace.json + plugin.json declarations done); remaining: CONTRIBUTING.md, marketplace listing submission via clau.de/plugin-directory-submission, README polish for external audience |
| H8 code | report.ps1 formatter implementation (post-mockup) | 5.6 | UI | 0.4w | **GATED:** mockup at `docs/research/report_formatter_mockup_2026-05-07.md` still PROPOSED status; operator must mark APPROVED before code; gate deadline mid-cycle 2026-05-17 (carry from v0.6.0 gate) |
| H20 | Repetition-candidate classifier (prompts typed 10+ times) | 5.6 | OB | 0.5w | New from H14 forum theme C/D; classify-phase extension; surface in `/hae:status` as "prompts you keep typing - consider promoting to CLAUDE.md/hook" |

**Total effort:** ~2.2w (well under 3-4w single-op budget; leaves slack for operator-side decisions on H8 + H12 polish iterations).

## Twin pre-flight (full block)

**Twin take:** Approve scope w/ trim: H21 PostToolUse capture removed from v0.7.0 (deferred to v0.8.0), H10 RA spawn added in parallel to unblock v0.8.0.

**Why:**
- **H22 is the surprise top RICE.** Forum theme E (data portability) + operator's "find insides in forum like reddit" principle + override exemplar (My habits 2026-05-05, score 18) where operator added forum pain research as PM task. Direct alignment. Plus: ships anti-lock-in messaging for H12 OSS at near-zero effort.
- **H12 effort revised dramatically.** Original 2.5w included LICENSE + marketplace + plugin.json work that v0.6.0+v0.6.1 already delivered. Remaining ~1.0w (CONTRIBUTING + submission + README polish). Operator's override exemplar (habits 2026-05-04, score 11) explicitly chose "open-source friendly" path - aligned.
- **H21 trim recommended.** RICE 3.0 vs ~1.5w effort is low-ROI in this cycle. H21 needs new hook binding + schema additive design - risk of integration complications. Producer-bias + "pair scope expansion with evidence" both argue for trimming low-RICE high-effort items in favor of higher-RICE wins (H22). Defer H21 to v0.8.0 where it can batch with H10 semantic retrieval schema work.
- **H10 RA spawn in parallel.** H10 RICE bumped from 3.2 to 5.0 per H14 finding (Mem0 industry-confirms keyword retrieval is wrong approach at scale). Spawn RA on H10 research now so v0.8.0 has actionable spec; doesn't cost operator's time.
- **H8 gate carries forward.** Mockup written 2026-05-07; status block still PROPOSED as of 2026-05-10. Operator's "mockups are necessary, always update them with statuses" principle is non-negotiable. Operator decision on mockup approval is the cycle's biggest non-code blocker.

**Risk if approved as-is (with trim):** v0.7.0 ships H22 + H12 + H8 + H20 in 2.2w; H21 deferred. If H8 mockup never gets approved, scope drops to 1.8w. If H12 polish reveals scope expansion (CONTRIBUTING needs deeper than expected, README polish triggers redesign), cycle could slip but unlikely given v0.6.0+v0.6.1 derisked it.

**Risk if H21 kept (rejected trim):** 3.7w cycle is at upper edge of single-op budget; H21 schema additive could collide with H10 semantic retrieval schema (when that lands v0.8.0+) creating rework. Trim is the safe + value-maximizing call.

**Confidence:** medium-high (full profile v0.3 + 3 strong override exemplar matches + forum research direct alignment + cost data starting to flow validates evidence loop)

Sign: `- twin (medium-high confidence persona, full profile v0.3)`

## Gates

### Gate 1: H8 code mockup gate (carry from v0.6.0)
- **Trip condition:** mockup at `docs/research/report_formatter_mockup_2026-05-07.md` status block not marked APPROVED or APPROVED WITH CHANGES by 2026-05-17.
- **Action on trip:** drop H8 code from v0.7.0; carry mockup forward to v0.8.0; reuse 0.4w on H21 partial start.

### Gate 2: H12 effort gate
- **Trip condition:** H12 polish work exceeds 1.5w (1.5x estimate).
- **Action on trip:** ship CONTRIBUTING + LICENSE + marketplace submission; defer README polish to v0.8.0 patch release.

## Out of scope (deferred)

- **H21** PostToolUse capture - twin-trimmed; reserve for v0.8.0 batch with H10 schema work.
- **H10** twin semantic retrieval - YELLOW research; RA spawning in parallel (this cycle); scope-in for v0.8.0.
- **H16** cross-platform - YELLOW research; 4w effort blocks v0.7.0 single-op cycle.
- **H13** hook perf - RED research; spawn RA in parallel to unblock v0.8.0+.
- **H15** Codex CLI - GREEN research; depends on Codex hook contract availability.
- **H11** Phase 6 dashboard - GREEN research.

## Dependencies

- H8 mockup approval (2026-05-17 deadline) gates H8 code.
- H12 unblocked by v0.6.0+v0.6.1 (LICENSE + marketplace.json shipped).
- H22 + H20 independent; can ship in parallel.
- H10 + H13 RA spawns parallel to v0.7.0 dev; outputs feed v0.8.0 scope.

## Test plan handoff (post-CB, post-reinstall)

QA verifies per shipped item:

1. **H22 export** - `/hae:export` emits CSV + markdown for last 4 weeks of operator data; verify project + record + token columns; verify markdown renders in VS Code + GitHub; verify no PII leaks (apply same redact patterns as raw capture).
2. **H12 OSS publish** - LICENSE + CONTRIBUTING.md + README polish present; marketplace listing submitted via clau.de/plugin-directory-submission (operator action); fresh-machine install via UI works; tag `v1.0.0` matches plugin.json after final ship.
3. **H8 code** (if Gate 1 cleared) - run `report.ps1`; verify TOC + section anchors + takeaway blockquotes + trend lines render in VS Code, Obsidian, GitHub markdown viewer; new chunk file `docs/chunks/features/report.md` exists per chunk format contract.
4. **H20 repetition** - run `/hae:classify-bulk` over operator's pool; verify "repetition_candidates" output identifies 5+ phrases typed 10+ times; verify `/hae:status` shows them as "prompts you keep typing - candidates for CLAUDE.md/hook promotion".
5. **H10 + H13 research** - operator reads research files when RA agents complete; applies findings to v0.8.0 scope.

## Mid-cycle review

**2026-05-17 (mid-cycle, gate-check date):**
- Evaluate H8 mockup status. If APPROVED: H8 code proceeds. If not: drop, carry to v0.8.0.
- Evaluate H22 + H12 progress. If H12 polish reveals scope expansion, trim README polish.
- Check H10 + H13 RA outputs (should land within first week of cycle).

## Closed v0.6.0 + v0.6.1 (2026-05-10)

- H1 marketplace UI install (28.8) ✓
- H19 override-rate drift signal (26.7) ✓
- H17 plugin distribution research (20.0) ✓
- H18 cost skill (14.4) ✓
- H14 forum user-pain research (4.0) ✓
- H6 CLAUDE.md tighten (7.0) ✓
- H9 auto-promote homes (4.2) ✓
- H3 twin gates expansion (24.0) ✓
- v0.6.1: MIT license added
