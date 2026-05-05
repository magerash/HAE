# HAE - classify helper. Three subcommands:
#   state       : print raw / classified / unclassified counts
#   next-batch  : auto-classify system messages, then emit JSON array of next N records
#                 that NEED LLM classification (oldest first). Auto-classified records are
#                 written to structured/ and marked done before output is built.
#   append      : read classified JSON array from stdin; append to structured/ and update state
#
# Auto-classification rules (saves ~40% LLM cycles on backfilled data):
#   - "[Request interrupted by user for tool use]" -> META/user-interrupt + override flag
#   - "Ultraplan terminated..." -> META/system-message
#   - "Remote Ultraplan session failed..." -> META/system-message
#   - Pure system-injected content (only <system-reminder>, <task-notification>,
#     <local-command-*>, <command-*> blocks) -> META/system-noise
# Mixed prompts (user text + system blocks) get the system blocks stripped before
# being sent to the LLM, so signal density is higher.

[CmdletBinding()]
param(
    [Parameter(Position=0)] [string]$Subcommand = 'state',
    [int]$N = 20,
    [int]$MaxPromptChars = 2000
)

$ErrorActionPreference = 'Stop'

$haeRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$cfg = Get-Content "$haeRoot\config.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$rawDir = "$haeRoot\prompts\raw"
$structDir = "$haeRoot\prompts\structured"
$stateDir = "$haeRoot\state"
$statePath = "$stateDir\classified_ids.json"

if (-not (Test-Path $structDir)) { New-Item -ItemType Directory -Path $structDir -Force | Out-Null }
if (-not (Test-Path $stateDir))  { New-Item -ItemType Directory -Path $stateDir  -Force | Out-Null }

# Load state
$classifiedIds = @{}
if (Test-Path $statePath) {
    try {
        $loaded = Get-Content $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($loaded.ids) {
            foreach ($id in $loaded.ids) { $classifiedIds[[string]$id] = $true }
        }
    } catch {}
}

function Get-AllRawRecords {
    $seen = @{}
    $list = New-Object System.Collections.ArrayList
    $files = Get-ChildItem $rawDir -Filter '*.jsonl' -ErrorAction SilentlyContinue | Sort-Object {
        if ($_.BaseName -match '^\d{4}-\d{2}-\d{2}__') { 1 } else { 0 }
    }
    foreach ($f in $files) {
        Get-Content $f.FullName -Encoding UTF8 -ErrorAction SilentlyContinue | ForEach-Object {
            if ([string]::IsNullOrWhiteSpace($_)) { return }
            try {
                $r = $_ | ConvertFrom-Json
                $rid = [string]$r.id
                if (-not $rid -or $seen.ContainsKey($rid)) { return }
                $seen[$rid] = $true
                [void]$list.Add($r)
            } catch {}
        }
    }
    return ,$list.ToArray()
}

function Save-State {
    $stateOut = [pscustomobject]@{
        ids              = @($classifiedIds.Keys)
        last_run         = (Get-Date).ToUniversalTime().ToString('o')
        total_classified = $classifiedIds.Count
    }
    [System.IO.File]::WriteAllText($statePath, ($stateOut | ConvertTo-Json -Depth 10), [System.Text.UTF8Encoding]::new($false))
}

function Strip-SystemBlocks([string]$text) {
    if ([string]::IsNullOrEmpty($text)) { return '' }
    $opts = [System.Text.RegularExpressions.RegexOptions]::Multiline -bor [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Singleline
    $clean = $text
    $clean = [regex]::Replace($clean, '<system-reminder>.*?</system-reminder>', '', $opts)
    $clean = [regex]::Replace($clean, '<task-notification>.*?</task-notification>', '', $opts)
    $clean = [regex]::Replace($clean, '<local-command-caveat>.*?</local-command-caveat>', '', $opts)
    $clean = [regex]::Replace($clean, '<local-command-stdout>.*?</local-command-stdout>', '', $opts)
    $clean = [regex]::Replace($clean, '<command-name>.*?</command-name>', '', $opts)
    $clean = [regex]::Replace($clean, '<command-message>.*?</command-message>', '', $opts)
    $clean = [regex]::Replace($clean, '<command-args>.*?</command-args>', '', $opts)
    $clean = [regex]::Replace($clean, '(?m)^Base directory for this skill:.*$', '', $opts)
    $clean = [regex]::Replace($clean, '(?m)^ARGUMENTS:.*$', '', $opts)
    return $clean.Trim()
}

function Get-AutoClassification($r) {
    # Returns a structured record for known system patterns, or $null when LLM is required.
    $p = [string]$r.prompt
    if ([string]::IsNullOrWhiteSpace($p)) { return $null }
    $trimmed = $p.Trim()

    $base = [ordered]@{
        id                      = $r.id
        ts                      = $r.ts
        session_id              = $r.session_id
        project                 = $r.project
        is_home_project         = $r.is_home_project
        project_weight          = $r.project_weight
        source                  = $r.source
        category                = 'META'
        subcategory             = $null
        intent_verbs            = @()
        entities                = @{ files = @(); features = @(); libs = @(); agents = @() }
        scope_signal            = 'hold'
        evidence_demand         = 0
        risk_appetite           = 0
        urgency                 = 'low'
        decision_made           = $null
        decision_rationale      = $null
        operator_overrode_agent = $false
        override_axis           = $null
        agent_proposal_summary  = $null
        retrieval_text          = $null
        classifier_version      = 'v0.1.0-auto'
        persona_version         = $null
        embedding               = $null
    }

    # 1. User interrupt
    if ($trimmed -eq '[Request interrupted by user for tool use]') {
        $base.subcategory = 'user-interrupt'
        $base.scope_signal = 'trim'
        $base.urgency = 'high'
        $base.risk_appetite = 2
        $base.operator_overrode_agent = $true
        $base.override_axis = 'approach'
        $base.decision_made = 'stop current agent action'
        $base.agent_proposal_summary = 'agent was using a tool when operator interrupted'
        $base.retrieval_text = 'Operator interrupted agent mid tool-use - override marker (specific intent in next message).'
        return [pscustomobject]$base
    }

    # 2. Ultraplan auto-terminate
    if ($trimmed -match '^Ultraplan terminated') {
        $base.subcategory = 'system-message'
        $base.entities.agents = @('Ultraplan')
        $base.retrieval_text = 'System notice: Ultraplan auto-terminated (no approval timeout).'
        return [pscustomobject]$base
    }

    # 3. Remote Ultraplan failed
    if ($trimmed -match '^Remote Ultraplan session failed') {
        $base.subcategory = 'system-message'
        $base.entities.agents = @('Ultraplan')
        $base.retrieval_text = 'System notice: remote Ultraplan session failed.'
        return [pscustomobject]$base
    }

    # 4. Single-token approval / continue / acknowledgment turns
    # These dilute META and burn LLM cycles. Match short prompts (<=30 chars) against
    # known approval lexicon - case-insensitive, surrounding punctuation tolerated.
    if ($trimmed.Length -le 30) {
        $simple = ($trimmed.ToLowerInvariant() -replace '[^\p{L}\p{Nd}\s+/]', '').Trim()
        $approvalLex = @(
            'yes','y','yep','yeah','yup','ok','okay','sure','fine','good','great',
            'no','n','nope','nah',
            'continue','next','go','proceed','do it','lets go','let s go','let''s go',
            'thanks','thank you','ty','thx','cheers',
            'done','ready','correct','right','exactly','agreed',
            'stop','wait','pause','hold on','hold',
            'run','start','begin','start it','run it','do','try'
        )
        if ($approvalLex -contains $simple) {
            $base.subcategory = 'operator-approval'
            $base.retrieval_text = "Short approval / direction turn: ""$trimmed"" - acknowledges or directs prior agent step."
            return [pscustomobject]$base
        }
        # Single digit/letter menu pick
        if ($trimmed -match '^[A-Za-z0-9]$') {
            $base.subcategory = 'menu-pick'
            $base.retrieval_text = "Single-character menu pick: ""$trimmed"" - operator chose option from prior numbered/lettered list."
            return [pscustomobject]$base
        }
    }

    # 5. Pure system-noise: when stripping all known blocks leaves nothing meaningful
    $stripped = Strip-SystemBlocks $p
    if ([string]::IsNullOrWhiteSpace($stripped)) {
        $base.subcategory = 'system-noise'
        $base.retrieval_text = 'Pure system-injected content (hook context, slash-command echo, system reminder); no operator intent.'
        return [pscustomobject]$base
    }
    if ($stripped.Length -lt 30 -and $p.Length -gt 200) {
        $base.subcategory = 'system-noise'
        $clip = $stripped.Substring(0, [Math]::Min(60, $stripped.Length))
        $base.retrieval_text = "Mostly system-injected content; minor user fragment: $clip"
        return [pscustomobject]$base
    }

    return $null
}

function Write-StructuredRecord($rec) {
    $ts = [DateTime]::Parse($rec.ts).ToUniversalTime()
    $monthFile = "$structDir\$($ts.ToString('yyyy-MM')).jsonl"
    $json = $rec | ConvertTo-Json -Depth 10 -Compress
    [System.IO.File]::AppendAllText($monthFile, $json + "`n", [System.Text.UTF8Encoding]::new($false))
    if ($rec.operator_overrode_agent -eq $true) {
        $overFile = "$structDir\overrides.jsonl"
        [System.IO.File]::AppendAllText($overFile, $json + "`n", [System.Text.UTF8Encoding]::new($false))
    }
}

switch ($Subcommand.ToLowerInvariant()) {
    'state' {
        $all = Get-AllRawRecords
        $structuredCount = 0
        $overrideCount = 0
        if (Test-Path $structDir) {
            Get-ChildItem $structDir -Filter '*.jsonl' -ErrorAction SilentlyContinue | ForEach-Object {
                $lines = (Get-Content $_.FullName -ErrorAction SilentlyContinue | Measure-Object -Line).Lines
                if ($_.Name -eq 'overrides.jsonl') { $overrideCount = $lines } else { $structuredCount += $lines }
            }
        }
        $unclassified = $all.Count - $classifiedIds.Count
        Write-Host "HAE classifier state:"
        Write-Host "  Raw records (deduped):  $($all.Count)"
        Write-Host "  Classified (state):     $($classifiedIds.Count)"
        Write-Host "  Structured (files):     $structuredCount records across monthly files"
        Write-Host "  Override deltas:        $overrideCount in overrides.jsonl"
        Write-Host "  Unclassified:           $unclassified"
        if ($unclassified -gt 0) {
            Write-Host ''
            Write-Host "Run /hae:classify (default N=20 per batch) to continue."
        }
    }

    'next-batch' {
        $all = Get-AllRawRecords
        $sorted = $all | Sort-Object { [DateTime]::Parse($_.ts) }
        $batch = New-Object System.Collections.ArrayList
        $autoCount = 0
        $autoBuckets = @{}
        $skippedCount = 0

        foreach ($r in $sorted) {
            if ($classifiedIds.ContainsKey([string]$r.id)) { continue }

            # Skip Stop records (response captures, not user intents)
            if ($r.event -eq 'Stop' -or $r.event -eq 'StopMarker') {
                $classifiedIds[[string]$r.id] = $true
                $skippedCount++
                continue
            }

            # Auto-classify known system patterns
            $autoStruct = Get-AutoClassification $r
            if ($autoStruct) {
                Write-StructuredRecord $autoStruct
                $classifiedIds[[string]$r.id] = $true
                $autoCount++
                $key = [string]$autoStruct.subcategory
                $autoBuckets[$key] = ($autoBuckets[$key] + 1)
                continue
            }

            # Strip embedded system blocks from mixed prompts before sending to LLM
            $promptText = Strip-SystemBlocks ([string]$r.prompt)
            if ([string]::IsNullOrWhiteSpace($promptText)) { $promptText = [string]$r.prompt }

            $truncated = $false
            if ($promptText.Length -gt $MaxPromptChars) {
                $extra = $promptText.Length - $MaxPromptChars
                $promptText = $promptText.Substring(0, $MaxPromptChars) + "...[truncated +${extra}chars]"
                $truncated = $true
            }
            $trim = [pscustomobject]@{
                id              = $r.id
                ts              = $r.ts
                session_id      = $r.session_id
                project         = $r.project
                is_home_project = $r.is_home_project
                project_weight  = $r.project_weight
                source          = $r.source
                event           = $r.event
                prompt          = $promptText
                prompt_truncated = $truncated
            }
            [void]$batch.Add($trim)
            if ($batch.Count -ge $N) { break }
        }

        Save-State

        # Stats to stderr so stdout stays valid JSON
        if ($autoCount -gt 0 -or $skippedCount -gt 0) {
            $bucketStr = ($autoBuckets.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ' '
            [Console]::Error.WriteLine("auto-classified: $autoCount ($bucketStr) | stop-skipped: $skippedCount | for LLM: $($batch.Count)")
        }

        if ($batch.Count -eq 0) { '[]'; return }
        $batch.ToArray() | ConvertTo-Json -Depth 10 -Compress
    }

    'append' {
        $ms = New-Object System.IO.MemoryStream
        [Console]::OpenStandardInput().CopyTo($ms)
        $bytes = $ms.ToArray()
        $ms.Dispose()
        if ($bytes.Length -eq 0) { Write-Host 'No input.'; exit 0 }
        $payload = [System.Text.Encoding]::UTF8.GetString($bytes)

        $records = $payload | ConvertFrom-Json
        if ($records -isnot [array]) { $records = @($records) }

        $appended = 0
        $overrides = 0
        $catCounts = @{}
        foreach ($r in $records) {
            if (-not $r.id) { continue }
            if ($classifiedIds.ContainsKey([string]$r.id)) { continue }

            Write-StructuredRecord $r
            if ($r.operator_overrode_agent -eq $true) { $overrides++ }
            $cat = if ($r.category) { [string]$r.category } else { 'UNKNOWN' }
            $catCounts[$cat] = ($catCounts[$cat] + 1)
            $classifiedIds[[string]$r.id] = $true
            $appended++
        }

        Save-State

        Write-Host "Appended $appended classified records."
        if ($overrides -gt 0) { Write-Host "Override deltas (high-signal exemplars): $overrides" }
        if ($catCounts.Count -gt 0) {
            $catStr = ($catCounts.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ' '
            Write-Host "Categories: $catStr"
        }
        Write-Host "Total classified: $($classifiedIds.Count)"
    }

    default {
        Write-Error "Unknown subcommand '$Subcommand'. Use: state | next-batch | append"
        exit 1
    }
}
