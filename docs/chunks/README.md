# HAE Documentation Chunks

Progressive-disclosure chunks for AI assistants working in this repo. Each chunk is a focused, retrieval-friendly unit (under 500 lines) covering one topic. Root `CLAUDE.md` stays small; specifics live here.

## Layout

```
docs/chunks/
  README.md             this file
  INDEX.md              codebase index (files <-> features <-> chunks)
  architecture/         system-level views (pipelines, layers)
  features/             one chunk per user-facing feature / skill
  patterns/             cross-cutting code patterns + invariants
```

## When to read which chunk

- Editing capture path -> `features/capture.md`, `patterns/hot-path.md`, `patterns/jsonl-records.md`
- Editing classifier -> `features/classify.md`, `architecture/classify-pipeline.md`
- Editing twin / persona -> `features/twin.md`, `features/profile.md`, `architecture/twin-pipeline.md`
- Editing installer / hooks wiring -> `features/install.md`, `patterns/idempotent-installer.md`
- Editing config / data root -> `patterns/data-root-resolution.md`
- New PowerShell script -> `patterns/powershell-conventions.md`
- Need file location -> `INDEX.md`

## Chunk format

Each chunk follows:

```markdown
# Title

## Quick Reference
key files, related chunks, schema refs

## Overview
2-4 sentences: what + why

## Key Functions / Components
table or list

## Code Patterns / Invariants
what to copy, what not to break

## Common Issues
debug tips, gotchas
```

## Maintenance rules

- New skill, script, or script behavior change -> create or update the matching feature chunk in the same change.
- Schema or hot-path change -> update `patterns/jsonl-records.md` or `patterns/hot-path.md`.
- Cross-link related chunks at the top (Quick Reference) instead of duplicating content.
- Keep each chunk under 500 lines. Split if it grows.
- One topic per chunk. If two topics keep co-changing, merge them; if a chunk grows too many sub-sections, split.
- ASCII only, no emoji, no em-dashes (Windows PowerShell 5.1 mangles them on non-Latin locale).
