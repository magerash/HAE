# Cost tracker (`/hae:cost`)

## Quick Reference

- Slash command: `/hae:cost`
- Script: `plugins/hae/scripts/cost.ps1`
- Skill: `plugins/hae/skills/cost/SKILL.md`
- Helper: `plugins/hae/scripts/_metrics_lib.ps1` (`Format-Sparkline`, `Get-WeekStart`)
- Schema fields: `tokens_in`, `tokens_out`, `tokens_cache_read`, `tokens_cache_create`, `model` (all nullable; added v0.6.0)
- Source research: `docs/research/h18_token_source_2026-05-10.md`
- Related chunks: `features/capture.md`, `features/profile.md`, `patterns/jsonl-records.md`

## Overview

H18 (RICE 14.4) shipped in v0.6.0. Track weekly Claude Code token spend per project, with sparkline + per-tier breakdown. Trend quality, not billing quality.

Pipeline:

```
capture_response.ps1 (Stop hook)
  -> reads transcript tail (last 50 lines)
  -> extracts message.usage + message.model from LAST assistant record with usage data
  -> writes tokens_in/out/cache_read/cache_create + model into raw JSONL record

cost.ps1
  -> scans <dataRoot>/prompts/raw/*.jsonl
  -> filters records w/ token fields (post-v0.6.0)
  -> groups by ISO week + project + model tier
  -> applies pricing table (Opus/Sonnet/Haiku 2026 rates)
  -> emits weekly table + per-project + per-tier + sparkline
```

## Key Functions

### capture_response.ps1 (Stop hook extension)

In the same loop that finds the last assistant text, also extract `$entry.message.usage` + `$entry.message.model` when present. Per H18 research, every API-response assistant record has `message.usage` inline. The 4 core fields are stable across observed model versions.

```powershell
foreach ($line in $tail) {
    $entry = $line | ConvertFrom-Json
    if ($entry.type -eq 'assistant') {
        # ... existing text extraction ...
        try {
            $u = $entry.message.usage
            if ($null -ne $u) {
                if ($null -ne $u.input_tokens)               { $tokensIn          = [int]$u.input_tokens }
                if ($null -ne $u.output_tokens)              { $tokensOut         = [int]$u.output_tokens }
                if ($null -ne $u.cache_read_input_tokens)    { $tokensCacheRead   = [int]$u.cache_read_input_tokens }
                if ($null -ne $u.cache_creation_input_tokens){ $tokensCacheCreate = [int]$u.cache_creation_input_tokens }
            }
            $m = $entry.message.model
            if (-not [string]::IsNullOrWhiteSpace([string]$m)) { $modelId = [string]$m }
        } catch { }
    }
}
```

Latency impact: zero (same loop, additional field reads with try/catch guard).

### cost.ps1 - aggregation + pricing

`Get-Tier($modelId)` infers tier from substring match: `haiku` -> haiku, `sonnet` -> sonnet, default -> opus. Conservative high-estimate.

`Get-RecordCost($r)` multiplies token counts by per-1M pricing for the inferred tier. Sums input/output/cache_read/cache_create.

Weekly aggregation uses `Get-WeekStart` from `_metrics_lib.ps1` (Monday 00:00 UTC). Sparkline uses `Format-Sparkline` (5 grades: ` . - = # *`).

## Code Patterns

### Schema additive contract

Per CLAUDE.md "no silent schema breaks": all five new fields are optional (`["integer", "null"]`) with descriptions referencing v0.6.0 add-date. Old records remain valid; new records carry data when transcript yields it.

Schema `$id` bumped from `hae/record.schema.json` to `hae/record.schema.json#v0.6.0` for traceability.

### Pricing as data (not config)

Hardcoded pricing table in `cost.ps1`. Operator can override later via `config.user` if needed. Default: Anthropic 2026 published rates.

```powershell
$pricing = @{
    'opus'   = @{ input = 15.00; output = 75.00; cache_read = 1.50; cache_create = 18.75 }
    'sonnet' = @{ input = 3.00;  output = 15.00; cache_read = 0.30; cache_create = 3.75 }
    'haiku'  = @{ input = 0.80;  output = 4.00;  cache_read = 0.08; cache_create = 1.00 }
}
```

## Common Issues

- **All weeks show $0**: no records with token data yet. Capture started writing token fields 2026-05-10+. Wait for sessions to accumulate.
- **Cost looks low vs Anthropic console**: per H18 limitation, capture reads only the last assistant record in the transcript tail. Long sessions w/ many turns understated. For audit-grade accuracy, layer Approach B (background full-transcript scan) - planned v0.7.0+.
- **Unknown model defaulting to Opus pricing**: intentional conservative estimate. If you use a non-Opus tier and want accurate numbers, ensure `message.model` is populated and matches a substring (`haiku`, `sonnet`).
- **Subagent spend missing**: subagents have separate transcript files; main session's Stop hook only sees its own transcript. Subagent capture is separate v0.7.0+ work.
- **Negative or weird week count**: ISO week boundaries are Monday 00:00 UTC. If your session straddles midnight UTC, it may land in the next week.

## Related Research

- `docs/research/h18_token_source_2026-05-10.md` - the source-of-truth research that selected Approach A and confirmed schema-additive feasibility. Operator should re-read before any v0.7.0 cost-skill upgrades.
