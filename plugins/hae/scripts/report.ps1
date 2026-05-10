# HAE - operator behavioral report
# Aggregates classified records into a single human-readable markdown report.
# Output: <haeRoot>\state\operator_report_v<N>.md
#
# Sections:
#   1. Pipeline state (raw / structured / overrides)
#   2. Category histogram
#   3. Project distribution (home vs other)
#   4. Override axis breakdown
#   5. Decision-style behavioral averages (from records, not self-report)
#   6. Recurring entities (top features, files, libs, agents)
#   7. Override exemplars (top N by axis)
#   8. Persistent themes (subcategories with >= 3 records)
#   9. Calibration: behavioral averages vs custom.json self-report

[CmdletBinding()]
param(
    [string]$Version = '0.2',
    [int]$TopN = 15
)

$ErrorActionPreference = 'Stop'

. "$(Split-Path -Parent $PSCommandPath)\_lib.ps1"
$structDir = Get-HaeStructuredDir
$rawDir    = Get-HaeRawDir
$profDir   = Get-HaeProfileDir
$stateDir  = Get-HaeStateDir
$outPath   = Join-Path $stateDir "operator_report_v$Version.md"

if (-not (Test-Path $stateDir)) { New-Item -ItemType Directory -Path $stateDir -Force | Out-Null }

# Load all structured (dedupe by id; skip overrides.jsonl - duplicate of monthly file entries)
$records = New-Object System.Collections.ArrayList
$seen = @{}
Get-ChildItem $structDir -Filter '*.jsonl' -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'overrides.jsonl' } | ForEach-Object {
    Get-Content $_.FullName -Encoding UTF8 -ErrorAction SilentlyContinue | ForEach-Object {
        if ([string]::IsNullOrWhiteSpace($_)) { return }
        try {
            $r = $_ | ConvertFrom-Json
            $rid = [string]$r.id
            if (-not $rid -or $seen.ContainsKey($rid)) { return }
            $seen[$rid] = $true
            [void]$records.Add($r)
        } catch {}
    }
}

# Load overrides separately for axis stats
$overrides = New-Object System.Collections.ArrayList
$overFile = "$structDir\overrides.jsonl"
if (Test-Path $overFile) {
    Get-Content $overFile -Encoding UTF8 -ErrorAction SilentlyContinue | ForEach-Object {
        if ([string]::IsNullOrWhiteSpace($_)) { return }
        try { [void]$overrides.Add(($_ | ConvertFrom-Json)) } catch {}
    }
}

# Raw count (deduped)
$rawSeen = @{}
$rawCount = 0
Get-ChildItem $rawDir -Filter '*.jsonl' -ErrorAction SilentlyContinue | ForEach-Object {
    Get-Content $_.FullName -Encoding UTF8 -ErrorAction SilentlyContinue | ForEach-Object {
        if ([string]::IsNullOrWhiteSpace($_)) { return }
        try {
            $r = $_ | ConvertFrom-Json
            $rid = [string]$r.id
            if ($rid -and -not $rawSeen.ContainsKey($rid)) {
                $rawSeen[$rid] = $true
                $rawCount++
            }
        } catch {}
    }
}

# Aggregations
$cats = @{}
$projects = @{}
$projectsHome = @{ home = 0; other = 0 }
$scopes = @{}
$urgencies = @{}
$evidenceSum = 0; $evidenceCount = 0
$riskSum = 0; $riskCount = 0
$entities = @{ files = @{}; features = @{}; libs = @{}; agents = @{} }
$subcatCounts = @{}
$classifierVersions = @{}

foreach ($r in $records) {
    $cat = if ($r.category) { [string]$r.category } else { 'UNKNOWN' }
    $cats[$cat] = ($cats[$cat] + 1)

    $proj = if ($r.project) { [string]$r.project } else { 'unknown' }
    $projects[$proj] = ($projects[$proj] + 1)
    if ($r.is_home_project) { $projectsHome.home++ } else { $projectsHome.other++ }

    if ($r.scope_signal) {
        $s = [string]$r.scope_signal
        $scopes[$s] = ($scopes[$s] + 1)
    }
    if ($r.urgency) {
        $u = [string]$r.urgency
        $urgencies[$u] = ($urgencies[$u] + 1)
    }
    # Exclude META from behavioral averages - META = system noise/approvals/interrupts,
    # not substantive operator decisions. Including them buries the real signal.
    $isSubstantive = ($cat -ne 'META')
    if ($null -ne $r.evidence_demand -and $isSubstantive) {
        $evidenceSum += [double]$r.evidence_demand
        $evidenceCount++
    }
    if ($null -ne $r.risk_appetite -and $isSubstantive) {
        $riskSum += [double]$r.risk_appetite
        $riskCount++
    }
    if ($r.subcategory) {
        $sub = [string]$r.subcategory
        $subcatCounts[$sub] = ($subcatCounts[$sub] + 1)
    }
    if ($r.classifier_version) {
        $cv = [string]$r.classifier_version
        $classifierVersions[$cv] = ($classifierVersions[$cv] + 1)
    }
    if ($r.entities) {
        foreach ($k in @('files','features','libs','agents')) {
            $list = $r.entities.$k
            if ($list) {
                foreach ($e in $list) {
                    if ($e) {
                        $key = [string]$e
                        $entities[$k][$key] = ($entities[$k][$key] + 1)
                    }
                }
            }
        }
    }
}

# Override axis breakdown
$overAxes = @{}
foreach ($o in $overrides) {
    $ax = if ($o.override_axis) { [string]$o.override_axis } else { 'unspecified' }
    $overAxes[$ax] = ($overAxes[$ax] + 1)
}

# Date range from records
$minTs = $null; $maxTs = $null
foreach ($r in $records) {
    try {
        $t = [DateTime]::Parse($r.ts).ToUniversalTime()
        if (-not $minTs -or $t -lt $minTs) { $minTs = $t }
        if (-not $maxTs -or $t -gt $maxTs) { $maxTs = $t }
    } catch {}
}

# Self-report from custom.json (for calibration)
$customSelf = $null
$customPath = "$profDir\custom.json"
if (Test-Path $customPath) {
    try { $customSelf = Get-Content $customPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
}

# Build markdown
$lines = New-Object System.Collections.ArrayList
[void]$lines.Add("# HAE Operator Behavioral Report v$Version")
[void]$lines.Add('')
[void]$lines.Add("**Generated:** $((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm UTC'))")
if ($minTs -and $maxTs) {
    [void]$lines.Add("**Source date range:** $($minTs.ToString('yyyy-MM-dd')) to $($maxTs.ToString('yyyy-MM-dd'))")
}
[void]$lines.Add('')
[void]$lines.Add('Aggregated from `prompts/structured/` (deduped by record id). Override exemplars counted separately from `overrides.jsonl`.')
[void]$lines.Add('')
[void]$lines.Add('---')
[void]$lines.Add('')

# 1. Pipeline state
[void]$lines.Add('## 1. Pipeline state')
[void]$lines.Add('')
$pct = if ($rawCount -gt 0) { [math]::Round(($records.Count / $rawCount) * 100, 1) } else { 0 }
[void]$lines.Add("- Raw records (deduped): **$rawCount**")
[void]$lines.Add("- Structured records: **$($records.Count)** ($pct% of raw)")
[void]$lines.Add("- Override exemplars: **$($overrides.Count)** ($([math]::Round($overrides.Count / [Math]::Max(1,$records.Count) * 100, 1))% override rate)")
$cvStr = ($classifierVersions.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ' '
[void]$lines.Add("- Classifier versions: $cvStr")
[void]$lines.Add('')

# 2. Category histogram
[void]$lines.Add('## 2. Category distribution')
[void]$lines.Add('')
[void]$lines.Add('| Category | Records | % |')
[void]$lines.Add('|----------|---------|---|')
$total = $records.Count
$cats.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
    $p = [math]::Round(($_.Value / $total) * 100, 1)
    [void]$lines.Add("| $($_.Key) | $($_.Value) | $p% |")
}
[void]$lines.Add('')

# 3. Project distribution
[void]$lines.Add('## 3. Project distribution')
[void]$lines.Add('')
[void]$lines.Add("- Home projects: **$($projectsHome.home)** | Other: **$($projectsHome.other)**")
[void]$lines.Add('')
[void]$lines.Add('| Project | Records |')
[void]$lines.Add('|---------|---------|')
$projects.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First $TopN | ForEach-Object {
    [void]$lines.Add("| $($_.Key) | $($_.Value) |")
}
[void]$lines.Add('')

# 4. Override axis breakdown
[void]$lines.Add('## 4. Override axis breakdown (where operator overrode the agent)')
[void]$lines.Add('')
if ($overrides.Count -eq 0) {
    [void]$lines.Add('(no overrides yet)')
} else {
    [void]$lines.Add('| Axis | Count | % of overrides |')
    [void]$lines.Add('|------|-------|----------------|')
    $overAxes.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
        $p = [math]::Round(($_.Value / $overrides.Count) * 100, 1)
        [void]$lines.Add("| $($_.Key) | $($_.Value) | $p% |")
    }
}
[void]$lines.Add('')

# 5. Behavioral averages
[void]$lines.Add('## 5. Decision-style behavioral averages (from records)')
[void]$lines.Add('')
$avgEv = if ($evidenceCount -gt 0) { [math]::Round($evidenceSum / $evidenceCount, 2) } else { 0 }
$avgRisk = if ($riskCount -gt 0) { [math]::Round($riskSum / $riskCount, 2) } else { 0 }
[void]$lines.Add("- Avg `evidence_demand`: **$avgEv / 10** (across $evidenceCount records)")
[void]$lines.Add("- Avg `risk_appetite`: **$avgRisk / 10** (across $riskCount records)")
[void]$lines.Add('')
[void]$lines.Add('### Scope-signal distribution')
[void]$lines.Add('')
[void]$lines.Add('| Scope signal | Count | % |')
[void]$lines.Add('|--------------|-------|---|')
$scopeTotal = ($scopes.Values | Measure-Object -Sum).Sum
$scopes.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
    $p = if ($scopeTotal -gt 0) { [math]::Round(($_.Value / $scopeTotal) * 100, 1) } else { 0 }
    [void]$lines.Add("| $($_.Key) | $($_.Value) | $p% |")
}
[void]$lines.Add('')
[void]$lines.Add('### Urgency distribution')
[void]$lines.Add('')
[void]$lines.Add('| Urgency | Count |')
[void]$lines.Add('|---------|-------|')
$urgencies.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
    [void]$lines.Add("| $($_.Key) | $($_.Value) |")
}
[void]$lines.Add('')

# 6. Recurring entities
[void]$lines.Add('## 6. Recurring entities')
[void]$lines.Add('')
foreach ($k in @('features','libs','files','agents')) {
    [void]$lines.Add("### Top $k mentioned")
    [void]$lines.Add('')
    if ($entities[$k].Count -eq 0) {
        [void]$lines.Add('(none)')
    } else {
        [void]$lines.Add('| Entity | Mentions |')
        [void]$lines.Add('|--------|----------|')
        $entities[$k].GetEnumerator() | Sort-Object Value -Descending | Select-Object -First $TopN | ForEach-Object {
            [void]$lines.Add("| $($_.Key) | $($_.Value) |")
        }
    }
    [void]$lines.Add('')
}

# 7. Override exemplars (top N by axis)
[void]$lines.Add("## 7. Override exemplars (top $TopN, most recent first)")
[void]$lines.Add('')
if ($overrides.Count -eq 0) {
    [void]$lines.Add('(none)')
} else {
    $sortedOver = $overrides | Sort-Object { [DateTime]::Parse($_.ts) } -Descending | Select-Object -First $TopN
    foreach ($o in $sortedOver) {
        $axis = if ($o.override_axis) { $o.override_axis } else { 'unspecified' }
        $ts = ([DateTime]::Parse($o.ts)).ToString('yyyy-MM-dd')
        [void]$lines.Add("- **$($o.project) | $ts | axis: $axis**")
        if ($o.agent_proposal_summary) { [void]$lines.Add("  Agent proposed: $($o.agent_proposal_summary)") }
        if ($o.decision_made) { [void]$lines.Add("  Operator decided: $($o.decision_made)") }
        if ($o.decision_rationale) { [void]$lines.Add("  Rationale: $($o.decision_rationale)") }
        [void]$lines.Add('')
    }
}

# 8. Persistent themes (subcategories with >= 3)
[void]$lines.Add('## 8. Persistent themes (subcategories repeated >= 3 times)')
[void]$lines.Add('')
$persistent = $subcatCounts.GetEnumerator() | Where-Object { $_.Value -ge 3 } | Sort-Object Value -Descending | Select-Object -First ($TopN * 2)
if ($persistent.Count -eq 0) {
    [void]$lines.Add('(none yet at threshold)')
} else {
    [void]$lines.Add('| Subcategory | Count |')
    [void]$lines.Add('|-------------|-------|')
    foreach ($p in $persistent) {
        [void]$lines.Add("| $($p.Key) | $($p.Value) |")
    }
}
[void]$lines.Add('')

# 9. Calibration: behavioral vs self-report
[void]$lines.Add('## 9. Calibration: behavioral averages vs self-report')
[void]$lines.Add('')
if (-not $customSelf) {
    [void]$lines.Add('No `profile/custom.json` found - run `/hae:profile` to enable calibration.')
} else {
    $selfEv = if ($customSelf.items.evidence_threshold_low) { [int]$customSelf.items.evidence_threshold_low } else { $null }
    $selfRisk = if ($customSelf.items.risk_tolerance) { [int]$customSelf.items.risk_tolerance } else { $null }

    [void]$lines.Add('| Axis | Self-report (1-7) | Behavioral avg (0-10, scaled to 1-7) | Delta |')
    [void]$lines.Add('|------|-------------------|--------------------------------------|-------|')

    if ($null -ne $selfEv) {
        # evidence_threshold_low: 1=demand data, 7=trust read. Behavioral evidence_demand: 0=easy, 10=demanding research.
        # Higher behavioral evidence_demand should correspond to LOWER self-report value (more data-demanding).
        $behavScaled = [math]::Round(7 - (($avgEv / 10) * 6), 2)  # invert + scale 0-10 to 7-1
        $delta = [math]::Round($behavScaled - $selfEv, 2)
        [void]$lines.Add("| Evidence threshold | $selfEv | $behavScaled (from avg evidence_demand $avgEv) | $delta |")
    }
    if ($null -ne $selfRisk) {
        # risk_tolerance: 1=safe, 7=big bets. Behavioral risk_appetite: 0=safe, 10=big bets. Same direction.
        $behavScaled = [math]::Round(1 + (($avgRisk / 10) * 6), 2)  # scale 0-10 to 1-7
        $delta = [math]::Round($behavScaled - $selfRisk, 2)
        [void]$lines.Add("| Risk tolerance | $selfRisk | $behavScaled (from avg risk_appetite $avgRisk) | $delta |")
    }
    [void]$lines.Add('')
    [void]$lines.Add('**Interpretation:** delta near 0 = self-report matches behavior. Large delta = blind spot (self-perception diverges from observed pattern).')
}
[void]$lines.Add('')

[void]$lines.Add('---')
[void]$lines.Add('')
[void]$lines.Add("*Generated by `scripts/report.ps1` v$Version. Re-run after each /hae:classify-bulk pass to track operator profile evolution.*")

# Write
$content = $lines -join "`n"
[System.IO.File]::WriteAllText($outPath, $content, [System.Text.UTF8Encoding]::new($false))
Write-Host "Report written: $outPath"
Write-Host "  Records analyzed: $($records.Count)"
Write-Host "  Overrides analyzed: $($overrides.Count)"
Write-Host "  Subcategory themes (>=3): $((($subcatCounts.Values | Where-Object { $_ -ge 3 }) | Measure-Object).Count)"
