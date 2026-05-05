# HAE Changelog

Format: `### Changelog vX.Y.Z YYYY-MM-DD`. Style: professional, minimalistic. One bullet per shipped change.

---

### Changelog v0.4.0 2026-05-06

**Plugin split + global cross-project install + config split + Path A twin.** Breaking change: plugin lives in own dev repo, data dir relocated.

- **Repo split.** Plugin source moved from `C:\Projects\My habits\.hae\` (in-project, gitignored) to standalone dev repo at `C:\Projects\HAE\`. Own git history. Habits project no longer carries `.hae/`.
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
