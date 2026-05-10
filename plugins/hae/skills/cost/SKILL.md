---
name: cost
description: Show HAE token-spend tracker for last N weeks. Aggregates captured token usage by week and project, applies Anthropic published pricing (Opus/Sonnet/Haiku tiers), produces sparkline + table. Use when user invokes /hae:cost, asks "how much did Claude Code cost me", "weekly token spend", or wants to track LLM cost trends.
---

# /hae:cost - Token spend tracker

Reads HAE-captured token-usage records (added v0.6.0 via H18 schema additive) and produces a weekly cost summary. Trend quality, not billing quality.

## Default

Run `${CLAUDE_PLUGIN_ROOT}/scripts/cost.ps1` (no args). Shows trailing 8 weeks: total cost, weekly sparkline, weekly breakdown table, per-project breakdown, per-model-tier breakdown.

```
powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}/scripts/cost.ps1"
```

## Options

| Flag | Default | Effect |
|------|---------|--------|
| `-Weeks <N>` | 8 | Trailing window length in weeks |
| `-Project <name>` | (none) | Filter to single project (matches `record.project` exactly) |
| `-Json` | off | Emit machine-readable JSON instead of human-friendly tables |

Examples:
```
powershell -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/scripts/cost.ps1" -Weeks 4
powershell -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/scripts/cost.ps1" -Project habits
powershell -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/scripts/cost.ps1" -Json
```

## What it shows

- **Total cost (USD, est.):** sum across the window. Model tier inferred from `record.model` (defaults to Opus pricing for unknown models).
- **Weekly sparkline:** ASCII grades (` . - = # *`); recent on right.
- **Weekly breakdown:** cost + records + 4 token columns per week.
- **Per-project (top 15):** cost + records + total tokens, sorted by cost descending.
- **Per-model-tier:** cost + records by Opus / Sonnet / Haiku.

## Pricing model (per 1M tokens, USD)

| Tier   | input | output | cache_read | cache_create |
|--------|-------|--------|------------|--------------|
| opus   | 15.00 | 75.00  | 1.50       | 18.75        |
| sonnet | 3.00  | 15.00  | 0.30       | 3.75         |
| haiku  | 0.80  | 4.00   | 0.08       | 1.00         |

Anthropic published rates 2026. Cache read priced at ~10% of input; cache create at ~125% (5min ephemeral).

## Coverage

- Only records w/ token fields (captured 2026-05-10+ via H18 schema additive).
- Records before that date show `tokens_in = null` and are excluded.
- Long sessions w/ many turns understated (per H18 limitation: capture reads only the last assistant record in the 50-line transcript tail).
- Subagent transcripts not yet covered (separate file path; planned for v0.7.0+).

## When to use

- Weekly: check spend trend; spot model-change cost spikes.
- Per-project: identify which work is most expensive; calibrate against value delivered.
- Pre-OSS-publish (H12): document personal cost as social proof / honesty signal.

## Cross-references

- `/hae:status` (Override-rate drift section) - if cost spikes correlate with override-rate spikes, investigate Anthropic-side change.
- `docs/research/h18_token_source_2026-05-10.md` - source-of-truth research on what gets captured and why.
- `docs/chunks/features/cost.md` - implementation details + accuracy caveats.
