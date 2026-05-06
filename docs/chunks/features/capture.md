# Capture (Live)

## Quick Reference

- Hook script: `scripts/capture_prompt.ps1` (UserPromptSubmit) + `scripts/capture_response.ps1` (Stop)
- Hook bindings: `hooks/hooks.json`
- Output: `<dataRoot>\prompts\raw\<UTC-date>__<sid8>.jsonl`
- Config: `capture.{enabled,max_prompt_chars,redact_patterns,include_response}`
- Related chunks: `architecture/capture-pipeline.md`, `features/redaction.md`, `features/weighting.md`, `patterns/hot-path.md`, `patterns/jsonl-records.md`

## Overview

Live capture writes one JSONL line per prompt and one per assistant response (when enabled). Hooks run synchronously inside Claude Code's event loop, so they must finish in <50ms and never raise.

## Key behaviors

- **One writer per file**: filename `<date>__<sid8>.jsonl` is unique per session, so single-writer guarantee holds without locks. Don't introduce shared write paths.
- **UTF-8 no-BOM**: write with `[System.IO.File]::AppendAllText($file, $line + "`n", [System.Text.UTF8Encoding]::new($false))`. Don't use `Out-File` (defaults to UTF-16 LE in PS 5.1).
- **Stdin reading**: read raw bytes via `Console.OpenStandardInput().CopyTo($ms)`, then `Encoding.UTF8.GetString`. Never use `[Console]::In.ReadToEnd()` - console encoding may mangle non-ASCII.
- **No async / no background jobs**: keep capture synchronous. A hung background job blocks Claude Code on its next event.

## Toggle capture

Edit user config `<dataRoot>\config.user.json`:

```jsonc
{
  "capture": {
    "enabled": false
  }
}
```

User config merges over `config.default.json` from the repo. Read on every hook fire - no restart needed.

## Adding a new captured field

1. Add field to `schema/record.schema.json`.
2. Add field to record builder in `capture_prompt.ps1` (and `capture_response.ps1` if relevant).
3. Bump `phase` if needed; bump schema `$id` if breaking.
4. Update `architecture/capture-pipeline.md` and `patterns/jsonl-records.md`.
5. Smoke test: type a prompt, confirm new field appears in raw JSONL.

## Common Issues

- **No file produced**: check `Resolve-HaeDataRoot` returned a path that exists; check `capture.enabled`; check `Get-HaeRawDir` builds expected path; tail any stderr.
- **Stop hook fires but no record**: `capture.include_response = false` (default in some configs).
- **Mojibake on Cyrillic prompts**: writer used wrong encoding. Confirm UTF-8 no-BOM.
- **Truncation surprises**: `capture.max_prompt_chars` cap ('...[TRUNCATED]' suffix); raise it cautiously - long prompts inflate raw store.
