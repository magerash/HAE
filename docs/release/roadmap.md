# HAE Roadmap

Long-term direction for the HAE plugin. Updated each /release-plan cycle.

## Quarterly goals

### Q2 2026 (current)

- **Shipped:** v0.5.0 (2026-05-07) - twin gates wired (H3), CLAUDE.md tightened (H6), auto-promote homes (H9), report.ps1 mockup (H8 phase 1), forum user-pain + plugin distribution research (H14, H17).
- **Active:** v0.6.0 (locked 2026-05-10) - H1 marketplace UI install (28.8, top), H19 override-rate drift signal (26.7), H18 /hae:cost skill (14.4), H12 v1.0 OSS release (7.2, gated on H1 <=0.5w), H8 code (5.6, gated on mockup approval). Total 4.2w max, 3.0w if both gates trip.
- **Mid-cycle review:** 2026-05-17 - evaluate gate states.
- **Next:** v0.7.0 - candidates pending v0.6.0 close: carry-overs (H12, H8 code) if gated, plus H20 repetition classifier, H21 PostToolUse capture, H13 hook perf research, H16 cross-platform research.

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
