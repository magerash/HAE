# Current Release Scope - v0.5.0

twin_preflight: approve (conditions applied: H8 mockup-first, H14 forum-pain added) | 2026-05-07 | confidence: medium-high

**Theme:** Twin signal density + install reach. Capitalize on Phase 5 done state by widening twin coverage and unblocking marketplace install.

**Target ship:** ~2 weeks (single-operator pace).

## Items

| ID | Title | RICE | Owner | Acceptance |
|----|-------|------|-------|------------|
| H3 | Twin gates: enable on_scope_cut + on_mid_release_scope_add | 24.0 | RM | Both gates fire twin.ps1 when /release-plan or user mutates scope; banner rendered; persisted to current_scope.md header |
| H1 | Marketplace UI install (plugins/hae/ subdir restructure) | 11.2 | SA+OB | `/plugin marketplace add Magerash/HAE` + `/plugin install hae@hae` works in UI; install_plugin.ps1 still works as fallback |
| H6 | Subdir CLAUDE.md per feature area | 7.0 | SA | scripts/CLAUDE.md, skills/CLAUDE.md, docs/CLAUDE.md exist with feature-scoped guidance; root CLAUDE.md trimmed |
| H8 | report.ps1 documentation chunk + readable formatter | 5.6 | UI | **Step 1 (mockup):** sketch report layout in markdown w/ status before code. **Step 2:** docs/chunks/features/report.md created; report output adds section anchors + table-of-contents. Mockup-first per operator principle. |
| H9 | Auto-promote homes wired | 4.2 | OB | manage_homes.ps1 + capture honor `auto_promote.enabled`; promotes after `min_records` threshold |
| H14 | Forum user-pain hypothesis hunt (HAE / Claude Code workflows) | 4.0 | RA | docs/research/forum_userpain_2026-05-XX.md w/ 5+ pain hypotheses pulled from reddit r/ClaudeAI, r/LocalLLaMA, HN threads on agent observability. Per operator principle "find insides in forum like reddit". |

## Out of scope (deferred)

- H13 hook perf - blocked by feasibility research
- H10 twin semantic retrieval - blocked by embedding choice research
- H12 v1.0 OSS - blocked by H1 (marketplace install must work first)

## Dependencies

- H1 must ship before H12 can be scoped
- H3 should ship before next /release-plan cycle so twin gates exercise themselves
- H6 + H8 are independent docs; can ship in parallel

## Test plan handoff

QA verifies per item:

1. **H3** - manually trigger scope cut via /release-plan, observe twin banner; check current_scope.md header carries twin_preflight line
2. **H1** - fresh Claude Code install on second machine, run UI install path, verify capture fires within 1s
3. **H6** - root CLAUDE.md line count drops; subdir CLAUDE.md files load only in their respective working contexts
4. **H8** - run report.ps1 against operator data, verify TOC + sections render readable in both terminal + markdown viewer
5. **H9** - drop capture below threshold then above, verify auto-promote fires once and only once
6. **H14** - RA produces research file w/ 5+ forum-sourced pain hypotheses; each links to source thread; each scored against HAE relevance + operator's existing principles
