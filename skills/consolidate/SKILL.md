---
name: consolidate
description: Merge per-session HAE raw files (prompts/raw/<date>__<sid>.jsonl) into combined daily files (prompts/raw/<date>.jsonl). Optional, lazy. Use when user invokes /hae:consolidate, asks "consolidate HAE", "merge per-session files", or before /hae:classify on a large backlog.
---

# /hae:consolidate — merge per-session files

Per-session files are first-class storage. This skill produces a combined dated file as a convenience for downstream consumers (classifier, twin few-shot retriever, ad-hoc grep).

## Procedure

1. Run: `powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Projects\My habits\.hae\scripts\consolidate.ps1"`
2. (Optional) `-Cleanup` flag deletes per-session sources after successful merge — only suggest if user asks for it
3. (Optional) `-Date 2026-05-04` flag limits to one day
4. Capture output (per-day appended counts + total)

## Output format

```
HAE consolidate done.
- Days processed:  N
- Records merged:  N
- Per-session sources kept (use -Cleanup to delete after merge)
```

## Don't

- Don't run with `-Cleanup` unless the user explicitly asked. Sources are cheap; combined file is convenience.
- Don't run if no per-session files exist — surface the empty state instead
