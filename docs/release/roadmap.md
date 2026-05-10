# HAE Roadmap

Long-term direction for the HAE plugin. Updated each /release-plan cycle.

## Quarterly goals

### Q2 2026 (current)

- **Shipped:** v0.5.0 (2026-05-07) - twin gates wired (H3), CLAUDE.md tightened (H6), auto-promote homes (H9), report.ps1 mockup (H8 phase 1), forum user-pain + plugin distribution research (H14, H17).
- **Shipped:** v0.6.0 + v0.6.1 (2026-05-10) - H1 marketplace UI install + H19 override-rate drift + H18 cost skill + MIT license. Validated +294% overall drift / +2400% evidence-axis from H19 sparkline. Cost tracker baseline established. Marketplace UI install live for `/plugin marketplace add Magerash/HAE`.
- **Active:** v0.7.0 (locked 2026-05-10 evening) - H22 /hae:export skill (17.5, NEW from H14 theme E), H12 v1.0 OSS publish completion (7.0, post-MIT), H8 code formatter (5.6, gated on mockup approval), H20 repetition classifier (5.6). Total 2.2w. H21 twin-trimmed (deferred to v0.8.0). H10 + H13 RA spawning in parallel.
- **Mid-cycle review:** 2026-05-17 - H8 mockup gate check, H10/H13 RA outputs.
- **Next:** v0.8.0 - twin intelligence depth: H10 semantic retrieval (5.0, post-research), H21 PostToolUse capture w/ H18 pattern reuse (4.0, batched), H13 hook perf (4.0, post-research).

### Q3 2026 (planned)

- v1.0.0 public OSS release (assumes H1 marketplace + H12 OSS prep ship in Q2)
- Cross-platform install: macOS + Linux (H16) — unblocks non-Windows operators
- Codex CLI integration (H15) if Codex hook contract available
- Phase 6 entry: cross-project intelligence layer (H11, dashboards)
- External user feedback loop established

### Q4 2026 (forward look)

- Phase 6 maturity: trend detection + drift alerts
- Twin embedding stack (H10 productionized)
- Multi-operator considerations if external users emerge

## Phases vs releases

| Phase | Releases | Status |
|-------|----------|--------|
| 0-1 | v0.1.0 | done |
| 2 | v0.3.0 | done |
| 3-4 | v0.2.0 | done |
| 5 | v0.4.0, v0.4.1 | done |
| 5.5 (consolidation) | v0.5.0, v0.6.0 | active / next |
| 6 (cross-project intelligence) | v0.7.0+ | research |
| 1.0 OSS milestone | v1.0.0 | planned Q3 |

## Risks tracked

- **R1:** Marketplace UI install gap (H1) blocks public adoption. RICE=28.8 post-H17; top of v0.6.0 scope.
- **R2:** Capture hot-path latency (470ms cold) may bite if Windows file I/O degrades. Research H13 RED priority.
- **R3:** Single operator = thin signal; profile may overfit. Mitigation: keep behavioral calibration (`scripts/report.ps1`) trustworthy.
- **R4:** Twin few-shot retrieval is keyword-based; may miss thematically relevant exemplars. Research H10 YELLOW priority.
- **R5:** Windows-only install blocks macOS/Linux operators (zero reach there today). Research H16 YELLOW; impacts OSS release H12.
- **R6:** HAE plugin layout may diverge from Claude Code marketplace conventions. Research H17 RED before H1 marketplace restructure to avoid rework.

## Out-of-scope (intentionally deferred)

- Mobile capture (no Claude Code mobile)
- Multi-user data sharing (privacy model assumes single operator)
- Cloud sync (privacy-first design; data stays local)
- Real-time streaming UI (current statusline + dashboard sufficient)
