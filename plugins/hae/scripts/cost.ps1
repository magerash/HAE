# HAE - cost tracker. Aggregates token spend across captured records.
#
# Usage:
#   cost.ps1                           : weekly summary (last 8 weeks) + per-project breakdown
#   cost.ps1 -Weeks 4                  : trailing 4 weeks only
#   cost.ps1 -Project habits           : single project filter
#   cost.ps1 -Json                     : machine-readable JSON output
#
# Pricing model (USD per 1M tokens, approximate Anthropic published rates 2026):
#   Opus 4.x:   input $15.00,  output $75.00,  cache_read $1.50,   cache_create $18.75
#   Sonnet 4.x: input $3.00,   output $15.00,  cache_read $0.30,   cache_create $3.75
#   Haiku 4.x:  input $0.80,   output $4.00,   cache_read $0.08,   cache_create $1.00
#   Unknown model defaults to Opus pricing (conservative high estimate).
#
# Limitation (per H18 research 2026-05-10):
#   Capture extracts usage from the LAST assistant record in the 50-line transcript tail.
#   Long sessions with many turns understate total spend. Acceptable for trend tracking;
#   not authoritative billing.

[CmdletBinding()]
param(
    [int]$Weeks = 8,
    [string]$Project,
    [switch]$Json
)

$ErrorActionPreference = 'Stop'

. "$(Split-Path -Parent $PSCommandPath)\_lib.ps1"
. "$(Split-Path -Parent $PSCommandPath)\_metrics_lib.ps1"

$rawDir = Get-HaeRawDir
if (-not (Test-Path $rawDir)) { Write-Host "No raw dir at $rawDir"; exit 0 }

# Pricing per 1M tokens (USD)
$pricing = @{
    'opus'   = @{ input = 15.00; output = 75.00; cache_read = 1.50; cache_create = 18.75 }
    'sonnet' = @{ input = 3.00;  output = 15.00; cache_read = 0.30; cache_create = 3.75 }
    'haiku'  = @{ input = 0.80;  output = 4.00;  cache_read = 0.08; cache_create = 1.00 }
}

function Get-Tier($modelId) {
    if ([string]::IsNullOrWhiteSpace($modelId)) { return 'opus' }
    $m = $modelId.ToLowerInvariant()
    if ($m -match 'haiku')  { return 'haiku' }
    if ($m -match 'sonnet') { return 'sonnet' }
    return 'opus'
}

function Get-RecordCost($r) {
    $tier = Get-Tier ([string]$r.model)
    $p = $pricing[$tier]
    $cIn   = ([int]($r.tokens_in)            / 1e6) * $p.input
    $cOut  = ([int]($r.tokens_out)           / 1e6) * $p.output
    $cCR   = ([int]($r.tokens_cache_read)    / 1e6) * $p.cache_read
    $cCC   = ([int]($r.tokens_cache_create)  / 1e6) * $p.cache_create
    return @{ cost = $cIn + $cOut + $cCR + $cCC; tier = $tier }
}

# Window: trailing $Weeks weeks (Mon-Sun ISO weeks)
$now = Get-WeekStart (Get-Date).ToUniversalTime()
$oldestWeekStart = $now.AddDays(-7 * ($Weeks - 1))

# Aggregations
$weekly = @{}      # weekKey -> { cost; tokens_in; tokens_out; cache_read; cache_create; records }
$perProject = @{}  # project -> { cost; records; tokens_total }
$perTier = @{}     # tier -> { cost; records }
$seenIds = @{}
$rawCount = 0
$captureCount = 0

Get-ChildItem $rawDir -Filter '*.jsonl' -ErrorAction SilentlyContinue | ForEach-Object {
    Get-Content $_.FullName -Encoding UTF8 -ErrorAction SilentlyContinue | ForEach-Object {
        if ([string]::IsNullOrWhiteSpace($_)) { return }
        try {
            $r = $_ | ConvertFrom-Json
            $rid = [string]$r.id
            if ($rid -and $seenIds.ContainsKey($rid)) { return }
            if ($rid) { $seenIds[$rid] = $true }
            $rawCount++

            # Filter: only records with token data (post-v0.6.0 captures)
            $hasTokens = ($null -ne $r.tokens_in) -or ($null -ne $r.tokens_out) -or ($null -ne $r.tokens_cache_create)
            if (-not $hasTokens) { return }

            # Optional project filter
            $proj = if ($r.project) { [string]$r.project } else { 'unknown' }
            if ($Project -and $proj -ne $Project) { return }

            $ts = [DateTime]::Parse($r.ts).ToUniversalTime()
            if ($ts -lt $oldestWeekStart) { return }

            $captureCount++
            $ws = Get-WeekStart $ts
            $wk = $ws.ToString('yyyy-MM-dd')

            $costInfo = Get-RecordCost $r
            $cost = [double]$costInfo.cost
            $tier = $costInfo.tier

            if (-not $weekly.ContainsKey($wk)) {
                $weekly[$wk] = @{ cost=0.0; tokens_in=0; tokens_out=0; cache_read=0; cache_create=0; records=0 }
            }
            $weekly[$wk].cost         += $cost
            $weekly[$wk].tokens_in    += [int]$r.tokens_in
            $weekly[$wk].tokens_out   += [int]$r.tokens_out
            $weekly[$wk].cache_read   += [int]$r.tokens_cache_read
            $weekly[$wk].cache_create += [int]$r.tokens_cache_create
            $weekly[$wk].records++

            if (-not $perProject.ContainsKey($proj)) {
                $perProject[$proj] = @{ cost=0.0; records=0; tokens_total=0 }
            }
            $perProject[$proj].cost         += $cost
            $perProject[$proj].records++
            $perProject[$proj].tokens_total += [int]$r.tokens_in + [int]$r.tokens_out + [int]$r.tokens_cache_read + [int]$r.tokens_cache_create

            if (-not $perTier.ContainsKey($tier)) { $perTier[$tier] = @{ cost=0.0; records=0 } }
            $perTier[$tier].cost += $cost
            $perTier[$tier].records++
        } catch {}
    }
}

# Build ordered weekly series
$orderedWeeks = @()
for ($i = 0; $i -lt $Weeks; $i++) {
    $ws = $oldestWeekStart.AddDays(7 * $i)
    $wk = $ws.ToString('yyyy-MM-dd')
    if ($weekly.ContainsKey($wk)) {
        $orderedWeeks += [pscustomobject]@{
            week         = $wk
            cost         = [math]::Round($weekly[$wk].cost, 4)
            tokens_in    = $weekly[$wk].tokens_in
            tokens_out   = $weekly[$wk].tokens_out
            cache_read   = $weekly[$wk].cache_read
            cache_create = $weekly[$wk].cache_create
            records      = $weekly[$wk].records
        }
    } else {
        $orderedWeeks += [pscustomobject]@{
            week         = $wk
            cost         = 0
            tokens_in    = 0
            tokens_out   = 0
            cache_read   = 0
            cache_create = 0
            records      = 0
        }
    }
}

$totalCost = ($orderedWeeks | Measure-Object -Property cost -Sum).Sum
$totalCost = [math]::Round([double]$totalCost, 4)
$weeklySpark = Format-Sparkline ($orderedWeeks | ForEach-Object { $_.cost })

if ($Json) {
    $out = [pscustomobject]@{
        window_weeks  = $Weeks
        window_start  = $oldestWeekStart.ToString('o')
        total_cost    = $totalCost
        captured_records = $captureCount
        scanned_records  = $rawCount
        weekly        = $orderedWeeks
        per_project   = $perProject.GetEnumerator() | Sort-Object { $_.Value.cost } -Descending | ForEach-Object { [pscustomobject]@{ project=$_.Key; cost=[math]::Round($_.Value.cost,4); records=$_.Value.records; tokens_total=$_.Value.tokens_total } }
        per_tier      = $perTier.GetEnumerator() | ForEach-Object { [pscustomobject]@{ tier=$_.Key; cost=[math]::Round($_.Value.cost,4); records=$_.Value.records } }
        sparkline     = $weeklySpark
        pricing_source = 'Anthropic published rates 2026 (Opus 4.x / Sonnet 4.x / Haiku 4.x); unknown model defaults to Opus'
        limitation    = 'Capture extracts usage from last assistant record in 50-line transcript tail. Long sessions understated. Trend-quality not billing-quality.'
    }
    $out | ConvertTo-Json -Depth 8
    return
}

Write-Host "## HAE cost tracker"
Write-Host ""
Write-Host "Window: trailing $Weeks weeks (since $($oldestWeekStart.ToString('yyyy-MM-dd')) UTC)"
if ($Project) { Write-Host "Filter: project=$Project" }
Write-Host "Records w/ token data: $captureCount of $rawCount scanned"
Write-Host "Total cost (USD, est.): `$$($totalCost.ToString('N4'))"
Write-Host "Weekly sparkline: $weeklySpark   (recent on right; ' . - = # *' grades)"
Write-Host ""
Write-Host "### Weekly breakdown"
Write-Host ""
Write-Host '| Week        | Cost ($)   | Records | tokens_in  | tokens_out | cache_read | cache_create |'
Write-Host '|-------------|-----------:|--------:|-----------:|-----------:|-----------:|-------------:|'
foreach ($w in $orderedWeeks) {
    $costFmt = ("{0:N4}" -f [double]$w.cost)
    Write-Host ("| {0,-11} | {1,10} | {2,7} | {3,10} | {4,10} | {5,10} | {6,12} |" -f $w.week, $costFmt, $w.records, $w.tokens_in, $w.tokens_out, $w.cache_read, $w.cache_create)
}
Write-Host ""

if ($perProject.Count -gt 0) {
    Write-Host "### Per-project (sorted by cost)"
    Write-Host ""
    Write-Host '| Project                    | Cost ($)  | Records | Tokens total |'
    Write-Host '|----------------------------|----------:|--------:|-------------:|'
    $perProject.GetEnumerator() | Sort-Object { $_.Value.cost } -Descending | Select-Object -First 15 | ForEach-Object {
        $costFmt = ("{0:N4}" -f [double]$_.Value.cost)
        Write-Host ("| {0,-26} | {1,9} | {2,7} | {3,12} |" -f $_.Key, $costFmt, $_.Value.records, $_.Value.tokens_total)
    }
    Write-Host ""
}

if ($perTier.Count -gt 0) {
    Write-Host "### Per-model-tier"
    Write-Host ""
    Write-Host '| Tier   | Cost ($)  | Records |'
    Write-Host '|--------|----------:|--------:|'
    $perTier.GetEnumerator() | Sort-Object { $_.Value.cost } -Descending | ForEach-Object {
        $costFmt = ("{0:N4}" -f [double]$_.Value.cost)
        Write-Host ("| {0,-6} | {1,9} | {2,7} |" -f $_.Key, $costFmt, $_.Value.records)
    }
    Write-Host ""
}

Write-Host "### Notes"
Write-Host "- Pricing: Anthropic published rates 2026 (USD per 1M tokens). Opus tier default for unknown model identifiers."
Write-Host "- Coverage: only records with token fields (captured 2026-05-10+ via H18 schema additive)."
Write-Host "- Accuracy: capture extracts usage from last assistant record in 50-line transcript tail. Long sessions understated."
Write-Host "- For trend tracking; not authoritative billing. Compare to Anthropic console for ground truth."
