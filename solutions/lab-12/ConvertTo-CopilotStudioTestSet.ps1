<#
.SYNOPSIS
    Lab 12: convert course eval CSVs (evals/lab-*-questions.csv) into CSV test sets for Copilot
    Studio agent evaluation, with a configurable column mapping.

.DESCRIPTION
    Copilot Studio agent evaluation supports importing a test set from CSV (CS-A14, SNIP; GA in
    the classic docs, PREVIEW in the new-experience docs). The exact column names and any row
    limit of the import file could NOT be verified for this course. This converter therefore
    reads its output columns from a JSON mapping file (default testset-column-map.json next to
    this script) so you can match the template that Copilot Studio gives you without editing code.

    Mapping file format:
      {
        "columns": [ { "target": "Question", "source": "prompt" },
                     { "target": "Expected response", "source": "expected_answer" },
                     { "target": "Some constant column", "value": "constant text" } ],
        (optional per column: "stopAt": [ "Diagnosis:", "Decision tree:" ] cuts the value at the
        first marker found, so troubleshooting notes in expected_answer are not graded)
        "includeBehaviors": [ "answer", "conflict_flagged", ... ],
        "stripAgentPrefix": true,
        "encoding": "utf8BOM"
      }

    Row selection:
      - -Lab and -Persona filter rows. Evaluation runs are not tied to the course personas, so
        convert one persona at a time and run the evaluation with a matching test identity if your
        Copilot Studio version supports that; otherwise it runs as the maker (break-it C-12-c).
      - -Agent keeps rows whose prompt starts with "[<Agent>]" (the Lab 12 convention) and, with
        -IncludeUntagged, rows without a prefix. stripAgentPrefix removes the "[...] " prefix.
      - Only expected_behavior values in includeBehaviors are kept. observe and action_called rows
        are excluded by default: they need a human or a tool run, not a text comparison.
      - -MaxRowsPerFile splits the output into several files (0 = no split). No row limit is
        stated in reference/limits.md; check Learn and set this if the import rejects a large file.

    Output files are written to -OutputFolder as testset-<name>[-partN].csv. Re-running overwrites
    them (idempotent). -Cleanup deletes the files this script would write for the same arguments.

.PARAMETER TenantUrl
    SharePoint tenant URL. Not used; accepted for consistency with the course scripts.

.PARAMETER Prefix
    Course prefix (default HLE). Used in the output file name.

.PARAMETER EvalFolder
    Folder with lab-*-questions.csv. Default <repo>/evals.

.PARAMETER Lab
    Lab number(s) to include. Default: all.

.PARAMETER Persona
    Persona value(s) to include. Default: all.

.PARAMETER Agent
    Agent name for the "[Agent] prompt" convention, for example "HLE HR Assistant".

.PARAMETER IncludeUntagged
    With -Agent, also include rows that have no "[...]" prefix (earlier labs' files).

.PARAMETER MapFile
    Column mapping JSON. Default testset-column-map.json next to this script.

.PARAMETER Name
    Output name. Default built from the filters.

.PARAMETER OutputFolder
    Default ./out/lab-12/testsets

.PARAMETER MaxRowsPerFile
    Split output into files of at most this many rows. 0 (default) = one file.

.PARAMETER Cleanup
    Delete the output files for these arguments.

.EXAMPLE
    ./ConvertTo-CopilotStudioTestSet.ps1 -Lab 3 -Persona learner
    ./ConvertTo-CopilotStudioTestSet.ps1 -Lab 12 -Agent "HLE HR Assistant" -Persona learner -MaxRowsPerFile 10
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$TenantUrl,

    [ValidatePattern('^[A-Za-z][A-Za-z0-9]{1,7}$')]
    [string]$Prefix = 'HLE',

    [string]$EvalFolder = (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'evals'),

    [int[]]$Lab,

    [string[]]$Persona,

    [string]$Agent,

    [switch]$IncludeUntagged,

    [string]$MapFile = (Join-Path $PSScriptRoot 'testset-column-map.json'),

    [string]$Name,

    [string]$OutputFolder = (Join-Path (Get-Location) 'out/lab-12/testsets'),

    [ValidateRange(0, 100000)]
    [int]$MaxRowsPerFile = 0,

    [switch]$Cleanup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ExpectedHeader = 'id,persona,prompt,expected_answer,expected_source,expected_behavior,caveat_id'
$PrefixPattern = '^\s*\[([^\]]+)\]\s*'

function Get-MapValue($Object, [string]$Name, $Default) {
    $p = $Object.PSObject.Properties[$Name]
    if ($p -and $null -ne $p.Value) { return $p.Value } else { return $Default }
}

if (-not $Name) {
    $parts = @($Prefix.ToLowerInvariant())
    if ($Lab) { $parts += 'lab' + (($Lab | ForEach-Object { '{0:D2}' -f $_ }) -join '-') }
    if ($Persona) { $parts += ($Persona -join '-') }
    if ($Agent) { $parts += ($Agent -replace '[^A-Za-z0-9]+', '-').Trim('-').ToLowerInvariant() }
    $Name = ($parts -join '-')
}
$basePath = Join-Path $OutputFolder "testset-$Name"

if ($Cleanup) {
    $files = @(Get-ChildItem -Path $OutputFolder -Filter "testset-$Name*.csv" -ErrorAction SilentlyContinue)
    foreach ($f in $files) { if ($PSCmdlet.ShouldProcess($f.FullName, 'Remove')) { Remove-Item -LiteralPath $f.FullName } }
    Write-Host "Removed $($files.Count) file(s)."
    return
}

if (-not (Test-Path $MapFile)) { throw "Mapping file not found: $MapFile" }
$map = Get-Content -Raw -Path $MapFile | ConvertFrom-Json
$columns = @(Get-MapValue $map 'columns' @())
if ($columns.Count -eq 0) { throw "$MapFile has no 'columns'." }
foreach ($c in $columns) {
    if (-not $c.PSObject.Properties['target']) { throw "Every column in $MapFile needs a 'target'." }
    if (-not $c.PSObject.Properties['source'] -and -not $c.PSObject.Properties['value']) { throw "Column '$($c.target)' needs 'source' or 'value'." }
}
$includeBehaviors = @(Get-MapValue $map 'includeBehaviors' @('answer', 'conflict_flagged', 'no_answer', 'refuse', 'answer_without_citation'))
$stripPrefix = [bool](Get-MapValue $map 'stripAgentPrefix' $true)
$encoding = [string](Get-MapValue $map 'encoding' 'utf8BOM')

$rows = [System.Collections.Generic.List[object]]::new()
$files = @(Get-ChildItem -Path $EvalFolder -Filter 'lab-*-questions.csv' | Sort-Object Name)
foreach ($f in $files) {
    $m = [regex]::Match($f.Name, '^lab-(\d+)-questions\.csv$')
    if (-not $m.Success) { continue }
    $labNo = [int]$m.Groups[1].Value
    if ($Lab -and $labNo -notin $Lab) { continue }
    $first = ((Get-Content -Path $f.FullName -TotalCount 1) -replace '^﻿', '') -replace '"', ''
    if ($first -ne $ExpectedHeader) { Write-Warning "$($f.Name): unexpected header, skipped."; continue }
    foreach ($r in @(Import-Csv -Path $f.FullName)) {
        if ($Persona -and $r.persona -notin $Persona) { continue }
        if ($r.expected_behavior -notin $includeBehaviors) { continue }
        $pm = [regex]::Match([string]$r.prompt, $PrefixPattern)
        if ($Agent) {
            if ($pm.Success) { if ($pm.Groups[1].Value.Trim() -ne $Agent) { continue } }
            elseif (-not $IncludeUntagged) { continue }
        }
        $row = [ordered]@{}
        foreach ($c in $columns) {
            if ($c.PSObject.Properties['value']) { $row[$c.target] = [string]$c.value; continue }
            $srcName = [string]$c.source
            if (-not $r.PSObject.Properties[$srcName]) { throw "Mapping source '$srcName' is not a column of $($f.Name)." }
            $v = [string]$r.$srcName
            if ($srcName -eq 'prompt' -and $stripPrefix) { $v = $v -replace $PrefixPattern, '' }
            if ($c.PSObject.Properties['stopAt']) {
                foreach ($marker in @($c.stopAt)) {
                    $idx = $v.IndexOf([string]$marker, [System.StringComparison]::Ordinal)
                    if ($idx -gt 0) { $v = $v.Substring(0, $idx).TrimEnd() }
                }
            }
            $row[$c.target] = $v
        }
        $rows.Add([pscustomobject]$row)
    }
}

Write-Host "Selected $($rows.Count) row(s) from $($files.Count) eval file(s). Behaviors kept: $($includeBehaviors -join ', ')."
if ($rows.Count -eq 0) { Write-Warning 'Nothing to write. Check -Lab, -Persona, -Agent and includeBehaviors.'; return }

New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
$chunks = @()
if ($MaxRowsPerFile -gt 0 -and $rows.Count -gt $MaxRowsPerFile) {
    for ($i = 0; $i -lt $rows.Count; $i += $MaxRowsPerFile) {
        $chunks += , @($rows.GetRange($i, [math]::Min($MaxRowsPerFile, $rows.Count - $i)))
    }
}
else { $chunks = , @($rows.ToArray()) }

for ($n = 0; $n -lt $chunks.Count; $n++) {
    $path = if ($chunks.Count -gt 1) { "$basePath-part$($n + 1).csv" } else { "$basePath.csv" }
    if ($PSCmdlet.ShouldProcess($path, "Write $(@($chunks[$n]).Count) row(s)")) {
        @($chunks[$n]) | Export-Csv -Path $path -NoTypeInformation -Encoding $encoding
        Write-Host "Wrote $path"
    }
}
Write-Host 'Before importing: compare the header row with the template in Copilot Studio (Evaluation > test set > import; UI labels may differ) and edit the mapping file if it differs.'
