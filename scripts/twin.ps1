# HAE - twin context composer
# Given a question, builds the system-prompt context for the operator's twin agent:
#   - persona.md (verbatim)
#   - principles.md (verbatim)
#   - top-K override exemplars (highest-signal training data; baseline boosted)
#   - top-K topical exemplars (keyword-relevance scored, project-weighted)
#
# Output modes:
#   default     : formatted markdown ready to paste into a subagent system prompt
#   -JsonOutput : structured JSON for programmatic consumers
#
# Usage:
#   twin.ps1 "should we add embeddings to twin retrieval now or ship v1 keyword-match first?"
#   twin.ps1 -K 8 -KOverrides 5 "release scope question..."

[CmdletBinding()]
param(
    [Parameter(Position=0, Mandatory=$true)] [string]$Question,
    [int]$K = 6,
    [int]$KOverrides = 3,
    [switch]$JsonOutput
)

$ErrorActionPreference = 'Stop'

$haeRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$structDir = "$haeRoot\prompts\structured"
$profDir   = "$haeRoot\profile"

# Load persona + principles
$persona = ''
if (Test-Path "$profDir\persona.md") { $persona = Get-Content "$profDir\persona.md" -Raw -Encoding UTF8 }
$principles = ''
if (Test-Path "$profDir\principles.md") { $principles = Get-Content "$profDir\principles.md" -Raw -Encoding UTF8 }
$personaExists = -not [string]::IsNullOrWhiteSpace($persona)

# Load structured records (skip overrides.jsonl - handled separately)
$structured = New-Object System.Collections.ArrayList
Get-ChildItem $structDir -Filter '*.jsonl' -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'overrides.jsonl' } | ForEach-Object {
    Get-Content $_.FullName -Encoding UTF8 -ErrorAction SilentlyContinue | ForEach-Object {
        if ([string]::IsNullOrWhiteSpace($_)) { return }
        try { [void]$structured.Add(($_ | ConvertFrom-Json)) } catch {}
    }
}

# Load overrides (high-signal training data)
$overrides = New-Object System.Collections.ArrayList
$overFile = "$structDir\overrides.jsonl"
if (Test-Path $overFile) {
    Get-Content $overFile -Encoding UTF8 -ErrorAction SilentlyContinue | ForEach-Object {
        if ([string]::IsNullOrWhiteSpace($_)) { return }
        try { [void]$overrides.Add(($_ | ConvertFrom-Json)) } catch {}
    }
}

# Tokenize question
$qWords = ($Question -split '\W+') | Where-Object { $_.Length -gt 3 } | ForEach-Object { $_.ToLowerInvariant() } | Sort-Object -Unique
$qHash = @{}
foreach ($w in $qWords) { $qHash[$w] = $true }

function Get-RelevanceScore($r) {
    $parts = @($r.retrieval_text, $r.subcategory, $r.decision_made, $r.decision_rationale)
    if ($r.entities) {
        if ($r.entities.features) { $parts += ($r.entities.features -join ' ') }
        if ($r.entities.libs)     { $parts += ($r.entities.libs -join ' ') }
        if ($r.entities.files)    { $parts += ($r.entities.files -join ' ') }
        if ($r.entities.agents)   { $parts += ($r.entities.agents -join ' ') }
    }
    $text = ($parts | Where-Object { $_ }) -join ' '
    if ([string]::IsNullOrWhiteSpace($text)) { return 0.0 }
    $words = ($text -split '\W+') | Where-Object { $_.Length -gt 3 } | ForEach-Object { $_.ToLowerInvariant() }
    $score = 0
    foreach ($w in $words) {
        if ($qHash.ContainsKey($w)) { $score++ }
    }
    $pw = if ($r.project_weight) { [double]$r.project_weight } else { 0.3 }
    return [double]$score * $pw
}

# Rank + pick top K
$structRanked = $structured | ForEach-Object {
    [pscustomobject]@{ rec = $_; score = (Get-RelevanceScore $_) }
} | Where-Object { $_.score -gt 0 } | Sort-Object score -Descending

$nTopical = [Math]::Max(0, $K - $KOverrides)
$topStruct = $structRanked | Select-Object -First $nTopical

# Overrides: baseline +5 boost, plus topical relevance
$overRanked = $overrides | ForEach-Object {
    $base = 5.0
    [pscustomobject]@{ rec = $_; score = $base + (Get-RelevanceScore $_) }
} | Sort-Object score -Descending
$topOver = $overRanked | Select-Object -First $KOverrides

if ($JsonOutput) {
    $exemplars = @()
    foreach ($x in $topOver) {
        $exemplars += [pscustomobject]@{
            kind                   = 'override'
            ts                     = $x.rec.ts
            project                = $x.rec.project
            project_weight         = $x.rec.project_weight
            category               = $x.rec.category
            subcategory            = $x.rec.subcategory
            scope_signal           = $x.rec.scope_signal
            evidence_demand        = $x.rec.evidence_demand
            risk_appetite          = $x.rec.risk_appetite
            decision_made          = $x.rec.decision_made
            decision_rationale     = $x.rec.decision_rationale
            override_axis          = $x.rec.override_axis
            agent_proposal_summary = $x.rec.agent_proposal_summary
            retrieval_text         = $x.rec.retrieval_text
            score                  = $x.score
        }
    }
    foreach ($x in $topStruct) {
        $exemplars += [pscustomobject]@{
            kind            = 'topical'
            ts              = $x.rec.ts
            project         = $x.rec.project
            project_weight  = $x.rec.project_weight
            category        = $x.rec.category
            subcategory     = $x.rec.subcategory
            scope_signal    = $x.rec.scope_signal
            evidence_demand = $x.rec.evidence_demand
            risk_appetite   = $x.rec.risk_appetite
            retrieval_text  = $x.rec.retrieval_text
            score           = $x.score
        }
    }
    $out = [pscustomobject]@{
        question = $Question
        persona_loaded = $personaExists
        persona = $persona
        principles = $principles
        exemplars = $exemplars
        stats = @{
            structured_pool   = $structured.Count
            overrides_pool    = $overrides.Count
            topical_returned  = $topStruct.Count
            override_returned = $topOver.Count
        }
    }
    $out | ConvertTo-Json -Depth 10
    return
}

# Markdown output (default)
$lines = New-Object System.Collections.ArrayList

[void]$lines.Add('# Twin context for question:')
[void]$lines.Add('')
[void]$lines.Add("> $Question")
[void]$lines.Add('')
[void]$lines.Add('---')
[void]$lines.Add('')

if ($personaExists) {
    [void]$lines.Add('## Operator persona (load verbatim)')
    [void]$lines.Add('')
    [void]$lines.Add($persona.Trim())
    [void]$lines.Add('')
} else {
    [void]$lines.Add('## Operator persona')
    [void]$lines.Add('')
    [void]$lines.Add('NOT YET BUILT - run /hae:profile. Twin will operate with no persona; sign as low-confidence.')
    [void]$lines.Add('')
}

if (-not [string]::IsNullOrWhiteSpace($principles)) {
    [void]$lines.Add('## Operator-authored principles (verbatim, non-negotiable)')
    [void]$lines.Add('')
    foreach ($p in ($principles -split "`n")) {
        $line = $p.Trim()
        if ($line) { [void]$lines.Add("- $line") }
    }
    [void]$lines.Add('')
}

[void]$lines.Add("## Override exemplars (highest signal: operator overrode agent; pool=$($overrides.Count))")
[void]$lines.Add('')
if ($topOver.Count -eq 0) {
    [void]$lines.Add('(no override deltas captured yet)')
    [void]$lines.Add('')
} else {
    foreach ($x in $topOver) {
        $r = $x.rec
        $axis = if ($r.override_axis) { $r.override_axis } else { 'unknown' }
        [void]$lines.Add("- **$($r.project) | $($r.ts) | axis: $axis | score=$([math]::Round($x.score,2))**")
        if ($r.agent_proposal_summary) { [void]$lines.Add("  Agent proposed: $($r.agent_proposal_summary)") }
        if ($r.decision_made) { [void]$lines.Add("  Operator decided: $($r.decision_made)") }
        if ($r.decision_rationale) { [void]$lines.Add("  Rationale: $($r.decision_rationale)") }
        if ($r.retrieval_text) { [void]$lines.Add("  Context: $($r.retrieval_text)") }
        [void]$lines.Add('')
    }
}

[void]$lines.Add("## Topical exemplars (keyword-relevance scored; pool=$($structured.Count))")
[void]$lines.Add('')
if ($topStruct.Count -eq 0) {
    [void]$lines.Add('(no topical matches above threshold; rely on persona + overrides)')
    [void]$lines.Add('')
} else {
    foreach ($x in $topStruct) {
        $r = $x.rec
        [void]$lines.Add("- **$($r.project) | $($r.category)/$($r.subcategory) | scope=$($r.scope_signal) ev=$($r.evidence_demand) risk=$($r.risk_appetite) | score=$([math]::Round($x.score,2))**")
        if ($r.retrieval_text) { [void]$lines.Add("  $($r.retrieval_text)") }
        [void]$lines.Add('')
    }
}

[void]$lines.Add('---')
[void]$lines.Add('')
[void]$lines.Add('## Twin instructions')
[void]$lines.Add('')
[void]$lines.Add('You are the operator twin. Emulate the operator''s judgment using:')
[void]$lines.Add('1. The persona block (decision-style scores).')
[void]$lines.Add('2. The principles (load verbatim - non-negotiable rules).')
[void]$lines.Add('3. The override exemplars (proven cases where the operator contradicted an agent - pattern-match against them).')
[void]$lines.Add('4. The topical exemplars (related context).')
[void]$lines.Add('')
[void]$lines.Add('Answer format:')
[void]$lines.Add('- **Twin take:** one-sentence position')
[void]$lines.Add('- **Why this position:** 2-4 bullets citing principle/exemplar/persona axis')
[void]$lines.Add('- **Risk in this call:** what could go wrong if operator follows the twin')
[void]$lines.Add('- **Confidence:** low | medium | high (low = thin profile signal; high = strong principle + exemplar match)')
[void]$lines.Add('- Sign with: `- twin (low-confidence persona, partial profile)`')

$lines -join "`n"
