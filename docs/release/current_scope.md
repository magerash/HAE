# Current Release Scope - v0.5.0

twin_preflight: approve (conditions applied: H8 mockup-first, H14 forum-pain added) | 2026-05-07 | confidence: medium-high

**Theme:** Twin signal density + doc tightening + auto-promote homes + research intake. H1 deferred to v0.6.0 by operator default after H17 research surfaced revised RICE (28.8) and confirmed it's a 2-4 hour task that warrants its own focused cycle.

**Target ship:** Wave 1 + Wave 2 done in single session 2026-05-07. Awaiting CB.

## Items

| ID | Title | RICE | Owner | Status |
|----|-------|------|-------|--------|
| H3 | Twin gates: on_scope_cut + on_mid_release_scope_add + on_backlog_add (bonus) | 24.0 | RM | **shipped** - wired in `.claude/commands/scope-review.md` + `.claude/commands/rice-score.md`; pattern doc at `docs/chunks/patterns/twin-gate.md` |
| H6 | CLAUDE.md tighten + chunk-breadcrumb pattern (reframed from subdir CLAUDE.md) | 7.0 | SA | **shipped** - root trimmed 240 -> 188 lines; breadcrumbs added to root + INDEX |
| H8 mockup | report.ps1 formatter mockup | 5.6 | UI | **shipped (mockup phase)** - `docs/research/report_formatter_mockup_2026-05-07.md` written, awaiting operator approval before code |
| H9 | Auto-promote homes wired | 4.2 | OB | **shipped** - new `scripts/_homes_lib.ps1`; classify.ps1 post-batch trigger; status.ps1 candidate display; audit log to `state/auto_promote.log` |
| H14 | Forum user-pain hypothesis hunt | 4.0 | RA | **shipped** - `docs/research/forum_userpain_2026-05-07.md`; produced H18/H19/H20/H21 as v0.6.0 candidates |
| H17 | Plugin distribution research | 20.0 | RA | **shipped** - `docs/research/plugin_distribution_2026-05-07.md`; revised H1/H12/H16 RICE in backlog |
| H1 | Marketplace UI install (`plugins/hae/` subdir restructure) | 28.8 | SA+OB | **deferred to v0.6.0** - destructive restructure; operator chose to ship v0.5.0 first |
| H8 code | report.ps1 implementation | 5.6 | UI | **deferred to v0.6.0** - awaiting H8 mockup approval |

## Out of scope (deferred to v0.6.0+)

- H1 marketplace restructure - moved to v0.6.0 (operator default - destructive change warrants own cycle)
- H8 code - awaiting mockup approval; ship in v0.6.0
- H13 hook perf - blocked by feasibility research
- H10 twin semantic retrieval - blocked by embedding choice research
- H12 v1.0 OSS - blocked by H1 shipping first
- H16 cross-platform - YELLOW research
- H15 Codex CLI - GREEN research

## Dependencies

- H17 + H14 research complete; findings applied to backlog and roadmap
- H3 wiring lives in `.claude/commands/` (now tracked - gitignore fixed this session)
- H1 deferred but unblocked; first item of v0.6.0 scope
- H8 mockup must be approved before H8 code begins

## Test plan handoff (post-CB, post-reinstall)

QA verifies per shipped item:

1. **H3 twin gates** - in `<dataRoot>/config.json` set `twin.gates.on_scope_cut=true`; run `/scope-review` and request item cut; confirm twin banner renders + `current_scope.md` header records the gate fire. Repeat for `on_mid_release_scope_add` (set true, request mid-release add via /scope-review) and `on_backlog_add` (set true, run `/rice-score` w/ new hypothesis).
2. **H6 CLAUDE.md** - confirm `wc -l CLAUDE.md` returns ~188; open three random feature chunks listed in the new breadcrumb table and confirm they exist + render correctly.
3. **H8 mockup** - operator reads `docs/research/report_formatter_mockup_2026-05-07.md` and marks status block APPROVED / APPROVED WITH CHANGES / REJECTED. Sign-off recorded in scope file.
4. **H9 auto-promote** - integration test: with `weighting.auto_promote.enabled=false` (default), run `/hae:classify`; confirm no write to user config. Set `enabled=true` in user config; re-run `/hae:classify` over a project w/ records >= `min_records`; confirm project appears in `weighting.homes` + a JSON line lands in `<dataRoot>/state/auto_promote.log`. Run `/hae:status` and verify the auto_promote section + new home shows.
5. **H17 + H14 research files** - operator reads each file end-to-end; confirms RICE revisions in backlog match research recommendations.

**Post-reinstall:** because `.claude/commands/*.md` are loaded from the installed plugin path (`C:\Plugins\hae\`), re-run `scripts/install_plugin.ps1` after CB. Restart Claude Code. Verify `/plugin list` reports `hae@hae-local` enabled and 0 errors.
