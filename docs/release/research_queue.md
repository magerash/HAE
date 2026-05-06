# Research Queue

Hypotheses needing analysis before RICE confidence is high enough to scope.

## Priority legend

- **RED** - blocking next-release scope; research within 1 week
- **YELLOW** - blocking later release; research within 1 month
- **GREEN** - exploratory; research when capacity allows

## Active

| ID | Hypothesis | Priority | Question for RA | Output target |
|----|------------|----------|-----------------|---------------|
| H14 | Forum user-pain hypothesis hunt | RED | What pain points do real Claude Code / agent-observability users report on reddit + HN? Which 5+ map to HAE's domain? Which are addressable in v0.6.0 scope? | docs/research/forum_userpain_2026-05-XX.md w/ source thread links + HAE-relevance score per pain |
| H13 | Persistent PS host for capture hot path | RED | Can a single PowerShell process serve N capture hook fires without state corruption on Windows 5.1? Latency budget achievable? Failure recovery cost? | docs/research/persistent_ps_host_2026-05-XX.md with go/no-go + RICE C revision |
| H10 | Twin semantic retrieval | YELLOW | Which embedding model fits offline + Windows + low cold-start? sqlite-vec vs lancedb vs flat numpy? Index size for 1670 records? | docs/research/twin_semantic_retrieval_2026-05-XX.md |
| H4  | AST chunking (cAST) for code chunks | YELLOW | Does cAST improve chunk retrieval quality for HAE-style markdown + .ps1 hybrid corpus, or is current line-bounded approach sufficient? | docs/research/ast_chunking_eval_2026-05-XX.md |
| H5  | Vector DB for chunk + exemplar retrieval | GREEN | Same engine for chunks + exemplars, or separate stores? Embedded vs server? | docs/research/vector_db_choice_2026-05-XX.md |
| H11 | Phase 6 cross-project intelligence dashboard | GREEN | What dashboards would the operator actually open weekly? Entity drift, override-axis trends, project velocity? | docs/research/phase6_dashboard_2026-05-XX.md |

## Queue rules

- RA picks highest-priority RED item first; emits one research file per spawn
- Research output must include revised RICE Confidence + Effort estimate
- After research, update rice_backlog.md with new score and move from `research` -> `scoped`/`idea`

## Recently completed research

(none yet - queue bootstrapped 2026-05-07)
