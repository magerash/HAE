# Redaction

## Quick Reference

- Patterns: `capture.redact_patterns` in `config.default.json`
- Applied in: `scripts/capture_prompt.ps1` (line ~34) and `scripts/capture_response.ps1`
- Replacement: `[REDACTED]`
- Related chunks: `features/capture.md`, `patterns/jsonl-records.md`

## Overview

Every prompt + response goes through a regex redaction pass before write. If a secret family is missing, raw JSONL records will leak it permanently. Add the pattern before turning on capture for a new project.

## Default coverage

- GitHub PATs (`ghp_...`, `github_pat_...`)
- OpenAI API keys (`sk-...`)
- AWS access keys (`AKIA...`) and secret keys (40-char base64-ish)
- JWTs (header.payload.sig)
- PEM blocks (`-----BEGIN ... -----END`)
- DB URLs with creds (`postgres://user:pass@...`, `mongodb://...`)
- Email addresses
- Generic `password|token|secret = "..."` assignments

## Adding a pattern

Edit `config.default.json` (or user config to override per-machine):

```jsonc
{
  "capture": {
    "redact_patterns": [
      "...existing...",
      "(?i)slack-token-[a-z0-9-]{20,}"
    ]
  }
}
```

Patterns are .NET regex. Test against a real example before shipping. Anchor where possible to reduce false positives.

## Privacy contract

- Redaction runs **before** write. No "redact later" path.
- Path PII is handled separately via `privacy.store_full_paths` -> hash + tail. See `patterns/jsonl-records.md`.
- All scripts that read raw records (classify, twin, status) should treat already-redacted text as authoritative; don't try to "recover" it.

## Common Issues

- **Pattern too greedy** -> swallows normal text. Anchor with explicit prefix or character class.
- **Pattern misses Unicode**: PowerShell `[regex]::Replace` is Unicode-aware; ensure no `(?-u)` flag.
- **Pattern updated, old records still leaky**: redaction is forward-only. To scrub history, add a one-shot `scrub.ps1` (not yet built) and re-run after pattern change. Track in changelog.
