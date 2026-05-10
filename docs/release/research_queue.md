# Research Queue

Hypotheses needing analysis before RICE confidence is high enough to scope.

## Priority legend

- **RED** - blocking next-release scope; research within 1 week
- **YELLOW** - blocking later release; research within 1 month
- **GREEN** - exploratory; research when capacity allows

## Active

| ID | Hypothesis | Priority | Question for RA | Output target |
|----|------------|----------|-----------------|---------------|
| H17 | Plugin distribution patterns | RED | How do top Claude Code plugins (gstack, oh-my-claudecode, codex plugin) structure their repos + marketplace.json + install UX? What's the cross-platform pattern? What's the OSS-publish playbook? | docs/research/plugin_distribution_2026-05-XX.md w/ side-by-side comparison table + recommended layout for HAE H1 + H12 |
| H14 | Forum user-pain hypothesis hunt | RED | What pain points do real Claude Code / agent-observability users report on reddit + HN? Which 5+ map to HAE's domain? Which are addressable in v0.6.0 scope? | docs/research/forum_userpain_2026-05-XX.md w/ source thread links + HAE-relevance score per pain |
| H13 | Persistent PS host for capture hot path | DONE | Can a single PowerShell process serve N capture hook fires without state corruption on Windows 5.1? Latency budget achievable? Failure recovery cost? | docs/research/h13_persistent_ps_host_2026-05-10.md |
| H16 | Cross-platform install (macOS/Linux) | YELLOW | What changes needed to make HAE work on macOS + Linux? Bash/zsh equivalent for capture hooks? Path resolution (XDG_DATA_HOME vs %USERPROFILE%)? Which scripts are PowerShell-specific vs portable? Effort to port vs rewrite in node/python? | docs/research/cross_platform_install_2026-05-XX.md w/ port plan + RICE Effort revision |
| H15 | Codex CLI integration | GREEN | Does Codex CLI expose UserPromptSubmit + Stop equivalent hooks? If yes, contract shape? If no, what's the wrapper alternative (PTY logging, daemon proxy)? Same data dir + schema works for cross-CLI captures? | docs/research/codex_integration_2026-05-XX.md w/ go/no-go + integration spec |
| H10 | Twin semantic retrieval | DONE | Which embedding model fits offline + Windows + low cold-start? sqlite-vec vs lancedb vs flat numpy? Index size for 1670 records? | docs/research/h10_semantic_retrieval_2026-05-10.md |
| H4  | AST chunking (cAST) for code chunks | YELLOW | Does cAST improve chunk retrieval quality for HAE-style markdown + .ps1 hybrid corpus, or is current line-bounded approach sufficient? | docs/research/ast_chunking_eval_2026-05-XX.md |
| H5  | Vector DB for chunk + exemplar retrieval | GREEN | Same engine for chunks + exemplars, or separate stores? Embedded vs server? | docs/research/vector_db_choice_2026-05-XX.md |
| H11 | Phase 6 cross-project intelligence dashboard | GREEN | What dashboards would the operator actually open weekly? Entity drift, override-axis trends, project velocity? | docs/research/phase6_dashboard_2026-05-XX.md |

## Queue rules

- RA picks highest-priority RED item first; emits one research file per spawn
- Research output must include revised RICE Confidence + Effort estimate
- After research, update rice_backlog.md with new score and move from `research` -> `scoped`/`idea`

## Recently completed research

| ID | Hypothesis | Completed | Output | Impact |
|----|-----------|-----------|--------|--------|
| H17 | Plugin distribution patterns | 2026-05-07 | docs/research/plugin_distribution_2026-05-07.md | H1 RICE 11.2->28.8, H12 RICE 2.25->7.2, H16 effort 2w->4w |
| H14 | Forum user-pain hypothesis hunt | 2026-05-07 | docs/research/forum_userpain_2026-05-07.md | Added H18/H19/H20/H21 as v0.6.0 candidates |
| H10 | Twin semantic retrieval | 2026-05-10 | docs/research/h10_semantic_retrieval_2026-05-10.md | BUILD verdict; fastembed+numpy recommended; RICE 5.0->5.6 (C 0.5->0.7, E 2.0->2.5); candidate-v0.8 |
| H13 | Persistent PS host for capture hot path | 2026-05-10 | docs/research/h13_persistent_ps_host_2026-05-10.md | PARK persistent-host (RICE 4.0->1.5); quick win async:true identified (0 effort); Alt-B Go binary RICE 5.6 candidate-v0.9 |
