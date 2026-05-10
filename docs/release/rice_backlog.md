# HAE RICE Backlog

Hypotheses scored by Reach (0-10) x Impact (0.25/0.5/1/2/3) x Confidence (0-1) / Effort (person-weeks).

Generated 2026-05-07 from CHANGELOG history + codebase health scan. Single-operator product; "Reach" approximates frequency hit per release cycle.

| ID  | Hypothesis | R | I | C | E | RICE | Status | Owner | Notes |
|-----|------------|---|---|---|---|------|--------|-------|-------|
| H1  | Marketplace UI install fix (`plugins/hae/` subdir + `marketplace.json` at root + plugin.json hooks declaration) | 8 | 2.0 | 0.9 | 0.5 | 28.8 | shipped-v0.6 | SA+OB | Done 2026-05-10; restructure to plugins/hae/ + marketplace.json + plugin.json declares hooks/commands/agents/skills paths |
| H19 | Override-rate drift signal in `/hae:status`: trailing 4-week sparkline as personal Anthropic-change detector | 5 | 2.0 | 0.8 | 0.3 | 26.7 | shipped-v0.6 | OB | Done 2026-05-10; _metrics_lib.ps1 + status.ps1 dashboard section; live test detected +294% overall drift (+2400% evidence axis) |
| H3  | Twin gates expansion (on_scope_cut + on_mid_release_scope_add + on_backlog_add bonus) | 6 | 1.5 | 0.8 | 0.3 | 24.0 | shipped-v0.5 | RM | Done v0.5.0; wired into scope-review.md + rice-score.md |
| H17 | Plugin distribution research (study top Claude Code plugins) | 5 | 1.5 | 0.8 | 0.3 | 20.0 | researched | RA | docs/research/plugin_distribution_2026-05-07.md. Findings revised H1, H12, H16 RICE. |
| H18 | `/hae:cost` skill: token spend tracker w/ additive schema (tokens_in, tokens_out, model) | 6 | 1.5 | 0.8 | 0.5 | 14.4 | shipped-v0.6 | OB+SA | Done 2026-05-10; Approach A per H18 RA (parse usage from transcript tail in Stop hook); 4 new schema fields + 1 nullable; cost.ps1 + /hae:cost skill + features/cost.md chunk; new include_tokens=true default writes slim StopTokens record |
| H12 | v1.0.0 public OSS release | 10 | 3.0 | 0.6 | 2.5 | 7.2 | scoped-v0.6 | PM+SA | Gate 1 cleared 2026-05-10; awaits operator LICENSE + CONTRIBUTING decisions to start |
| H6  | Tighten CLAUDE.md + chunk-breadcrumb pattern | 5 | 1.0 | 0.7 | 0.5 | 7.0 | shipped-v0.5 | SA | Done v0.5.0; root trimmed 240 -> 188 lines |
| H8  | report.ps1 documentation chunk + readable formatter (mockup-first) | 4 | 1.0 | 0.7 | 0.5 | 5.6 | scoped-v0.6-gated | UI | Mockup shipped v0.5.0; code v0.6.0 gated on mockup approval by 2026-05-17 |
| H20 | Repetition-candidate classifier: identify prompts typed 10+ times | 4 | 1.0 | 0.7 | 0.5 | 5.6 | candidate-v0.7 | OB | Slated for v0.7.0; classify-phase extension; no new infrastructure |
| H16 | Cross-platform install (macOS + Linux paths, shell, hooks) | 10 | 2.5 | 0.8 | 4.0 | 5.0 | research | RA | YELLOW; effort doubled to 4w post-H17 (PowerShell port is real work); confidence up |
| H9  | Auto-promote homes wired (`weighting.auto_promote.enabled`) | 3 | 1.0 | 0.7 | 0.5 | 4.2 | shipped-v0.5 | OB | Done v0.5.0; _homes_lib.ps1 + classify.ps1 trigger + status.ps1 display + audit log |
| H14 | Forum user-pain hypothesis hunt | 4 | 1.0 | 0.5 | 0.5 | 4.0 | researched | RA | docs/research/forum_userpain_2026-05-07.md. Produced H18/H19/H20/H21 as v0.6.0 candidates. |
| H13 | Capture hook perf: persistent PS host (470ms cold -> <100ms) | 10 | 2.0 | 0.4 | 2.0 | 4.0 | research | RA | RED; needs feasibility spike |
| H10 | Twin few-shot retrieval: semantic over keyword overlap | 8 | 2.0 | 0.4 | 2.0 | 3.2 | research | RA | YELLOW; H14 confirms keyword retrieval is industry-recognized failure mode (Mem0 report); upgrade priority |
| H21 | PostToolUse hook capture + `/hae:trace <session-id>` skill | 5 | 2.0 | 0.6 | 2.0 | 3.0 | candidate-v0.7 | OB+SA | Slated for v0.7.0; new hook binding + schema work; differentiated capability |
| H15 | Codex CLI integration | 8 | 2.0 | 0.4 | 2.5 | 2.56 | research | RA | GREEN; depends on Codex hook contract |
| H7  | install_plugin.ps1 refactor (marketplace/copy/registry split) | 2 | 0.5 | 0.8 | 0.5 | 1.6 | idea | OB | 296 lines; 3 distinct responsibilities |
| H11 | Phase 6: cross-project intelligence dashboard | 3 | 2.0 | 0.5 | 3.0 | 1.0 | research | RA | Entity rollups, trend analysis, drift detection |

## Status legend

- `scoped-v0.6` - locked into v0.6.0 (current release)
- `scoped-v0.6-gated` - in v0.6.0 with twin pre-flight gate condition
- `candidate-v0.7` - slated for next release scope review
- `shipped-v0.5` - shipped in v0.5.0
- `research` - in research_queue.md
- `researched` - research file exists
- `idea` - parked
- `done` - shipped (moved to changelog reference)

## Backlog hygiene

Re-score quarterly. Drop items where R*I*C trends toward 0 across two cycles. Promote `idea` -> `research` when an item blocks higher-RICE work.

## Recent changes (2026-05-10)

- v0.6.0 scope locked: H1, H19, H18, H12 (gated), H8 code (gated)
- H12 + H8 code in v0.6.0 gated per twin pre-flight conditions; carry to v0.7.0 if gates trip
- H20, H21 promoted to `candidate-v0.7`
- H3, H6, H9 marked `shipped-v0.5` (v0.5.0 close)

## Recent changes (2026-05-07)

- H1 RICE 11.2 -> 28.8 (now top of backlog) per H17 research findings
- H12 RICE 2.25 -> 7.2 per H17 (OSS path simpler than estimated)
- H16 effort 2.0w -> 4.0w per H17 (PowerShell-to-bash port underestimated)
- H17 marked `researched`, H14 marked `researched`
- H18, H19, H20, H21 added as v0.6.0 candidates from H14 forum research
