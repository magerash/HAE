# HAE RICE Backlog

Hypotheses scored by Reach (0-10) x Impact (0.25/0.5/1/2/3) x Confidence (0-1) / Effort (person-weeks).

Generated 2026-05-07 from CHANGELOG history + codebase health scan. Single-operator product; "Reach" approximates frequency hit per release cycle.

| ID  | Hypothesis | R | I | C | E | RICE | Status | Owner | Notes |
|-----|------------|---|---|---|---|------|--------|-------|-------|
| H1  | Marketplace UI install fix (`plugins/hae/` subdir + `marketplace.json` at root + plugin.json hooks declaration) | 8 | 2.0 | 0.9 | 0.5 | 28.8 | done-v0.6.0 | SA+OB | Shipped 2026-05-10 v0.6.0; restructure to plugins/hae/ + marketplace.json + plugin.json declares hooks/commands/agents/skills paths |
| H19 | Override-rate drift signal in `/hae:status`: trailing 4-week sparkline as personal Anthropic-change detector | 5 | 2.0 | 0.8 | 0.3 | 26.7 | done-v0.6.0 | OB | Shipped 2026-05-10 v0.6.0; _metrics_lib.ps1 + status.ps1 dashboard section; live test detected +294% overall drift (+2400% evidence axis) |
| H3  | Twin gates expansion (on_scope_cut + on_mid_release_scope_add + on_backlog_add bonus) | 6 | 1.5 | 0.8 | 0.3 | 24.0 | shipped-v0.5 | RM | Done v0.5.0; wired into scope-review.md + rice-score.md |
| H17 | Plugin distribution research (study top Claude Code plugins) | 5 | 1.5 | 0.8 | 0.3 | 20.0 | researched | RA | docs/research/plugin_distribution_2026-05-07.md. Findings revised H1, H12, H16 RICE. |
| H18 | `/hae:cost` skill: token spend tracker w/ additive schema (tokens_in, tokens_out, model) | 6 | 1.5 | 0.8 | 0.5 | 14.4 | done-v0.6.0 | OB+SA | Shipped 2026-05-10 v0.6.0; Approach A per H18 RA (parse usage from transcript tail in Stop hook); 4 new schema fields + 1 nullable; cost.ps1 + /hae:cost skill + features/cost.md chunk; new include_tokens=true default writes slim StopTokens record |
| H12 | v1.0.0 public OSS release | 10 | 3.0 | 0.6 | 2.5 | 7.0 | scoped-v0.7 | PM+SA | Effort revised 2.5w -> 1.0w post-v0.6.0 (LICENSE + marketplace + plugin.json declarations done); v0.6.1 added MIT LICENSE; remaining: CONTRIBUTING + marketplace submission + README external polish |
| H6  | Tighten CLAUDE.md + chunk-breadcrumb pattern | 5 | 1.0 | 0.7 | 0.5 | 7.0 | shipped-v0.5 | SA | Done v0.5.0; root trimmed 240 -> 188 lines |
| H8  | report.ps1 documentation chunk + readable formatter (mockup-first) | 4 | 1.0 | 0.7 | 0.5 | 5.6 | scoped-v0.7-gated | UI | Mockup shipped v0.5.0; code v0.7.0 gated on mockup approval (carry from v0.6.0 gate; deadline 2026-05-17) |
| H22 | `/hae:export` skill: CSV + markdown summary by project (anti-lock-in OSS positioning) | 5 | 1.5 | 0.7 | 0.3 | 17.5 | scoped-v0.7 | OB | NEW from H14 forum theme E (data portability); reuses _metrics_lib.ps1 helpers; addresses Cursor-style lock-in anxiety |
| H20 | Repetition-candidate classifier: identify prompts typed 10+ times | 4 | 1.0 | 0.7 | 0.5 | 5.6 | scoped-v0.7 | OB | classify-phase extension; no new infrastructure |
| H16 | Cross-platform install (macOS + Linux paths, shell, hooks) | 10 | 2.5 | 0.8 | 4.0 | 5.0 | research | RA | YELLOW; effort doubled to 4w post-H17 (PowerShell port is real work); confidence up |
| H9  | Auto-promote homes wired (`weighting.auto_promote.enabled`) | 3 | 1.0 | 0.7 | 0.5 | 4.2 | shipped-v0.5 | OB | Done v0.5.0; _homes_lib.ps1 + classify.ps1 trigger + status.ps1 display + audit log |
| H14 | Forum user-pain hypothesis hunt | 4 | 1.0 | 0.5 | 0.5 | 4.0 | researched | RA | docs/research/forum_userpain_2026-05-07.md. Produced H18/H19/H20/H21 as v0.6.0 candidates. |
| H13 | Capture hook perf: persistent PS host (470ms cold -> <100ms) | 10 | 2.0 | 0.3 | 4.0 | 1.5 | researched | RA | PARK persistent-host (C 0.4->0.3, E 2.0->4.0, RICE 4.0->1.5); quick win: async:true on hooks (0-effort); Alt-B Go binary RICE 5.6 candidate-v0.9; docs/research/h13_persistent_ps_host_2026-05-10.md |
| H10 | Twin few-shot retrieval: semantic over keyword overlap | 8 | 2.5 | 0.7 | 2.5 | 5.6 | researched | RA | docs/research/h10_semantic_retrieval_2026-05-10.md. BUILD: fastembed/all-MiniLM-L6-v2 ONNX + flat numpy + Option A pre-compute; staleness detection Phase 2 gated. RICE revised: C 0.5->0.7 (unknowns resolved), E 2.0->2.5 (Python embed pipeline + integration). Score 5.0->5.6. candidate-v0.8 |
| H21 | PostToolUse hook capture + `/hae:trace <session-id>` skill | 5 | 2.0 | 0.6 | 1.5 | 4.0 | candidate-v0.8 | OB+SA | Twin-deferred from v0.7.0 (low-RICE-high-effort vs H22+H12); v0.8.0 batch w/ H10 schema work; effort revised 2.0w -> 1.5w using H18 StopTokens slim-record pattern reuse |
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

## Recent changes (2026-05-10 evening)

- v0.7.0 scope locked: H22 (new top, 17.5), H12 (revised 7.0), H8 code (carry-gated), H20.
- H22 added: `/hae:export` from H14 forum theme E (data portability); RICE 17.5; near-free implementation.
- H12 effort revised 2.5w -> 1.0w post-v0.6.0+v0.6.1 (LICENSE + marketplace + declarations done); RICE re-scored 7.2 -> 7.0 (R adjusted to 5 for realistic post-publish reach).
- H21 twin-deferred from v0.7.0 to v0.8.0 (low-RICE-high-effort); effort revised 2.0w -> 1.5w using H18 StopTokens pattern reuse.
- H10 RICE bumped 3.2 -> 5.0 per H14 + Mem0 industry-confirm.
- H1, H19, H18, H17, H14, H6, H9, H3 marked `done-v0.6.0` (shipped 2026-05-10).
- v0.6.1: MIT license added.
- H13 PARK: persistent PS host C 0.4->0.3, E 2.0->4.0, RICE 4.0->1.5; quick win (async:true) + Alt-B Go binary (RICE 5.6) identified as better paths; candidate-v0.9.

## Recent changes (2026-05-10 morning)

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
