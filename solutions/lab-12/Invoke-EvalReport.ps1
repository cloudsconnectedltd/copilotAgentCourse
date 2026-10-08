<#
.SYNOPSIS
    Lab 12 capstone: run the course evals, record results, and report pass rates by lab, persona
    and caveat.

.DESCRIPTION
    Reads every evals/lab-*-questions.csv (header id,persona,prompt,expected_answer,
    expected_source,expected_behavior,caveat_id), and works with one results CSV:

      -Mode Init     Create the results CSV, or merge new eval rows into an existing one. Existing
                     results are never overwritten. Rows whose id no longer exists in the evals are
                     kept and reported as orphans.
      -Mode Record   Record results. Interactive by default: shows each row that has no result
                     yet (filtered by -Lab, -Persona, -CaveatId) and asks for pass, fail, observed,
                     skipped, next or quit. The file is saved after every answer. Non-interactive:
                     -Id L03-Q04 -Result pass [-Notes "..."].
      -Mode Report   (default) Print the pass-rate summary overall, by lab, by persona and by
                     caveat_id, list failed rows, and optionally write the summaries to CSV files
                     in -ReportFolder.
      -Mode Validate Check every eval file: header, duplicate ids, persona and expected_behavior
                     values, repo paths in expected_source that do not exist.

    Pass rate = pass / (pass + fail). Rows recorded as observed or skipped are counted but are not
    part of the rate, because they cover preview, SNIP or UNVERIFIED behavior or a missing
    prerequisite. Rows with no result are "not run".

    The script does not depend on any particular rows. It discovers the files at run time, so it
    works while other labs' eval files are still being written.

    -Cleanup removes the results CSV and the report files this script wrote. It never touches
    evals/*.csv.

.PARAMETER TenantUrl
    SharePoint tenant URL. Not used; accepted for consistency with the course scripts and stored
    in the results file header comment.

.PARAMETER Prefix
    Course prefix (default HLE). Printed in the report.

.PARAMETER Mode
    Init, Record, Report (default) or Validate.

.PARAMETER EvalFolder
    Folder that holds lab-*-questions.csv. Default: <repo>/evals, found relative to this script.

.PARAMETER ResultsCsv
    Results file. Default ./eval-results.csv in the current folder.

.PARAMETER Lab
    Filter by lab number(s), for example 3 or 3,11.

.PARAMETER Persona
    Filter by persona value(s), for example hr,fin.

.PARAMETER CaveatId
    Filter by caveat_id value(s), for example C-03-e.

.PARAMETER Id
    Record mode, non-interactive: the eval id to record.

.PARAMETER Result
    Record mode, non-interactive: pass, fail, observed or skipped.

.PARAMETER Notes
    Record mode: notes to store with the result.

.PARAMETER Tester
    Name stored with each result. Default: current user name.

.PARAMETER Redo
    Record mode, interactive: also show rows that already have a result.

.PARAMETER ReportFolder
    Report mode: write summary-overall.csv, summary-by-lab.csv, summary-by-persona.csv,
    summary-by-caveat.csv and failures.csv here.

.PARAMETER Cleanup
    Remove the results CSV and report files created by this script.

.EXAMPLE
    ./Invoke-EvalReport.ps1 -Mode Init
    ./Invoke-EvalReport.ps1 -Mode Record -Lab 3 -Persona fin
    ./Invoke-EvalReport.ps1 -Mode Record -Id L12-Q02 -Result pass -Notes "no answer for Sofia"
    ./Invoke-EvalReport.ps1 -Mode Report -ReportFolder ./out/lab-12
#>
[CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Default')]
param(
    [string]$TenantUrl,

    [ValidatePattern('^[A-Za-z][A-Za-z0-9]{1,7}$')]
    [string]$Prefix = 'HLE',

    [ValidateSet('Init', 'Record', 'Report', 'Validate')]
    [string]$Mode = 'Report',

    [string]$EvalFolder = (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'evals'),

    [string]$ResultsCsv = (Join-Path (Get-Location) 'eval-results.csv'),

    [int[]]$Lab,

    [string[]]$Persona,

    [string[]]$CaveatId,

    [string]$Id,

    [ValidateSet('pass', 'fail', 'observed', 'skipped', '')]
    [string]$Result = '',

    [string]$Notes = '',

    [string]$Tester = [Environment]::UserName,

    [switch]$Redo,

    [string]$ReportFolder,

    [switch]$Cleanup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ExpectedHeader = @('id', 'persona', 'prompt', 'expected_answer', 'expected_source', 'expected_behavior', 'caveat_id')
$ValidPersonas = @('learner', 'hr', 'tech', 'fin', 'nolic', 'guest')
$ValidBehaviors = @('answer', 'no_answer', 'refuse', 'answer_without_citation', 'conflict_flagged', 'action_called', 'observe')
$ResultColumns = @('id', 'lab', 'persona', 'expected_behavior', 'caveat_id', 'result', 'run_date', 'tester', 'notes')
$ValidResults = @('pass', 'fail', 'observed', 'skipped')
$ReportFiles = @('summary-overall.csv', 'summary-by-lab.csv', 'summary-by-persona.csv', 'summary-by-caveat.csv', 'failures.csv')
$RepoRoot = Split-Path -Parent $EvalFolder

function Get-EvalFiles {
    if (-not (Test-Path $EvalFolder)) { throw "Eval folder not found: $EvalFolder. Pass -EvalFolder." }
    $files = @(Get-ChildItem -Path $EvalFolder -Filter 'lab-*-questions.csv' | Sort-Object Name)
    if ($files.Count -eq 0) { throw "No lab-*-questions.csv files in $EvalFolder" }
    return $files
}

function Get-LabNumber([string]$FileName) {
    $m = [regex]::Match($FileName, '^lab-(\d+)-questions\.csv$')
    if (-not $m.Success) { return 0 }
    return [int]$m.Groups[1].Value
}

function Import-Evals {
    <# Returns all eval rows with an added 'lab' property and 'file' property. #>
    $rows = [System.Collections.Generic.List[object]]::new()
    foreach ($f in Get-EvalFiles) {
        $labNo = Get-LabNumber $f.Name
        $firstLine = (Get-Content -Path $f.FullName -TotalCount 1) -replace '^﻿', ''
        $header = @($firstLine.Split(',') | ForEach-Object { $_.Trim().Trim('"') })
        if (($header -join ',') -ne ($ExpectedHeader -join ',')) {
            Write-Warning "$($f.Name): header is '$($header -join ',')', expected '$($ExpectedHeader -join ',')'. File skipped."
            continue
        }
        foreach ($r in @(Import-Csv -Path $f.FullName)) {
            if ([string]::IsNullOrWhiteSpace($r.id)) { continue }
            $r | Add-Member -NotePropertyName lab -NotePropertyValue $labNo -Force
            $r | Add-Member -NotePropertyName file -NotePropertyValue $f.Name -Force
            $rows.Add($r)
        }
    }
    return , $rows.ToArray()
}

function Import-Results {
    if (-not (Test-Path $ResultsCsv)) { return , @() }
    $rows = @(Import-Csv -Path $ResultsCsv)
    foreach ($r in $rows) {
        foreach ($c in $ResultColumns) {
            if (-not $r.PSObject.Properties[$c]) { $r | Add-Member -NotePropertyName $c -NotePropertyValue '' }
        }
    }
    return , $rows
}

function Save-Results([object[]]$Rows) {
    $dir = Split-Path -Parent $ResultsCsv
    if ($dir) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $Rows | Sort-Object @{ Expression = { [int]$_.lab } }, id | Select-Object $ResultColumns |
        Export-Csv -Path $ResultsCsv -NoTypeInformation -Encoding utf8
}

function Test-Filter($Row) {
    if ($Lab -and ([int]$Row.lab -notin $Lab)) { return $false }
    if ($Persona -and ($Row.persona -notin $Persona)) { return $false }
    if ($CaveatId -and ($Row.caveat_id -notin $CaveatId)) { return $false }
    return $true
}

function Get-Summary([object[]]$Rows, [scriptblock]$KeyOf, [string]$KeyName) {
    $groups = $Rows | Group-Object -Property @{ Expression = $KeyOf }
    foreach ($g in ($groups | Sort-Object Name)) {
        $items = @($g.Group)
        $pass = @($items | Where-Object { $_.result -eq 'pass' }).Count
        $fail = @($items | Where-Object { $_.result -eq 'fail' }).Count
        $obs = @($items | Where-Object { $_.result -eq 'observed' }).Count
        $skip = @($items | Where-Object { $_.result -eq 'skipped' }).Count
        $notRun = @($items | Where-Object { [string]::IsNullOrWhiteSpace($_.result) }).Count
        $rate = if (($pass + $fail) -gt 0) { [math]::Round(100.0 * $pass / ($pass + $fail), 1) } else { $null }
        [pscustomobject][ordered]@{
            $KeyName    = $g.Name
            total       = $items.Count
            pass        = $pass
            fail        = $fail
            observed    = $obs
            skipped     = $skip
            not_run     = $notRun
            pass_rate   = if ($null -eq $rate) { 'n/a' } else { "$rate%" }
        }
    }
}

# ------------------------------------------------------------------ Cleanup
if ($Cleanup) {
    $targets = @($ResultsCsv)
    if ($ReportFolder) { $targets += $ReportFiles | ForEach-Object { Join-Path $ReportFolder $_ } }
    foreach ($t in $targets) {
        if (Test-Path $t) {
            if ($PSCmdlet.ShouldProcess($t, 'Remove')) { Remove-Item -LiteralPath $t }
        }
    }
    Write-Host 'Cleanup complete. evals/*.csv were not touched.'
    return
}

# ------------------------------------------------------------------ Validate
if ($Mode -eq 'Validate') {
    $evals = Import-Evals
    $problems = 0
    foreach ($dup in ($evals | Group-Object id | Where-Object Count -gt 1)) {
        Write-Warning "Duplicate id $($dup.Name) in $(@($dup.Group.file | Select-Object -Unique) -join ', ')"; $problems++
    }
    foreach ($r in $evals) {
        if ($r.persona -notin $ValidPersonas) { Write-Warning "$($r.id): persona '$($r.persona)' is not one of $($ValidPersonas -join ', ')"; $problems++ }
        if ($r.expected_behavior -notin $ValidBehaviors) { Write-Warning "$($r.id): expected_behavior '$($r.expected_behavior)' is not one of $($ValidBehaviors -join ', ')"; $problems++ }
        $src = [string]$r.expected_source
        if ($src -like 'data/*' -and -not (Test-Path (Join-Path $RepoRoot $src))) {
            if ($src -like '*Employee-Handbook-Full.docx' -or $src -like '*Archive-Bulk*') {
                Write-Verbose "$($r.id): $src is generated at setup (allowed)"
            }
            else { Write-Warning "$($r.id): expected_source '$src' does not exist in the repo"; $problems++ }
        }
        elseif ($src -notlike 'data/*' -and $src -notmatch '^(api:|dataverse:|connector:|admin:|agent:|none$)') {
            Write-Warning "$($r.id): expected_source '$src' has an unknown form"; $problems++
        }
    }
    $evals | Group-Object lab | Sort-Object { [int]$_.Name } | ForEach-Object {
        [pscustomobject]@{ lab = $_.Name; rows = $_.Count; file = @($_.Group.file)[0] }
    } | Format-Table -AutoSize | Out-String -Width 220 | Write-Host
    Write-Host "Eval rows: $($evals.Count). Problems: $problems"
    return
}

# ------------------------------------------------------------------ Init
if ($Mode -eq 'Init') {
    $evals = Import-Evals
    $existing = Import-Results
    $byId = @{}
    foreach ($r in $existing) { $byId[$r.id] = $r }
    $added = 0
    foreach ($e in $evals) {
        if ($byId.ContainsKey($e.id)) {
            # refresh descriptive columns, keep the recorded result
            $byId[$e.id].lab = $e.lab; $byId[$e.id].persona = $e.persona
            $byId[$e.id].expected_behavior = $e.expected_behavior; $byId[$e.id].caveat_id = $e.caveat_id
            continue
        }
        $byId[$e.id] = [pscustomobject][ordered]@{
            id = $e.id; lab = $e.lab; persona = $e.persona; expected_behavior = $e.expected_behavior
            caveat_id = $e.caveat_id; result = ''; run_date = ''; tester = ''; notes = ''
        }
        $added++
    }
    $evalIds = @($evals | ForEach-Object id)
    $orphans = @($byId.Values | Where-Object { $_.id -notin $evalIds })
    if ($orphans.Count) { Write-Warning "$($orphans.Count) result rows have ids no longer in evals (kept): $(($orphans.id) -join ', ')" }
    if ($PSCmdlet.ShouldProcess($ResultsCsv, "Write results file ($added new rows)")) {
        Save-Results @($byId.Values)
        Write-Host "Results file: $ResultsCsv ($($byId.Count) rows, $added added)"
    }
    return
}

# ------------------------------------------------------------------ Record
if ($Mode -eq 'Record') {
    if (-not (Test-Path $ResultsCsv)) { throw "No results file at $ResultsCsv. Run -Mode Init first." }
    $results = Import-Results
    $evalIndex = @{}
    foreach ($e in (Import-Evals)) { $evalIndex[$e.id] = $e }

    if ($Id) {
        if (-not $Result) { throw 'Pass -Result with -Id.' }
        $row = $results | Where-Object id -eq $Id | Select-Object -First 1
        if (-not $row) { throw "Id $Id is not in $ResultsCsv. Run -Mode Init to add new eval rows." }
        $row.result = $Result; $row.run_date = (Get-Date).ToString('yyyy-MM-dd HH:mm'); $row.tester = $Tester
        if ($Notes) { $row.notes = $Notes }
        if ($PSCmdlet.ShouldProcess($ResultsCsv, "Record $Id = $Result")) { Save-Results $results }
        Write-Host "Recorded $Id = $Result"
        return
    }

    $todo = @($results | Where-Object { (Test-Filter $_) -and ($Redo -or [string]::IsNullOrWhiteSpace($_.result)) } |
            Sort-Object @{ Expression = { [int]$_.lab } }, id)
    Write-Host "$($todo.Count) rows to record. Answers: p=pass f=fail o=observed s=skipped n=next q=quit"
    foreach ($row in $todo) {
        $e = $evalIndex[$row.id]
        Write-Host ''
        Write-Host ("[{0}] lab {1}  persona {2}  behavior {3}  caveat {4}" -f $row.id, $row.lab, $row.persona, $row.expected_behavior, $row.caveat_id) -ForegroundColor Cyan
        if ($e) {
            Write-Host "Prompt:   $($e.prompt)"
            Write-Host "Expected: $($e.expected_answer)"
            Write-Host "Source:   $($e.expected_source)"
        }
        else { Write-Warning 'This id is no longer in the eval files.' }
        if ($row.result) { Write-Host "Current:  $($row.result) ($($row.notes))" }
        $answer = (Read-Host 'Result').Trim().ToLowerInvariant()
        switch ($answer) {
            'q' { Write-Host 'Stopped.'; return }
            'n' { continue }
            { $_ -in @('p', 'f', 'o', 's') } {
                $map = @{ p = 'pass'; f = 'fail'; o = 'observed'; s = 'skipped' }
                $row.result = $map[$answer]
                $row.run_date = (Get-Date).ToString('yyyy-MM-dd HH:mm')
                $row.tester = $Tester
                $n = Read-Host 'Notes (Enter to keep existing)'
                if ($n) { $row.notes = $n }
                Save-Results $results
            }
            default { Write-Warning "Unknown answer '$answer'; row left unchanged." }
        }
    }
    Write-Host 'All selected rows visited.'
    return
}

# ------------------------------------------------------------------ Report
if (-not (Test-Path $ResultsCsv)) { throw "No results file at $ResultsCsv. Run -Mode Init, then -Mode Record." }
$allResults = Import-Results
$results = @($allResults | Where-Object { Test-Filter $_ })
$bad = @($results | Where-Object { $_.result -and $_.result -notin $ValidResults })
if ($bad.Count) { Write-Warning "Unknown result values (treated as not run): $(($bad | ForEach-Object { "$($_.id)=$($_.result)" }) -join ', ')"; foreach ($b in $bad) { $b.result = '' } }

Write-Host "Harbourline course eval report ($Prefix) from $ResultsCsv, $($results.Count) rows"
if ($TenantUrl) { Write-Host "Tenant: $TenantUrl" }
Write-Host 'Pass rate = pass / (pass + fail). Observed and skipped rows are excluded from the rate.'

$overall = @(Get-Summary $results { 'all' } 'scope')
$byLab = @(Get-Summary $results { 'lab-{0:D2}' -f [int]$_.lab } 'lab')
$byPersona = @(Get-Summary $results { $_.persona } 'persona')
$byCaveat = @(Get-Summary $results { if ([string]::IsNullOrWhiteSpace($_.caveat_id)) { '(none)' } else { $_.caveat_id } } 'caveat_id')
$failures = @($results | Where-Object result -eq 'fail' | Select-Object id, lab, persona, caveat_id, notes)

Write-Host "`nOverall"; $overall | Format-Table -AutoSize | Out-String -Width 220 | Write-Host
Write-Host 'By lab'; $byLab | Format-Table -AutoSize | Out-String -Width 220 | Write-Host
Write-Host 'By persona'; $byPersona | Format-Table -AutoSize | Out-String -Width 220 | Write-Host
Write-Host 'By caveat_id'; $byCaveat | Format-Table -AutoSize | Out-String -Width 220 | Write-Host
if ($failures.Count) { Write-Host 'Failures (use labs/lab-12-eval-troubleshooting/troubleshooting-decision-tree.md)'; $failures | Format-Table -AutoSize | Out-String -Width 220 | Write-Host }

if ($ReportFolder) {
    New-Item -ItemType Directory -Path $ReportFolder -Force | Out-Null
    $sets = [ordered]@{ 'summary-overall.csv' = $overall; 'summary-by-lab.csv' = $byLab; 'summary-by-persona.csv' = $byPersona; 'summary-by-caveat.csv' = $byCaveat; 'failures.csv' = $failures }
    foreach ($k in $sets.Keys) {
        $path = Join-Path $ReportFolder $k
        if ($PSCmdlet.ShouldProcess($path, 'Write report')) { @($sets[$k]) | Export-Csv -Path $path -NoTypeInformation -Encoding utf8 }
    }
    Write-Host "Report files written to $ReportFolder"
}
