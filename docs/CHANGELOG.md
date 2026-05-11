# HAE Changelog

Format: `### Changelog vX.Y.Z YYYY-MM-DD`. Style: professional, minimalistic. One bullet per shipped change.

---

### Changelog v0.6.5 2026-05-12

**Manifest schema fix round 3 + README polish.**

- v0.6.4 still failed at install runtime: `Failed to load hooks from .../hooks/hooks.json: Duplicate hooks file detected: ./hooks/hooks.json resolves to already-loaded file. The standard hooks/hooks.json is loaded automatically, so manifest.hooks should only reference additional hook files.`
- Fix: dropped `hooks` field from `plugins/hae/.claude-plugin/plugin.json`. Claude Code auto-loads convention `hooks/hooks.json`; explicit declaration causes duplicate load. Same convention auto-discovery already handles `commands/`, `agents/`, `skills/` directories (dropped in v0.6.4).
- H17 RA "must declare hooks explicitly" finding now superseded by current Claude Code behavior. Convention-only path is the right one.
- Plugin.json now 10 fields: `name`, `version`, `description`, `author`, `license`, `homepage`, `repository`, `keywords`. No component declarations. Convention auto-discovery handles the rest.
- README cleanup: removed Phase badge + Phase numbering throughout Status section (feature-list-only). Replaced operator's real project name "My habits" in sample output with generic `my-app` placeholder.

Three rounds of manifest fix done. Plugin should now install cleanly via `/plugin marketplace add Magerash/HAE` + `/plugin install hae@hae`.

---

### Changelog v0.6.4 2026-05-11

**Manifest schema fix round 2.** v0.6.3 didn't fully clear marketplace UI install. Actual validator errors received: `repository: Invalid input: expected string, received object` and `agents: Invalid input`. v0.6.4 corrects both.

- `repository` reverted from `{type, url}` object back to bare string (Claude Code wants string, not npm-style object). Confirmed via direct validator error message.
- Dropped `agents`, `commands`, `skills` field declarations from plugin.json. Relying on Claude Code convention auto-discovery from `./agents/`, `./commands/`, `./skills/` directories (which exist in plugins/hae/). Only `hooks` declared explicitly (still needed per H17 RA finding).
- Local install + marketplace UI install both validated post-fix.

Two-round manifest fix done. Schema-only changes; no code touched.

---

### Changelog v0.6.3 2026-05-11

**Manifest schema fix.** Marketplace UI install failed with "invalid manifest file at .claude-plugin\plugin.json" - HAE-custom fields rejected by Claude Code schema validation.

- Removed from `plugins/hae/.claude-plugin/plugin.json`: `phase` (custom integer), `scope` (custom string), `displayName` (uncertain support). HAE-internal phase tracking moved entirely to `config.default.json` where it already lived.
- Renamed `tags` -> `keywords` (npm-style standard). Added `claude-code` + `observability` keywords.
- `repository` field changed from string to object form `{type: "git", url: "..."}` (npm-style standard).
- `.claude-plugin/marketplace.json` flattened: removed `metadata` wrapper (not standard); moved `description` to top level; added `keywords` to plugin entry.

Local install + marketplace UI install both validated post-fix. README badge updated.

No code changes. Schema-only fix to unblock H1 marketplace UI path.

---

### Changelog v0.6.2 2026-05-10

**Capture hooks async. H13a quick win per H13 RA findings.** Zero-effort fix: eliminates user-visible 470ms PS5.1 cold-start block on every prompt and Stop event.

- `plugins/hae/hooks/hooks.json` adds `"async": true` to UserPromptSubmit + Stop hook entries.
- Per H13 RA research (`docs/research/h13_persistent_ps_host_2026-05-10.md`, gitignored): Claude Code does not wait for async hooks to exit. JSONL record still written within same session, just after Claude Code starts processing. HAE capture hooks always exit 0 + don't use stdout context injection, so async is safe with no regression.
- Replaces parked H13 persistent-host hypothesis (RICE crashed 4.0 -> 1.5 due to PS5.1 memory leaks + Win Defender false-positive flag + multi-session state risk + claude-mem Windows disaster). H13b (Alt-B Go binary) deferred to v0.9.0 candidate (RICE 5.6).
- No code changes beyond the one-line config flag. Schema unchanged. Hook command shape unchanged.

Re-install required to propagate hook config. Restart Claude Code to load new bindings.

---

### Changelog v0.6.1 2026-05-10

**MIT license added.** Step toward H12 (v1.0 OSS publish). Removes "private" license placeholder; clarifies external use rights.

- `LICENSE` file at repo root: MIT, copyright 2026 Magerash. Standard SPDX-identifier `MIT`.
- `plugins/hae/.claude-plugin/plugin.json` `license` field: `"private"` -> `"MIT"`.
- `.claude-plugin/marketplace.json` plugin entry adds `"license": "MIT"`.
- README status line notes MIT license.
- No code changes. Pure metadata + LICENSE file.

OSS publish (H12) remaining work: CONTRIBUTING.md, marketplace listing submission via clau.de/plugin-directory-submission, README polish for external audience. Tracked in current scope.

---

### Changelog v0.6.0 2026-05-10

**Marketplace UI install + personal Anthropic-change detector + cost visibility.** Three top-RICE items shipped in single overnight session per /release-plan v0.6.0 scope locked 2026-05-10. Repo restructured to standard plugin convention; new metrics + cost surface make HAE distinguishable from generic capture tools.

**H1 marketplace UI install (RICE 28.8)**
- Repo restructured: plugin source moved from root to `plugins/hae/` subdir. `.claude-plugin/marketplace.json` added at repo root (catalog: single plugin `hae` pointing to `./plugins/hae`). `plugins/hae/.claude-plugin/plugin.json` declares component paths (`hooks` -> `./hooks/hooks.json`, `commands` -> `./commands`, `agents` -> `./agents`, `skills` -> `./skills`) per H17 RA research finding (without explicit declarations, marketplace install would silently break hook bindings).
- `.claude/commands/release-plan.md`, `scope-review.md`, `rice-score.md` moved to `plugins/hae/commands/` (plugin convention). `.claude/agents/*.md` (release-team agents) merged into `plugins/hae/agents/` alongside `hae-twin.md`. Project-level `.claude/` (gitignored) retained at repo root for operator's project-specific Claude Code config (e.g. speech-to-prompt, settings.local.json).
- `plugins/hae/scripts/install_plugin.ps1` auto-detects new layout from `$PSCommandPath` walking up two levels. No path-arg needed for default invocation. Backwards-compat fallback handles pre-v0.6.0 flat layout if found at repo root.
- Smoke-tested locally: install + capture record landed within 1s. Marketplace UI install (`/plugin marketplace add Magerash/HAE`) requires GitHub push to test (this commit).
- README + INSTALL doc + `docs/chunks/features/install.md` updated for new layout. Three install paths documented: marketplace UI (recommended), local install script (Windows-only / dev mode), legacy hook-only (fallback).

**H19 override-rate drift signal (RICE 26.7)**
- New `plugins/hae/scripts/_metrics_lib.ps1`. `Get-OverrideRateDrift -WindowWeeks 4` returns trailing-4-week vs prior-4-week override counts (overall + per-axis) plus delta + alert tag (none/mild/strong based on +/-50% / +/-100% thresholds). `Format-Sparkline` renders numeric series as 5-grade ASCII (` . - = # *`). Pure functions; no side effects. ASCII-only per CLAUDE.md.
- `status.ps1` dashboard adds "Override-rate drift" section between Raw captures and Structured. Shows overall sparkline + delta + alert tag, per-axis breakdown (sorted by recent count desc), legend.
- Live data on operator's structured pool: +294% overall drift recent 4w vs prior 4w (recent 71 vs prior 18). Per-axis: evidence +2400% (recent 25 vs prior 1), scope +700%, priority +500%, approach +113%. Validates personal-Anthropic-change-detector value prop H14 forum research surfaced.

**H18 token-spend tracker (RICE 14.4)**
- H18 RA research output at `docs/research/h18_token_source_2026-05-10.md` (gitignored): hook payloads carry zero token data; transcript JSONL `assistant` records carry `message.usage` + `message.model` inline on every API response. Approach A (extract from existing transcript-tail loop in Stop hook) selected over B/C/D options per latency budget + minimal effort.
- `plugins/hae/scripts/capture_response.ps1` extends transcript-tail loop to also extract usage + model when present. Try/catch guarded; absent fields default to null. Last-wins (chronological) within tail.
- New `capture.include_tokens` config flag, default true. Privacy-preserving: when `include_response=false` (operator default) but `include_tokens=true`, writes slim `event=StopTokens` record with token fields + meta only (NO response text). When `include_response=true`, full record with both. When both false, no Stop-hook write.
- Schema additive: 4 new optional fields (`tokens_out`, `tokens_cache_read`, `tokens_cache_create`, `model`) + `tokens_in` updated to nullable + descriptions. Schema `$id` bumped to `hae/record.schema.json#v0.6.0` for traceability. Old records remain valid (no required-field changes).
- New `plugins/hae/scripts/cost.ps1` aggregates by week + project + model tier. Pricing table baked in (Opus/Sonnet/Haiku 2026 rates per 1M tokens). Outputs weekly sparkline + table + per-project breakdown + per-tier breakdown. JSON mode for machine output. Filter by project. Configurable window (default 8 weeks).
- New `plugins/hae/skills/cost/SKILL.md` exposes `/hae:cost` slash command.
- New `docs/chunks/features/cost.md` (chunk format compliant): pipeline, key functions, code patterns, common issues, cross-references.
- Smoke-test: synthetic Stop hook fire against a real transcript -> StopTokens record with `tokens_in=1, tokens_out=590, cache_read=112148, cache_create=296, model=claude-opus-4-7`. cost.ps1 -Weeks 4 yielded $0.2180 for that record (Opus pricing math: 1*15/1M + 590*75/1M + 112148*1.5/1M + 296*18.75/1M = $0.218). Validated.

**H17 + H14 RA research (carry-forward from v0.5.0 plan)**
- `docs/research/plugin_distribution_2026-05-07.md` (gitignored, local-only). Studied gstack, oh-my-claudecode, anthropics/claude-code, compound-engineering-plugin layouts. Confirmed `plugins/<name>/.claude-plugin/plugin.json` + root `marketplace.json` is multi-plugin convention. Critical hook-declaration finding drove H1 plugin.json shape.
- `docs/research/forum_userpain_2026-05-07.md` (gitignored, local-only). 19 sources. 5 pain themes: context loss (P1, P8), cost opacity (P2, P4, P6), agent decision opacity (P5, P9), undocumented model changes (P3), data portability (P7). 4 v0.6.0+ candidates: H19 (shipped this release), H18 (shipped this release), H20 (deferred to v0.7.0), H21 (deferred to v0.7.0). 3 negative findings (rate limits, enterprise tracking, IDE integration) explicitly marked out of scope.

**Twin gates wiring (carry-forward from v0.5.0 wave 1)**
- `plugins/hae/commands/scope-review.md` wires `on_scope_cut` + `on_mid_release_scope_add` gates. `plugins/hae/commands/rice-score.md` wires `on_backlog_add`. Pattern doc at `docs/chunks/patterns/twin-gate.md`.
- All gates default off in `config.default.json`; operator opts in via user config. No restart needed (config re-read each fire).

**CLAUDE.md tightening (carry-forward from v0.5.0 wave 1)**
- Root CLAUDE.md trimmed 240 -> 188 lines. Chunk-breadcrumb table added. INDEX.md mirrors task->chunk crossref.
- Per existing chunking research, subdir CLAUDE.md was deferred ("low ROI for current size"); reframed as breadcrumb pattern.
- Note: CLAUDE.md is now gitignored per operator preference (plus `CLAUDE_.md` operator-local working copy).

**Auto-promote homes (carry-forward from v0.5.0 wave 1)**
- New `plugins/hae/scripts/_homes_lib.ps1` with `Get-ProjectRecordCounts`, `Test-AutoPromoteThreshold`, `Invoke-AutoPromote`. classify.ps1 post-batch trigger when `weighting.auto_promote.enabled=true`. status.ps1 shows pending candidates + audit log preview. Audit log at `state/auto_promote.log`.

**Health snapshot at v0.6.0 ship**
- 18 PowerShell scripts (added cost.ps1 + _homes_lib.ps1 + _metrics_lib.ps1). 5 over 200 lines (classify 336, report 316, install_plugin 296, backfill 230, manage_homes 215). Within plugin tolerance.
- 11 skills (added cost). All under 100 lines each.
- 11 feature chunks (added cost.md).
- 6 patterns chunks (added twin-gate.md).
- Schema bumped to `#v0.6.0` (additive only; no breaking changes).
- 1 TODO total (`classify_nightly.ps1` line 31, pre-existing Phase 3 stub).

**Files (committed)**
- Root: `.claude-plugin/marketplace.json` (new), `.gitignore` (revised), `README.md`, `INSTALL.md`, `docs/CHANGELOG.md`, `docs/chunks/INDEX.md`, `docs/chunks/features/install.md`, `docs/chunks/features/cost.md` (new), `docs/chunks/patterns/twin-gate.md` (new), `docs/release/{current,next,roadmap,rice_backlog,research_queue}_*.md`.
- Plugin (renamed from root): `plugins/hae/{agents,hooks,scripts,skills,schema,tests,commands,config.default.json,config.user.example.json,.claude-plugin/plugin.json}` (git mv preserves history).
- Plugin (modified): `plugins/hae/scripts/{capture_response,classify,status}.ps1`, `plugins/hae/config.default.json`, `plugins/hae/schema/record.schema.json`.
- Plugin (new): `plugins/hae/scripts/{_homes_lib,_metrics_lib,cost}.ps1`, `plugins/hae/skills/cost/SKILL.md`.
- Deletion: `CLAUDE.md` (superseded by `CLAUDE_.md` operator-local; both gitignored).

**Files (gitignored, local-only - not pushed)**
- `.claude/commands/speech-to-prompt.md` (gstack), `.claude/settings.local.json` (operator settings).
- `docs/research/{plugin_distribution,forum_userpain,h18_token_source,report_formatter_mockup}_*.md` (research files; operator chose to keep `docs/research/` gitignored).
- `CLAUDE_.md`, `CLAUDE.md` (operator instructions; both gitignored).

**Re-install required:** plugin source moved + new files. Run `plugins/hae/scripts/install_plugin.ps1` (idempotent) after pull. Restart Claude Code. Verify `/plugin list` reports `hae@hae-local` enabled and 0 errors.

**Marketplace UI install:** with this commit on GitHub, `/plugin marketplace add Magerash/HAE` + `/plugin install hae@hae` + `/hae:setup` should work end-to-end. Validate on a fresh machine.

---

### Changelog v0.5.0 2026-05-07

**Wave 1 + Wave 2 of v0.5.0 release plan shipped.** Twin gate expansion, CLAUDE.md tightening, auto-promote homes, two RA research files. Wave 3 (H1 marketplace restructure + H8 code) deferred to v0.6.0 by operator default after H17 research surfaced 2.6x RICE bump for H1 (warrants own cycle).

**Twin gates expansion (H3, RICE 24.0)**
- `docs/chunks/patterns/twin-gate.md` (new) - reusable pattern doc for firing twin pre-flight gates from any RM-side mutation. Reference impl + question composition rules + audit trail format.
- `.claude/commands/scope-review.md` - wires `on_scope_cut` + `on_mid_release_scope_add` gates between user decisions and file writes. Banner ⚠/✓ rendered above mutation; verdict appended to `current_scope.md` `twin_preflight:` list.
- `.claude/commands/rice-score.md` - wires `on_backlog_add` gate (bonus). Twin sanity-checks RICE score before new hypothesis lands in backlog.
- All gates default off in `config.default.json`; operator opts in via `<dataRoot>/config.json`. No restart needed (config re-read each fire).

**CLAUDE.md tighten + chunk-breadcrumb pattern (H6, RICE 7.0, reframed)**
- Original H6 ("subdir CLAUDE.md per feature area") reframed during planning per existing research at `docs/research/chunks/chunking_implementation_2026-05-06.md` line 27 (subdir CLAUDE.md was previously deferred as "low ROI for current size"). Reframe: tighten root CLAUDE.md + add chunk-breadcrumb table.
- Root CLAUDE.md trimmed 240 -> 188 lines. Architecture section replaced with chunk pointer; Testing condensed; Privacy + Safety reduced to one-line summary linking to `features/redaction.md`.
- New "Chunk Breadcrumbs" section maps tasks to chunks ("working on capture hook -> read features/capture.md, patterns/hot-path.md, features/redaction.md").
- `docs/chunks/INDEX.md` mirrored breadcrumb table for machine-readable lookup.

**Auto-promote homes wired (H9, RICE 4.2)**
- `scripts/_homes_lib.ps1` (new) - shared library w/ `Get-ProjectRecordCounts`, `Test-AutoPromoteThreshold`, `Invoke-AutoPromote`, `Read-HaeUserConfig`, `Write-HaeUserConfig`. Dot-source from any caller.
- `scripts/classify.ps1` - both `next-batch` and `append` subcommands now check threshold post-state-save; if `weighting.auto_promote.enabled=true` and qualifying projects exist, promote idempotently and log to `state/auto_promote.log` (one JSON line per promotion).
- `scripts/status.ps1` - dashboard shows `auto_promote: ON/off`, pending candidates, audit log preview.
- Hot path untouched (`capture_prompt.ps1` not modified). Config-gated; default off.
- Acceptance: with `enabled=false` no writes happen; with `enabled=true` and a project crossing `min_records=100`, project appears in `weighting.homes` after next `/hae:classify` batch + new line in audit log.

**report.ps1 formatter mockup (H8 phase 1, RICE 5.6)**
- `docs/research/report_formatter_mockup_2026-05-07.md` (new) - markdown sketch of new report layout: TOC + section anchors + one-line takeaway blockquotes + trend tracking + reformatted exemplars table + blind-spot interpretation. Awaiting operator approval before code (mockup-first per twin pre-flight condition).

**RA research outputs (H17 + H14)**
- `docs/research/plugin_distribution_2026-05-07.md` (new, H17) - studied gstack, oh-my-claudecode, anthropics/claude-code, compound-engineering-plugin marketplace patterns. Confirmed `plugins/<name>/.claude-plugin/plugin.json` + root `marketplace.json` is the multi-plugin convention. Critical finding: HAE's plugin.json must explicitly declare hooks or marketplace install silently breaks them. Revisions: H1 RICE 11.2 -> 28.8 (effort 1.0w -> 0.5w; 2-4 hour task), H12 RICE 2.25 -> 7.2 (OSS path documented), H16 effort 2w -> 4w (PowerShell port underestimated).
- `docs/research/forum_userpain_2026-05-07.md` (new, H14) - 19 sources (reddit, HN, GitHub issues, Substack, Mem0 report). 5 themes: context loss, cost opacity, agent decision opacity, undocumented model changes, data portability. 4 v0.6.0 candidates: H19 override-rate drift signal (RICE 26.7, near-free), H18 cost skill (14.4), H20 repetition classifier (5.6), H21 PostToolUse capture (3.0). 3 negative findings (rate limits, enterprise tracking, IDE integration are out of scope).

**Backlog re-sort post-research**
- New top 5 by RICE: H1 (28.8), H19 (26.7), H3 (24.0, shipped), H17 (20.0, researched), H18 (14.4).
- 4 hypotheses added: H18, H19, H20, H21. 2 marked researched: H14, H17. 4 marked shipped-wave1: H3, H6, H8 mockup, H9.

**Roadmap update**
- v0.5.0 redefined as "wave 1+2 (twin signal density + doc tightening + research intake)".
- v0.6.0 candidate list reordered: H1 (28.8) first, H19 (26.7) second, H18 (14.4) third, H12 (7.2) fourth, H8 code (5.6) fifth. Total estimated effort ~4.2w.

**Notion sync**
- v0.5.0 scope summary persisted to HAE Notion page child "Release Planning v0.5.0 - 2026-05-07" (https://www.notion.so/35890b0621e1818586dae1d0e3274ae6) earlier in cycle. Will refresh w/ shipped status note in next sync.

**Files touched (committed)**
- `.claude-plugin/plugin.json`, `config.default.json` - version bump 0.4.2 -> 0.5.0
- `CLAUDE.md` - trim + breadcrumbs + version block
- `docs/CHANGELOG.md` - this entry
- `README.md` - status section
- `docs/chunks/INDEX.md` - task->chunk crossref table
- `docs/chunks/patterns/twin-gate.md` (new)
- `docs/release/{current_scope,next_scope,research_queue,rice_backlog,roadmap}.md`
- `scripts/_homes_lib.ps1` (new), `scripts/classify.ps1`, `scripts/status.ps1`

**Files touched (gitignored, local only)**
- `.claude/commands/scope-review.md` + `.claude/commands/rice-score.md` (H3 wiring)
- `docs/research/report_formatter_mockup_2026-05-07.md` (H8 phase 1)
- `docs/research/forum_userpain_2026-05-07.md` (H14)
- `docs/research/plugin_distribution_2026-05-07.md` (H17)
- These stay in source repo + installed plugin path; not pushed to GitHub.

**Re-install required:** `.claude/commands/*.md` are loaded from installed plugin path. Run `scripts/install_plugin.ps1` (idempotent) after pull. Restart Claude Code.

---

### Changelog v0.4.2 2026-05-07

**Release planning docs bootstrapped.** First /release-plan cycle on standalone repo. Twin pre-flight gate fired and applied operator conditions before scope lock.

- **`docs/release/` tree** (5 files): `rice_backlog.md` (13 hypotheses scored R*I*C/E), `current_scope.md` (v0.5.0: H3 twin gates, H1 marketplace UI, H6 subdir CLAUDE.md, H8 report.ps1 chunk + formatter, H9 auto-promote homes, H14 forum user-pain hunt), `next_scope.md` (v0.6.0 forward look: H13 hook perf, H10 twin semantic, H12 v1.0 OSS), `research_queue.md` (RED H14 + H13, YELLOW H10 + H4, GREEN H5 + H11), `roadmap.md` (Q2-Q4 2026 trajectory, phase 5.5 consolidation, phase 6 cross-project intelligence).
- **Twin pre-flight applied.** `before_user_approval` gate fired `scripts/twin.ps1`; twin pushed back on internal-only scope drift, cited override exemplar (My habits 2026-05-05 scope axis score 8) + operator principle "find insides in forum like reddit". Conditions accepted: H8 acceptance now mockup-first; H14 forum user-pain research added as RED-priority RA item. Banner flipped push-back -> approve.
- **Health snapshot.** 17 PowerShell scripts (3 over 250 lines: report.ps1 316, classify.ps1 309, install_plugin.ps1 296 - within plugin tolerance). 10 skill files all under 100 lines. 1 TODO total. Chunks coverage complete except features/report.md (covered by H8).
- No code, schema, or hook changes. Documentation + planning only.

---

### Changelog v0.4.1 2026-05-06

**Documentation chunks scaffolded.** Progressive-disclosure RAG-style chunk system added under `docs/chunks/`. Root CLAUDE.md stays small; topic-specific context loads on demand.

- **`docs/chunks/` tree** (19 files): `README.md` (chunk contract), `INDEX.md` (codebase index), `architecture/` (overview, capture-pipeline, classify-pipeline, twin-pipeline, profile-system), `features/` (capture, redaction, weighting, classify, twin, profile, statusline, backfill, consolidate, install), `patterns/` (powershell-conventions, hot-path, jsonl-records, idempotent-installer, data-root-resolution).
- **Chunk format** per CLAUDE.md spec: Quick Reference, Overview, Key Functions, Code Patterns, Common Issues. Each chunk under 250 lines, ASCII only, cross-linked via "Related chunks" headers.
- **Maintenance contract** wired into Version Workflow step 7: schema, skill, script, or hot-path changes require chunk update in same release.
- **Research write-up** at `docs/research/chunking_implementation_2026-05-06.md` documents adaptation from the Android-targeted base research, 2026 web findings (CLAUDE.md best practices, cAST), and deferred items (subdir CLAUDE.md, AST chunking, vector DB).
- No code, schema, or hook changes. Documentation only.

---

### Changelog v0.4.0 2026-05-06

**Plugin split + global cross-project install + config split + Path A twin.** Breaking change: plugin lives in own dev repo, data dir relocated.

- **Repo split.** Plugin source moved from `Some project\.hae\` (in-project, gitignored) to standalone dev repo at `C:\Projects\HAE\`. Own git history. Habits project no longer carries `.hae/`.
- **Copy-mode installer.** `scripts/install_plugin.ps1` overhauled: `-CopyTo` (default `C:\Plugins\hae`), `-DataDir` (default `%USERPROFILE%\.hae`), `-Mode Copy` (default) or `-Mode Junction` (live dev), `-PersistEnv` to set `$env:HAE_DATA_DIR` user-scope. Robocopy excludes operator data dirs from install copy.
- **Global cross-project data dir.** Captures from every project's Claude Code session funnel into single shared `<dataRoot>` (default `%USERPROFILE%\.hae\`). Records carry `project` + `is_home_project` + `project_weight` for downstream weighting. `weighting.homes` lives in operator user config so capture is project-aware without per-project install.
- **Config split.** `config.default.json` (committed: capture flags, redact patterns, classifier categories, twin gates defaults). `config.user.example.json` (template). `<dataRoot>/config.json` (operator-private: homes, project_overrides, statusline.previous_command). Loader at `scripts/_lib.ps1` deep-merges user over default. Operator-private fields no longer at risk of dev-repo leak.
- **`scripts/_lib.ps1` helper.** New shared library: `Resolve-HaePluginRoot`, `Resolve-HaeDataRoot`, `Get-HaeConfig`, `Get-HaeRawDir`/`StructuredDir`/`ProfileDir`/`StateDir`, `Ensure-HaeDataRoot`. All scripts dot-source `_lib.ps1` and resolve data paths through helper. Hot path benchmarked: capture_prompt.ps1 ~470ms cold, no regression vs pre-refactor (~520ms).
- **All scripts refactored** (12 files): `capture_prompt`, `capture_response`, `twin`, `status`, `classify`, `classify_nightly`, `consolidate`, `backfill_history`, `manage_homes` (writes user config not plugin), `report`, `statusline`, `statusline_universal`. Hardcoded `$haeRoot\prompts\*` literals replaced with helper calls.
- **SKILL.md path templating.** All skill files use `${CLAUDE_PLUGIN_ROOT}` for script paths, `<dataRoot>` for data paths, `$env:HAE_DATA_DIR` for env-var references. No more username-embedded literal paths.
- **Path A twin invocation** (Phase 5 wire). `/release-plan` slash command runs `${CLAUDE_PLUGIN_ROOT}/scripts/twin.ps1 "<q>"` via Bash, composes twin block inline. Subagent spawn via `hae:hae-twin` removed — plugin agent registry not reliably available from main-loop Task. No project mirror needed.
- **Seeds folder dropped.** Habits-specific session logs (`v0.92`, `v0.93`) moved to operator data dir at `<dataRoot>/docs/internal-sessions/`. Auto-classifier patterns + user backfill bootstrap classifier for any user; synthetic universal seeds rejected as classifier-poisoning risk.
- **MIGRATION.md added** — runbook for users migrating from in-project `.hae/` layout.
- Plugin manifest version 0.4.0, phase 5, scope `global-cross-project`.

---

### Changelog v0.3.1 2026-05-05

Process-count + window-flash polish. Eliminate one PowerShell child spawn per statusline render via dot-source pattern. Hide all PowerShell windows on hook + statusline invocations.

- `scripts/statusline.ps1` rewritten as dual-mode: defines `Get-HaeStatusline` function; auto-invokes only when run directly (`$MyInvocation.InvocationName -ne '.'`). When dot-sourced from `statusline_universal.ps1`, runs in the wrapper's process - no child PowerShell spawn.
- `scripts/statusline_universal.ps1` switched from spawning child `& powershell -File statusline.ps1` to `. (Join-Path $PSScriptRoot 'statusline.ps1'); $haeOut = Get-HaeStatusline -HaeRoot $haeRoot`. Net: 1 PS process per render instead of 2.
- `hooks/hooks.json` + `scripts/install_statusline.ps1` add `-NonInteractive -WindowStyle Hidden` to all PowerShell invocations. No more brief console-window flash on each prompt-submit / turn-end / statusline render.
- INSTALL.md adds new "Background processes" section explaining what runs at each trigger point + lifetimes (capture hooks sub-50ms, statusline ~100-300ms, no daemons).
- INSTALL.md placeholders normalized: 14 hardcoded `C:\Projects\My habits\.hae` paths replaced with `<haeRoot>` placeholder + one-line notation block at top.
- README.md status block + phases table refreshed for v0.3.0 (Phases 0-4 done, Phase 5 pending). Layout block expanded from 4 scripts to 14 to reflect actual `scripts/` contents.

---

### Changelog v0.3.0 2026-05-05

Phase 2 complete. Full operator profile (PAEI 30Q + HEXACO Brief 24Q + Custom 8Q + 6 principles + regenerated persona) captured via AskUserQuestion 4-bucket Likert flow. Twin confidence raised from low-medium to medium-high.

**Profile completion**
- `profile/paei.json` - 30 items, scoring formulas applied. Code: **Paei** (Producer dominant; A=4.71, E=4.43, I=4.0 all present at moderate-to-strong levels). Producer-dominant + all roles present = "ambitious shipper who insists on rigor".
- `profile/hexaco.json` - 24 items via 4-bucket Likert (Strongly disagree=1 / Disagree=2 / Agree=4 / Strongly agree=5; neutral=3 not directly capturable but didn't matter for tilt detection). Reverse-keyed items inverted via `6-response`. High: H=4.25, C=3.75, O=4.0. Mid: E=3.25, X=3.0, A=3.5. Low: none.
- `profile/persona.md` regenerated (~5800 chars). 12 implications derived from full PAEI+HEXACO+Custom+Principles synthesis: mockups-first, codex double-check, class-leading benchmarking, forum user research, think-big-make-simple tension, scope-with-evidence pairing, fast-trust review, early-unify abstraction, calculated big bets with surfaced risk, demand verification (informed by 35.5% evidence-axis override behavior), process discipline (informed by A=4.71), team-cohesion-secondary (informed by I=4.0).
- Behavioral calibration validated against 1670 captured records: evidence_demand behavioral avg 4.43 vs self-report custom_evidence_threshold_low=3 (matches direction); risk_appetite behavioral 3.55 vs self-report custom_risk_tolerance=5 (mild self-overestimate, blind spot -1.87/7).

**AskUserQuestion 4-bucket Likert UX**
- Discovered hard limit: AskUserQuestion `options` array capped at 2-4 items by tool schema. Cannot present full 1-7 or 1-5 buttons per item.
- Workaround: 4-bucket Likert mapping (PAEI/Custom: Strongly-disagree=1, Lean-disagree=3, Lean-agree=5, Strongly-agree=7; HEXACO: Strongly-disagree=1, Disagree=2, Agree=4, Strongly-agree=5). Lossy on midpoints but one-fire-per-item, native Claude Code multiple-choice UX.
- Parallel batching: up to 4 questions per AskUserQuestion call + multiple calls per response = 12 items per turn. PAEI 30Q completed in 4 turns, HEXACO 24Q in 2 turns.
- Limitation acknowledged: AskUserQuestion is single-shot, no prev/next nav. For full 1-7 buttons + arrow nav, web wizard (`/hae:profile -Wizard`) deferred to future v0.4+.

**Twin confidence bump**
- Pre-v0.3: signed `low-confidence persona, partial profile`. Twin's V1 month-view-kill answer cited V2-redesign exemplar but lacked PAEI/HEXACO context.
- Post-v0.3: signs `medium-high confidence, full profile v0.3`. Twin can now invoke Producer-bias to break ambiguity, cite Conscientiousness for rollback insistence, cite Openness for "compare to best-in-class" benchmarking.

**Phases roadmap update**
- Phase 2 marked DONE (was partial v0.2.0, custom-only).
- Phases summary now: 0+1+2+3+4 done; only Phase 5 (release-manager loop integration) remains.

---

### Changelog v0.2.1 2026-05-05

Statusline format + color polish + profile UX shift to AskUserQuestion-per-item.

- `scripts/statusline.ps1` - counts format changed `Nr/Ms/Tt` -> `sessions:N raw:M total:T` (labels first, brighter numbers, no slashes). Brand `[hae#X.Y.Z]` switched from `[90m]` (medium gray) to `[38;5;250m]` (light gray, 256-color). Labels (`cap:`, `sessions:`, `raw:`, `total:`, `home:`, `prof:`, `str:`, `next:`) all rendered in `[90m]` (darker gray) with values keeping their accent colors (yellow numbers, green flags, magenta structured count). Hierarchy now reads brand-light -> labels-dark -> values-bright.
- `skills/profile/SKILL.md` - Phase 2 procedure rewritten to use AskUserQuestion per item (was: batch input of 5-10 numbers per message). Native Claude Code multiple-choice UI per item. ~62 tool fires for full battery (30 PAEI + 24 HEXACO + 8 Custom). Cost noted in skill; web-wizard alternative deferred to future `/hae:profile -Wizard` for users who want prev/next nav. Phase 4 (free-form principles) explicitly NOT AskUserQuestion - kept as text input.
- Don't list updated: don't combine items, don't re-fire answered items, AskUserQuestion only for Phase 2.

---

### Changelog v0.2.0 2026-05-05

Phase 3 classifier + Phase 4 twin shipped. Universal statusline. 1670 records classified end-to-end. 75 override exemplars captured. First validated twin demos (V1 month-view kill question; same Q answered materially better with 4x exemplar pool).

**Phase 3 classifier**
- `scripts/classify.ps1` - three subcommands (`state`, `next-batch`, `append`). Handles raw -> structured pipeline, dedup by id across per-session and combined files, state tracking via `state/classified_ids.json`. Stop records auto-skipped, Stop transcripts not classified.
- `skills/classify/SKILL.md` (`/hae:classify`) - single-batch interactive classifier. User's Claude Code model performs classification; helper script handles I/O. 8-category taxonomy (FEATURE/BUG/RESEARCH/RELEASE_OPS/CODE_QA/REFACTOR/META/PLANNING) plus scope_signal, evidence_demand 0-10, risk_appetite 0-10, urgency, intent_verbs, entities, decision_made/rationale, operator_overrode_agent, override_axis, retrieval_text, classifier_version.
- `skills/classify-bulk/SKILL.md` (`/hae:classify-bulk`) - spawns subagent that loops batches in fresh context, returns summary to main without polluting the conversation. Configurable batch size + batch limit. Validated end-to-end across three spawns; 1670 records classified.
- Auto-classifier (5 inline patterns) reduces LLM cycles by 40-55%: `[Request interrupted by user for tool use]`, `Ultraplan terminated...`, `Remote Ultraplan session failed`, single-token approval lexicon (yes/no/continue/next/go/ok/thanks/stop/done/etc), single-character menu-picks. Auto-classified records carry `classifier_version: "v0.1.0-auto"` and write directly to structured store inside `next-batch`.
- `Strip-SystemBlocks` helper removes embedded `<system-reminder>`, `<task-notification>`, `<local-command-*>`, `<command-*>` blocks from mixed prompts before LLM input. Higher signal density per record.
- `MaxPromptChars` truncation (default 2000) on `next-batch` output protects subagent context budget; full text stays in raw store.
- Stats line emitted on stderr (auto-classified count, bucket breakdown, LLM-bound count) so stdout stays valid JSON for piping.
- Override deltas auto-routed to `prompts/structured/overrides.jsonl` in addition to monthly file (high-signal subset for twin few-shot).

**Phase 4 twin**
- `scripts/twin.ps1` - context composer. Loads `profile/persona.md` + `profile/principles.md` verbatim, ranks override exemplars (baseline +5 boost) and topical exemplars (keyword overlap times project_weight), composes markdown system prompt or JSON output. Configurable `-K` (top-K) and `-KOverrides` (override slot count).
- `skills/twin/SKILL.md` (`/hae:twin`) - rewritten from stub. Runs twin.ps1 with user question, surfaces composed context, answers inline as the twin in the prescribed format (Twin take / Why / Risk / Confidence / sign-off). Subagent mode available for deep questions.
- `agents/hae-twin.md` - twin subagent spec retained.
- Validated: same V1 month-view kill question answered with 18 vs 75 overrides produces materially different + better recommendation. Twin's first answer recommended deferring kill 2 versions; second answer (with V2-month-redesign exemplar surfacing) reverses to "kill IS right, with mockup-first + dev-verify chain". Documented in this changelog as the Phase 4 acceptance test.

**Behavioral report**
- `scripts/report.ps1` - aggregates structured store into `state/operator_report_v<N>.md`. Sections: pipeline state, category histogram, project distribution, override-axis breakdown, decision-style behavioral averages (scope, evidence, risk, urgency), recurring entities (top features/libs/files/agents), top override exemplars, persistent themes (subcategories with >=3 records), calibration (behavioral averages vs `profile/custom.json` self-report).
- v0.2 patch: behavioral averages exclude META category records. Pre-fix: avg evidence_demand=2.05, avg risk_appetite=1.83 (washed out by 62% META noise). Post-fix: 4.43 and 3.55 across 654 substantive records, calibration deltas land within ±2/7 (interpretable blind spots, not algorithmic flaw).

**Universal statusline**
- `scripts/statusline.ps1` - HAE-only segment with ANSI colors. Format `[hae#X.Y.Z] | cap:ON | Nr/Ms/Tt | home:X | prof:PHCr* | str:N | next:hint`. Brand gray, ON green, OFF red, counts yellow, !nohome red, override star bright cyan, dividers gray. Disable via `$env:NO_COLOR` or `config.statusline.colors = false`.
- `scripts/statusline_universal.ps1` - wraps any pre-existing `statusLine.command` (OMC, gstack, custom, none) on row 1, HAE on row 2. Forwards stdin to wrapped command via `Process` API. Stores previous command in `config.statusline.previous_command` so universal install doesn't lose existing HUD.
- `scripts/install_statusline.ps1` - installs/uninstalls universal wrapper. Captures current `statusLine.command`, switches to wrapper. Idempotent. `-Uninstall` restores captured previous.
- `skills/statusline/SKILL.md` (`/hae:statusline`) - manage statusline integration: preview, install standalone, install universal, restore.
- Statusline reads count via dedupe-by-id (per-session + combined files no longer double-count after `/hae:consolidate`).

**Plugin install fixes (after Claude Code validation errors)**
- `hooks/hooks.json` schema corrected: matcher object containing nested `hooks` array (was flat array, failed Claude Code schema validation).
- `plugin.json` validation: `author` must be object not string; `homepage` requires valid URL or absent (was `"local"`).
- Skill `name:` field stripped of `hae:` prefix (Claude Code auto-namespaces by plugin name; double-namespacing produced ugly `hae:hae-classify` slugs). Skill directories renamed `hae-<name>/` -> `<name>/` to match.
- All `.ps1` em-dash characters replaced with `-` (Russian-locale Windows PowerShell mangles em-dash to mojibake breaking parser).

**Backfill home-match fix**
- Anthropic project-dir slug encoding is lossy (`-` represents both `\` and ` `). `Decode-ProjectDir` produced wrong path (`C:\Projects\My\habits` vs real `C:\Projects\My habits`), missing home prefix match. Fix: also try slug-form match by encoding home path to slug (lowercase, replace `[:\\/ ]` with `-`, no leading dash) and comparing against the directory slug. After patch + adding `C:\Users\Magerash\PycharmProjects\My habits` as second home prefix: 1248 home / 401 other (was 5 / 1641).

**Phase 2 partial**
- `profile/custom.json` - 8 anchored decision-style ratings (risk_tolerance, scope_bias, evidence_threshold_low, abstraction_tolerance, refactor_appetite, review_strictness, research_depth, parallelism_comfort) + summary sentence.
- `profile/principles.md` - 6 verbatim operator principles (mockups necessary, codex self-review, best in class, reddit user research, think big, make it simple).
- `profile/persona.md` - generated from custom.json + principles. Includes per-axis "Implications for the twin" (mockups-first, codex double-check, class-leading benchmarking, forum user research, think-big-make-simple tension, scope-with-evidence pairing, fast-trust review, early-unify abstraction, calculated-big-bets-with-risk-surfaced).
- PAEI 30Q + HEXACO 24Q deferred. Twin signs as `low-confidence persona, partial profile`.

**Status dashboard fixes**
- `scripts/status.ps1` extracted from inline skill procedure. Single source of truth (matches manage_homes pattern).
- Variable name collision fix: `$home` reserved by PowerShell, renamed to `$homeCount`.
- Dedup by `id` across per-session + combined files (was double-counting after `/hae:consolidate`).
- New section: backfill state, plugin enable status, weighting.homes list with `[path]` / `[name]` tags.

**Pipeline state at v0.2.0 ship**
- Raw records: 1670 (1635 backfill + 35 live; ~30 days of operator history).
- Structured records: 1670 (100% classified).
- Override exemplars: 75 (4.5% override rate). Axis breakdown: approach 54.8%, evidence 35.5%, priority 8.1%, scope 1.6%.
- Top projects: habits=1241, Findar=253, buy=93, Splitly=29, bot=15.
- Profile: custom + 6 principles + persona. PAEI + HEXACO pending.
- Statusline: live, multi-row, OMC + HAE composed.
- Plugin install: local marketplace at `~/.claude/plugins/marketplaces/hae-local/` (junction to repo). One-command installer + uninstaller.

---

### Changelog v0.1.0 2026-05-05

First versioned snapshot. Phase 0 scaffold + Phase 1 live capture + Phase 2 questionnaire materials + plugin install via local marketplace.

**Plugin packaging**
- `.claude-plugin/plugin.json` manifest (name, version, displayName, description, author object, license, tags)
- `hooks/hooks.json` with `${CLAUDE_PLUGIN_ROOT}` placeholder, matcher + nested hooks-array schema
- `scripts/install_plugin.ps1` - one-command install via auto-created local marketplace at `~/.claude/plugins/marketplaces/hae-local/`. Idempotent; supports `-PluginPath`, `-MarketplaceName`, `-PluginName`, `-Uninstall`. Backs up settings.json + registry files with timestamp + GUID suffix.
- `scripts/install_hooks.ps1` - legacy direct-hook installer (capture only, no skills); kept for users who don't want full plugin install.

**Capture pipeline (Phase 1)**
- `scripts/capture_prompt.ps1` - UserPromptSubmit hook. Reads stdin as raw UTF-8 bytes (encoding-independent). Redacts secrets (GitHub PATs, OpenAI keys, AWS, JWT, PEM, DB URLs with creds, emails, generic password/token assignments). Hashes paths + keeps last 2 segments by default (privacy.store_full_paths = false). Computes is_home_project + project_weight against weighting.homes list. Per-session direct write to `prompts/raw/<UTC-date>__<sid8>.jsonl` (single writer = no append race, no spool, no scheduler).
- `scripts/capture_response.ps1` - Stop hook (gated by capture.include_response). Reads transcript tail (50 lines) inline, extracts last assistant text, applies same redact + path-PII pipeline, writes paired record.
- `scripts/consolidate.ps1` - lazy merger of per-session files into combined `<date>.jsonl`. Optional `-Cleanup` to delete sources after merge. Idempotent.
- `scripts/backfill_history.ps1` - one-shot importer of historical Claude Code session transcripts from `~/.claude/projects/`. Decodes Anthropic's project-dir slug back to cwd. Idempotent via `state/backfilled_sessions.json`. Records carry `source: "backfill"` and `bf-` filename prefix.

**Project weighting**
- `weighting.homes` array (path prefix or basename entries) replaces hardcoded single-project path. Default empty.
- `scripts/manage_homes.ps1` - subcommands `list | add | remove | auto-detect [-Apply]`. Auto-detect ranks projects by record count, suggests path or basename entry depending on whether full cwd survived privacy mode.
- Capture re-reads config on every fire; weight changes take effect with no Claude Code restart.

**Privacy + safety**
- 25 redact regexes covering common secret families.
- Path PII control via `privacy.store_full_paths` (default false). Stores SHA-256 16-hex hash + last N path segments.
- All capture scripts wrap everything in try/catch, exit 0 on every error path - hot path can never block Claude Code.

**Schema (`schema/record.schema.json`)**
- Per-record fields: id, ts, event, session_id, transcript_path/hash/tail, cwd/hash/tail, project, is_home_project, project_weight, source, prompt|response, prompt_chars|response_chars, hae_phase, permission, plus structured-record fields (category, scope_signal, evidence_demand, risk_appetite, decision_made, decision_rationale, operator_overrode_agent, override_axis, classifier_version, persona_version, retrieval_text, embedding nullable).

**Skills (Phase 2 + ops)**
- `skills/profile/` - interactive PAEI + HEXACO Brief + custom decision-style + free-form principles runner. Generates `profile/persona.md` synthesizing all four instruments.
- `skills/status/` - dashboard (capture stats, profile completeness, hook install state, backfill state).
- `skills/home/` - wrapper around `manage_homes.ps1`.
- `skills/backfill/` - wrapper around `backfill_history.ps1`.
- `skills/consolidate/` - wrapper around `consolidate.ps1`.
- `skills/classify/` - Phase 3 classifier spec (script implementation pending).
- `skills/twin/` - Phase 4 emulator spec.

**Tests (questionnaires)**
- `tests/paei.md` - 30-item PAEI (Adizes Producer / Administrator / Entrepreneur / Integrator).
- `tests/hexaco_brief.md` - 24-item HEXACO Brief (Honesty-Humility, Emotionality, eXtraversion, Agreeableness, Conscientiousness, Openness; 4 items per factor with reverse-keying).
- `tests/custom_decision.md` - 8 anchored items (risk tolerance, scope bias, evidence threshold, abstraction tolerance, refactor appetite, review strictness, research depth, parallelism comfort) + free-form principles prompt.

**Twin agent (Phase 4 spec)**
- `agents/hae-twin.md` - subagent that loads persona + principles + override exemplars, mirrors operator decision style, signs answers with explicit emulation disclaimer.

**Statusline**
- `scripts/statusline.ps1` - HAE-only segment for Claude Code statusLine. Format: `[hae#0.1.0] cap:ON 12r/3s/127t home:X prof:PHCr* str:N next:hint`. Drains stdin to avoid stalling parent. Self-contained, reads state from disk only.
- `scripts/statusline_with_omc.ps1` - wrapper that runs OMC HUD + HAE segment, joined with " | ". Captures stdin once, forwards to OMC.
- `skills/statusline/` - manage statusline integration (preview, install standalone, install wrapper, restore, uninstall).

**Bootstrap data**
- `seeds/sessions/` - 2 hand-written session prompt logs (24 + 9 prompts) imported from prior `research/human-agent/` location.

**Documentation**
- `README.md` - phases, layout, capture mechanics, weighting, privacy.
- `INSTALL.md` - plugin install (one command) + legacy direct-hooks fallback + backfill walkthrough.
- `CLAUDE.md` - AI assistant instructions for working on HAE.
- This changelog.

**Verified end-to-end (2026-05-05)**
- Plugin loads: 1 plugin, 7 skills, 1 agent, 2 hooks, 0 errors.
- Live capture fires on real Claude Code prompts; record lands in `prompts/raw/<date>__<sid8>.jsonl` within 1s.
- Russian + em-dash characters preserved through stdin -> JSON parse -> redact -> write.
- Secret patterns redact correctly (verified with synthetic GitHub PAT in test payload).
- Privacy mode null's full cwd / transcript_path while preserving hash + tail.
- `manage_homes.ps1 auto-detect -Apply` adds basename-match home from privacy-scrubbed records and subsequent captures match correctly.
- Idempotent re-install of plugin: junction up to date, registries re-written, no duplication.

---
