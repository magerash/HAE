# HAE - nightly classification pass (Phase 3 stub)
# Reads prompts/raw/*.jsonl produced since last run, classifies each prompt
# into the 8-category taxonomy, scores scope_signal/risk_appetite/evidence_demand,
# detects operator-overrode-agent deltas, writes prompts/structured/<YYYY-MM>.jsonl.
#
# Phase 0: not implemented. Stub prints status and exits.

. "$(Split-Path -Parent $PSCommandPath)\_lib.ps1"
$rawDir = Get-HaeRawDir
$structuredDir = Get-HaeStructuredDir

Write-Host "HAE classify_nightly - Phase 0 stub"
Write-Host ""
Write-Host "Raw dir:        $rawDir"
Write-Host "Structured dir: $structuredDir"

if (-not (Test-Path $rawDir)) {
    Write-Host "No raw data yet."
    exit 0
}

$files = Get-ChildItem $rawDir -Filter '*.jsonl' -ErrorAction SilentlyContinue
$lineCount = 0
foreach ($f in $files) {
    $lineCount += (Get-Content $f.FullName | Measure-Object -Line).Lines
}

Write-Host "Raw files:  $($files.Count)"
Write-Host "Raw lines:  $lineCount"
Write-Host ""
Write-Host "TODO Phase 3: implement LLM classifier pass."
exit 0
