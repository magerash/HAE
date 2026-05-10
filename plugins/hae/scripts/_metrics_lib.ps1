# HAE - shared metrics library
# Dot-source from any HAE script:
#   . "$(Split-Path -Parent $PSCommandPath)\_metrics_lib.ps1"
#
# Provides:
#   Get-OverrideRateDrift  : weekly override counts overall + per-axis, trailing-4-week vs prior-4-week delta
#   Format-Sparkline       : render numeric series as ASCII sparkline (8 graded characters)
#
# Design contract:
#   - Reads from overrides.jsonl (Phase 3 classifier output)
#   - Pure functions; no side effects, no writes
#   - ASCII-only output (no unicode block chars - terminal compatibility per CLAUDE.md)
#   - Returns structured object; caller renders

# Requires _lib.ps1 to be dot-sourced first (Get-HaeStructuredDir).

function Format-Sparkline {
    # Render numeric series as ASCII sparkline. 5 grades: . - = # *
    # Grade based on max in series. Empty/zero values render as space.
    param(
        [Parameter(Mandatory=$true)] $Series,
        [int]$Width = 0
    )
    $arr = @($Series | ForEach-Object { [double]$_ })
    if ($arr.Count -eq 0) { return '' }
    $maxV = ($arr | Measure-Object -Maximum).Maximum
    if ($maxV -le 0) { return (' ' * $arr.Count) }

    $glyphs = @(' ', '.', '-', '=', '#', '*')   # 0..5 grades
    $sb = New-Object System.Text.StringBuilder
    foreach ($v in $arr) {
        if ($v -le 0) { [void]$sb.Append($glyphs[0]); continue }
        $g = [int][Math]::Ceiling(($v / $maxV) * 5)
        if ($g -lt 1) { $g = 1 }
        if ($g -gt 5) { $g = 5 }
        [void]$sb.Append($glyphs[$g])
    }
    $out = $sb.ToString()
    if ($Width -gt 0 -and $out.Length -lt $Width) {
        $out = $out.PadLeft($Width)
    }
    return $out
}

function Get-WeekStart {
    # ISO week start (Monday 00:00 UTC) for a given DateTime
    param([DateTime]$Date)
    $utc = $Date.ToUniversalTime()
    $dow = [int]$utc.DayOfWeek
    if ($dow -eq 0) { $dow = 7 }   # Sunday -> 7
    $offset = $dow - 1              # Monday=0, Tuesday=1, ...
    return $utc.Date.AddDays(-$offset)
}

function Get-OverrideRateDrift {
    # Read overrides.jsonl, group by ISO week. Return:
    #   weeks_count        : number of weeks observed
    #   weekly_counts      : @(int) ordered oldest -> newest, length = $WindowWeeks * 2 (recent on right)
    #   per_axis           : hashtable axis -> @(int) weekly counts, same window
    #   recent_4w_total    : int sum of last $WindowWeeks weeks
    #   prior_4w_total     : int sum of weeks before that, same length
    #   delta              : recent_4w_total - prior_4w_total
    #   delta_pct          : (delta / prior_4w_total) * 100, or null if prior=0
    #   sparkline_overall  : ASCII sparkline string for full 8-week series
    #   sparkline_per_axis : hashtable axis -> sparkline string
    #   axes               : list of axes seen (sorted by recent_4w count descending)
    #   alert              : 'none' | 'mild' | 'strong' based on delta_pct thresholds
    param(
        [int]$WindowWeeks = 4
    )

    $structDir = Get-HaeStructuredDir
    $overFile = Join-Path $structDir 'overrides.jsonl'

    $totalWindowWeeks = $WindowWeeks * 2   # recent + prior
    $now = Get-WeekStart (Get-Date).ToUniversalTime()
    $oldestWeekStart = $now.AddDays(-7 * ($totalWindowWeeks - 1))   # inclusive

    # Buckets: weekStart -> @{ overall, per_axis @{ axis -> count } }
    $buckets = @{}
    for ($i = 0; $i -lt $totalWindowWeeks; $i++) {
        $ws = $oldestWeekStart.AddDays(7 * $i)
        $buckets[$ws.ToString('yyyy-MM-dd')] = @{
            week_start = $ws
            overall    = 0
            per_axis   = @{}
        }
    }

    if (-not (Test-Path $overFile)) {
        return [pscustomobject]@{
            weeks_count        = 0
            weekly_counts      = @()
            per_axis           = @{}
            recent_4w_total    = 0
            prior_4w_total     = 0
            delta              = 0
            delta_pct          = $null
            sparkline_overall  = ''
            sparkline_per_axis = @{}
            axes               = @()
            alert              = 'none'
            window_weeks       = $WindowWeeks
            window_start       = $oldestWeekStart
        }
    }

    Get-Content $overFile -Encoding UTF8 -ErrorAction SilentlyContinue | ForEach-Object {
        if ([string]::IsNullOrWhiteSpace($_)) { return }
        try {
            $r = $_ | ConvertFrom-Json
            if (-not $r.ts) { return }
            $ts = [DateTime]::Parse($r.ts).ToUniversalTime()
            if ($ts -lt $oldestWeekStart) { return }
            $ws = Get-WeekStart $ts
            $key = $ws.ToString('yyyy-MM-dd')
            if (-not $buckets.ContainsKey($key)) { return }
            $buckets[$key].overall++
            $axis = if ($r.override_axis) { [string]$r.override_axis } else { 'unspecified' }
            if (-not $buckets[$key].per_axis.ContainsKey($axis)) { $buckets[$key].per_axis[$axis] = 0 }
            $buckets[$key].per_axis[$axis]++
        } catch {}
    }

    # Build ordered series oldest -> newest
    $ordered = @($buckets.Values | Sort-Object { $_.week_start })
    $weekly = @($ordered | ForEach-Object { $_.overall })

    # Aggregate per-axis across all weeks
    $axesSeen = @{}
    foreach ($b in $ordered) {
        foreach ($a in $b.per_axis.Keys) { $axesSeen[$a] = $true }
    }
    $perAxis = @{}
    foreach ($a in $axesSeen.Keys) {
        $perAxis[$a] = @($ordered | ForEach-Object { if ($_.per_axis.ContainsKey($a)) { $_.per_axis[$a] } else { 0 } })
    }

    # Totals (last WindowWeeks vs first WindowWeeks)
    $recentSum = ($weekly[-$WindowWeeks..-1] | Measure-Object -Sum).Sum
    $priorSum  = ($weekly[0..($WindowWeeks-1)] | Measure-Object -Sum).Sum
    $delta = $recentSum - $priorSum
    $deltaPct = if ($priorSum -gt 0) { [math]::Round(($delta / $priorSum) * 100, 1) } else { $null }

    # Alert thresholds (operator-friendly defaults)
    $alert = 'none'
    if ($priorSum -ge 4 -and $null -ne $deltaPct) {
        $abs = [Math]::Abs($deltaPct)
        if ($abs -ge 100) { $alert = 'strong' }
        elseif ($abs -ge 50) { $alert = 'mild' }
    }

    # Sort axes by recent count desc
    $axesSorted = @($perAxis.GetEnumerator() | Sort-Object { ($_.Value[-$WindowWeeks..-1] | Measure-Object -Sum).Sum } -Descending | ForEach-Object { $_.Key })

    # Sparklines
    $sparkOverall = Format-Sparkline $weekly
    $sparkPerAxis = @{}
    foreach ($a in $axesSorted) { $sparkPerAxis[$a] = Format-Sparkline $perAxis[$a] }

    return [pscustomobject]@{
        weeks_count        = $totalWindowWeeks
        weekly_counts      = $weekly
        per_axis           = $perAxis
        recent_4w_total    = [int]$recentSum
        prior_4w_total     = [int]$priorSum
        delta              = [int]$delta
        delta_pct          = $deltaPct
        sparkline_overall  = $sparkOverall
        sparkline_per_axis = $sparkPerAxis
        axes               = $axesSorted
        alert              = $alert
        window_weeks       = $WindowWeeks
        window_start       = $oldestWeekStart
    }
}
