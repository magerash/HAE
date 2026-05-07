# HAE RICE Backlog

Hypotheses scored by Reach (0-10) x Impact (0.25/0.5/1/2/3) x Confidence (0-1) / Effort (person-weeks).

Generated 2026-05-07 from CHANGELOG history + codebase health scan. Single-operator product; "Reach" approximates frequency hit per release cycle.

| ID  | Hypothesis | R | I | C | E | RICE | Status | Owner | Notes |
|-----|------------|---|---|---|---|------|--------|-------|-------|
| H1  | Marketplace UI install fix (`plugins/hae/` subdir + `marketplace.json` at root + plugin.json hooks declaration) | 8 | 2.0 | 0.9 | 0.5 | 28.8 | scoped | SA+OB | RICE up 2.6x post-H17 research; effort revised to 2-4 hour task; critical: plugin.json must declare hooks or marketplace install silently breaks them |
| H19 | Override-rate drift signal in `/hae:status`: trailing 4-week sparkline as personal Anthropic-change detector | 5 | 2.0 | 0.8 | 0.3 | 26.7 | candidate-v0.6 | OB | New from H14 forum research; serves operator's evidence-dominant decision style; near-free implementation on existing structured records |
| H3  | Twin gates expansion (on_scope_cut + on_mid_release_scope_add + on_backlog_add bonus) | 6 | 1.5 | 0.8 | 0.3 | 24.0 | shipped-wave1 | RM | v0.5.0 wave 1 done; wired into scope-review.md + rice-score.md |
| H17 | Plugin distribution research (study top Claude Code plugins) | 5 | 1.5 | 0.8 | 0.3 | 20.0 | researched | RA | docs/research/plugin_distribution_2026-05-07.md. Findings revised H1, H12, H16 RICE. |
| H18 | `/hae:cost` skill: token spend tracker w/ additive schema (tokens_in, tokens_out, model) | 6 | 1.5 | 0.8 | 0.5 | 14.4 | candidate-v0.6 | OB+SA | New from H14; uses existing capture infrastructure; non-breaking schema additive |
| H12 | v1.0.0 public OSS release | 10 | 3.0 | 0.6 | 2.5 | 7.2 | candidate-v0.6 | PM+SA | RICE up 3.2x post-H17; unblocked once H1 ships; OSS playbook documented |
| H6  | Tighten CLAUDE.md + chunk-breadcrumb pattern | 5 | 1.0 | 0.7 | 0.5 | 7.0 | shipped-wave1 | SA | Reframed from subdir CLAUDE.md per existing chunking research; root trimmed 240 -> 188 lines |
| H8  | report.ps1 documentation chunk + readable formatter (mockup-first) | 4 | 1.0 | 0.7 | 0.5 | 5.6 | wave1-mockup-done | UI | Mockup at docs/research/report_formatter_mockup_2026-05-07.md awaiting operator approval; code in wave 3 |
| H20 | Repetition-candidate classifier: identify prompts typed 10+ times | 4 | 1.0 | 0.7 | 0.5 | 5.6 | candidate-v0.6 | OB | New from H14; classify-phase extension; no new infrastructure |
| H16 | Cross-platform install (macOS + Linux paths, shell, hooks) | 10 | 2.5 | 0.8 | 4.0 | 5.0 | research | RA | YELLOW; effort doubled to 4w post-H17 (PowerShell port is real work); confidence up |
| H9  | Auto-promote homes wired (`weighting.auto_promote.enabled`) | 3 | 1.0 | 0.7 | 0.5 | 4.2 | shipped-wave1 | OB | _homes_lib.ps1 + classify.ps1 trigger + status.ps1 display + audit log |
| H14 | Forum user-pain hypothesis hunt | 4 | 1.0 | 0.5 | 0.5 | 4.0 | researched | RA | docs/research/forum_userpain_2026-05-07.md. Produced H18/H19/H20/H21 as v0.6.0 candidates. |
| H13 | Capture hook perf: persistent PS host (470ms cold -> <100ms) | 10 | 2.0 | 0.4 | 2.0 | 4.0 | research | RA | RED; needs feasibility spike |
| H10 | Twin few-shot retrieval: semantic over keyword overlap | 8 | 2.0 | 0.4 | 2.0 | 3.2 | research | RA | YELLOW; H14 confirms keyword retrieval is industry-recognized failure mode (Mem0 report); upgrade priority |
| H21 | PostToolUse hook capture + `/hae:trace <session-id>` skill | 5 | 2.0 | 0.6 | 2.0 | 3.0 | candidate-v0.6 | OB+SA | New from H14; new hook binding + schema work; differentiated capability |
| H15 | Codex CLI integration | 8 | 2.0 | 0.4 | 2.5 | 2.56 | research | RA | GREEN; depends on Codex hook contract |
| H7  | install_plugin.ps1 refactor (marketplace/copy/registry split) | 2 | 0.5 | 0.8 | 0.5 | 1.6 | idea | OB | 296 lines; 3 distinct responsibilities |
| H11 | Phase 6: cross-project intelligence dashboard | 3 | 2.0 | 0.5 | 3.0 | 1.0 | research | RA | Entity rollups, trend analysis, drift detection |

## Status legend

- `scoped` - assigned to current or next release
- `shipped-wave1` - implemented in current cycle, awaiting CB
- `wave1-mockup-done` - mockup phase complete, code awaiting approval
- `candidate-v0.6` - new from research, slated for next scope review
- `research` - in research_queue.md
- `researched` - research file exists; awaiting RICE re-evaluation or scope-in
- `idea` - parked, awaiting reach signal or research
- `done` - shipped (moved to changelog reference)

## Backlog hygiene

Re-score quarterly. Drop items where R*I*C trends toward 0 across two cycles. Promote `idea` -> `research` when an item blocks higher-RICE work.

## Recent changes (2026-05-07)

- H1 RICE 11.2 -> 28.8 (now top of backlog) per H17 research findings
- H12 RICE 2.25 -> 7.2 per H17 (OSS path simpler than estimated)
- H16 effort 2.0w -> 4.0w per H17 (PowerShell-to-bash port underestimated)
- H17 marked `researched`, H14 marked `researched`
- H3, H6, H9 marked `shipped-wave1` (v0.5.0 implementation)
- H8 marked `wave1-mockup-done`
- H18, H19, H20, H21 added as v0.6.0 candidates from H14 forum research
