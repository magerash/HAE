# HAE RICE Backlog

Hypotheses scored by Reach (0-10) x Impact (0.25/0.5/1/2/3) x Confidence (0-1) / Effort (person-weeks).

Generated 2026-05-07 from CHANGELOG history + codebase health scan. Single-operator product; "Reach" approximates frequency hit per release cycle.

| ID  | Hypothesis | R | I | C | E | RICE | Status | Owner | Notes |
|-----|------------|---|---|---|---|------|--------|-------|-------|
| H3  | Twin gates expansion (on_scope_cut + on_mid_release_scope_add) | 6 | 1.5 | 0.8 | 0.3 | 24.0 | scoped | RM | Cheap config + skill wire; high signal during re-scoping |
| H1  | Marketplace UI install fix (`plugins/hae/` subdir restructure) | 8 | 2.0 | 0.7 | 1.0 | 11.2 | scoped | SA+OB | Unblocks `/plugin install hae@hae` UI flow |
| H6  | Subdir CLAUDE.md per feature area | 5 | 1.0 | 0.7 | 0.5 | 7.0 | scoped | SA | Progressive disclosure beyond docs/chunks/ |
| H8  | report.ps1 documentation chunk + readable formatter | 4 | 1.0 | 0.7 | 0.5 | 5.6 | scoped | UI | Behavioral report unreadable for non-author; needs feature chunk |
| H9  | Auto-promote homes wired (`weighting.auto_promote.enabled`) | 3 | 1.0 | 0.7 | 0.5 | 4.2 | scoped | OB | Config stub exists; no caller |
| H14 | Forum user-pain hypothesis hunt (reddit/HN scrape for HAE-adjacent pain) | 4 | 1.0 | 0.5 | 0.5 | 4.0 | scoped | RA | Added per twin pre-flight; honors operator principle "find insides in forum like reddit". Output feeds v0.6.0 scope. |
| H13 | Capture hook perf: persistent PS host (470ms cold -> <100ms) | 10 | 2.0 | 0.4 | 2.0 | 4.0 | research | RA | Risky; needs feasibility spike |
| H10 | Twin few-shot retrieval: semantic over keyword overlap | 8 | 2.0 | 0.4 | 2.0 | 3.2 | research | RA | Embedding model + offline index choice |
| H12 | v1.0.0 public OSS release | 10 | 3.0 | 0.3 | 4.0 | 2.25 | idea | PM | Needs marketplace fix (H1) first |
| H7  | install_plugin.ps1 refactor (marketplace/copy/registry split) | 2 | 0.5 | 0.8 | 0.5 | 1.6 | idea | OB | 296 lines; 3 distinct responsibilities |
| H11 | Phase 6: cross-project intelligence dashboard | 3 | 2.0 | 0.5 | 3.0 | 1.0 | research | RA | Entity rollups, trend analysis, drift detection |
| H2  | Web wizard `/hae:profile -Wizard` | 2 | 1.5 | 0.5 | 2.0 | 0.75 | idea | UI | Lossless 1-7 Likert + prev/next nav |
| H5  | Vector DB for chunk + exemplar retrieval | 4 | 2.0 | 0.3 | 4.0 | 0.6 | research | RA | Embedded options (sqlite-vec, lancedb) |
| H4  | AST chunking (cAST) for code chunks | 3 | 1.0 | 0.4 | 2.5 | 0.48 | research | RA | Mentioned in v0.4.1 chunking research as deferred |

## Status legend

- `scoped` - assigned to current or next release
- `research` - in research_queue.md
- `idea` - parked, awaiting reach signal or research
- `done` - shipped (move to changelog reference, drop from active backlog)

## Backlog hygiene

Re-score quarterly. Drop items where R*I*C trends toward 0 across two cycles. Promote `idea` -> `research` when an item blocks higher-RICE work.
