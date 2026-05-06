# Project Weighting

## Quick Reference

- Config: `weighting.{homes, home_weight, other_weight, project_overrides}`
- Apply: `scripts/capture_prompt.ps1` (lines ~43-67)
- Manage: `scripts/manage_homes.ps1 list|add|remove|auto-detect` (and `/hae:home`)
- Used by: classifier (passes through `project_weight`), twin ranker (multiplier in relevance score)
- Related chunks: `features/capture.md`, `architecture/twin-pipeline.md`

## Overview

Each captured record carries `project_weight` that biases retrieval toward signal from the operator's home projects. Records from random one-off projects don't drown out the projects the operator actually owns.

## Match rules

For each entry in `weighting.homes`:

| Entry shape | Match against | Logic |
|-------------|---------------|-------|
| Contains `/` or `\` | full `cwd` (lowercased) | path-prefix: `cwd == h` or `cwd startswith h+'/'` or `cwd startswith h+'\'` |
| No slash | last path segment of `cwd` | basename match (case-insensitive) |

First match wins -> `is_home_project = true`, `project_weight = home_weight`.

If no match, check `project_overrides[<basename>]` (per-project explicit weight). Otherwise `project_weight = other_weight`.

## Defaults

```jsonc
{
  "weighting": {
    "homes": [],
    "home_weight": 1.0,
    "other_weight": 0.3,
    "project_overrides": {}
  }
}
```

Empty `homes` -> nothing is home.

## Auto-detect

`scripts/manage_homes.ps1 auto-detect` scans existing `prompts/raw/*.jsonl`, ranks projects by record volume, suggests top-N as homes. Operator confirms before write.

## Adding a home

```powershell
# By basename (matches any cwd ending in this folder name)
.\scripts\manage_homes.ps1 add HAE

# By path prefix (only matches this exact tree)
.\scripts\manage_homes.ps1 add C:\Projects\HAE
```

## Use in twin

`twin.ps1` Get-RelevanceScore multiplies keyword-match count by `project_weight`. So a record from a 1.0-weight home project counts ~3.3x more than a 0.3-weight stranger project.

## Common Issues

- **Too many homes** -> weighting flattens (everything is 1.0). Keep homes list short; use `project_overrides` for the long tail.
- **Path-prefix entry for `C:\` matches everything**: don't add root-level prefixes.
- **Case sensitivity**: matching is lowercased on both sides. Don't rely on case to disambiguate.
