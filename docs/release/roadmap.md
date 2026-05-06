# HAE Roadmap

Long-term direction for the HAE plugin. Updated each /release-plan cycle.

## Quarterly goals

### Q2 2026 (current)

- **Done:** Phase 5 (release-manager loop integration + standalone repo + global cross-project install + Path A twin)
- **Active:** v0.5.0 - twin signal density + install reach + forum user-pain intake (H3, H1, H6, H8, H9, H14)
- **Next:** v0.6.0 - twin intelligence depth + hot-path perf + user-pain-driven items from H14 (H13, H10, H12 + TBD from H14)

### Q3 2026 (planned)

- v1.0.0 public OSS release (assumes H1 marketplace + H12 OSS prep ship in Q2)
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

- **R1:** Marketplace UI install gap (H1) blocks public adoption. RICE=11.2; in current scope.
- **R2:** Capture hot-path latency (470ms cold) may bite if Windows file I/O degrades. Research H13 RED priority.
- **R3:** Single operator = thin signal; profile may overfit. Mitigation: keep behavioral calibration (`scripts/report.ps1`) trustworthy.
- **R4:** Twin few-shot retrieval is keyword-based; may miss thematically relevant exemplars. Research H10 YELLOW priority.

## Out-of-scope (intentionally deferred)

- Mobile capture (no Claude Code mobile)
- Multi-user data sharing (privacy model assumes single operator)
- Cloud sync (privacy-first design; data stays local)
- Real-time streaming UI (current statusline + dashboard sufficient)
