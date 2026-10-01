<#
.SYNOPSIS
    Uploads the course documents to the Harbourline libraries and imports Vendors.csv into the Vendors list.

.DESCRIPTION
    Idempotent. Steps:
      1. Runs the Python generators if their outputs are missing:
           tools/generate-data/generate_oversized_handbook.py  -> HR-Policies/Employee-Handbook-Full.docx
           tools/generate-data/generate_archive_bulk.py        -> Harbourline-Operations/Archive-Bulk/
      2. Uploads each local folder to its library, preserving subfolders (reference/site-map.md):
           data/sharepoint/Harbourline-Hub/Getting-Started        -> Hub / Getting-Started
           data/sharepoint/Harbourline-Hub/HR-Policies (+Restricted) -> Hub / HR-Policies
           data/sharepoint/Harbourline-Hub/Finance                -> Hub / Finance
           data/sharepoint/Harbourline-Operations/Procedures      -> Operations / Procedures
           data/sharepoint/Harbourline-Operations/Archive-Bulk    -> Operations / Archive-Bulk
         A file is skipped when a file with the same name and size already exists.
      3. Imports data/sharepoint/Harbourline-Hub/Vendors.csv into the Vendors list in PnP batches,
         skipping rows whose VendorId already exists.

    data/sharepoint/lab-09-drops is NOT uploaded; learners drop those files during Lab 9.

.PARAMETER TenantUrl
    Root SharePoint URL, for example https://contoso.sharepoint.com.

.PARAMETER Prefix
    Course object prefix. Default HLE.

.PARAMETER ClientId
    Application (client) ID of your Entra app registration for PnP.PowerShell. Defaults to $env:ENTRAID_APP_ID.

.PARAMETER PythonPath
    Python 3 executable used for the generators. Default python3 (use py or python on Windows).

.PARAMETER SkipGenerators
    Do not run the Python generators, even if outputs are missing.

.PARAMETER BatchSize
    Number of list items per PnP batch. Default 100.

.PARAMETER Cleanup
    Removes the uploaded files (and the non-structural subfolders they came in) and the Vendors
    list items whose VendorId appears in Vendors.csv. Libraries, the list and the Restricted and
    Incoming folders stay (02-provision-sites.ps1 -Cleanup removes them).

.EXAMPLE
    ./setup/03-upload-content.ps1 -TenantUrl https://contoso.sharepoint.com -ClientId 11111111-2222-3333-4444-555555555555

.EXAMPLE
    ./setup/03-upload-content.ps1 -TenantUrl https://contoso.sharepoint.com -PythonPath py -WhatIf

.EXAMPLE
    ./setup/03-upload-content.ps1 -TenantUrl https://contoso.sharepoint.com -Cleanup

.NOTES
    Runtime is dominated by Archive-Bulk (about 1,200 files) and the Vendors list (about 2,600 rows).
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$TenantUrl,
    [ValidatePattern('^[A-Za-z][A-Za-z0-9]{1,9}$')][string]$Prefix = 'HLE',
    [string]$ClientId = $env:ENTRAID_APP_ID,
    [string]$PythonPath = 'python3',
    [switch]$SkipGenerators,
    [ValidateRange(1, 1000)][int]$BatchSize = 100,
    [switch]$Cleanup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'common.psm1') -Force -Verbose:$false

Write-Step "03 Upload content$(if ($Cleanup) { ' (CLEANUP)' })" -Level Header
if (-not $ClientId) { throw 'Pass -ClientId (your Entra app for PnP.PowerShell) or set $env:ENTRAID_APP_ID. See setup/README.md.' }
Assert-Module -Name 'PnP.PowerShell'

$names = Get-CourseNames -TenantUrl $TenantUrl -Prefix $Prefix
$repo = Get-CourseRepoRoot
$spRoot = Join-Path $repo 'data/sharepoint'
$hubLocal = Join-Path $spRoot 'Harbourline-Hub'
$opsLocal = Join-Path $spRoot 'Harbourline-Operations'
$vendorsCsv = Join-Path $hubLocal 'Vendors.csv'
$handbook = Join-Path $hubLocal 'HR-Policies/Employee-Handbook-Full.docx'
$archiveLocal = Join-Path $opsLocal 'Archive-Bulk'

# Local folder -> (site, library). Folders created by 02 are protected from folder deletion in cleanup.
$protectedFolders = @('Restricted', 'Incoming')
$map = @(
    [pscustomobject]@{ Site = 'Hub'; Library = 'Getting-Started'; Local = (Join-Path $hubLocal 'Getting-Started') }
    [pscustomobject]@{ Site = 'Hub'; Library = 'HR-Policies';     Local = (Join-Path $hubLocal 'HR-Policies') }
    [pscustomobject]@{ Site = 'Hub'; Library = 'Finance';         Local = (Join-Path $hubLocal 'Finance') }
    [pscustomobject]@{ Site = 'Ops'; Library = 'Procedures';      Local = (Join-Path $opsLocal 'Procedures') }
    [pscustomobject]@{ Site = 'Ops'; Library = 'Archive-Bulk';    Local = $archiveLocal }
)
# Guard: never upload the Lab 9 drop files.
$lab9 = [System.IO.Path]::GetFullPath((Join-Path $spRoot 'lab-09-drops'))
foreach ($m in $map) {
    if ([System.IO.Path]::GetFullPath($m.Local).StartsWith($lab9, [System.StringComparison]::OrdinalIgnoreCase)) { throw 'Mapping points at lab-09-drops; refusing.' }
}

function Get-LocalFiles([string]$Root) {
    if (-not (Test-Path -LiteralPath $Root)) { return @() }
    return @(Get-ChildItem -LiteralPath $Root -File -Recurse | Where-Object {
            -not $_.Name.StartsWith('.') -and
            -not ($_.DirectoryName -eq $Root -and $_.Name -ieq 'README.md')
        })
}
function Get-RelDir([string]$Root, [string]$Dir) {
    $rel = [System.IO.Path]::GetRelativePath($Root, $Dir)
    if ($rel -eq '.') { return '' }
    return ($rel -replace '\\', '/')
}
function Get-RemoteFiles($Conn, [string]$FolderSiteRel) {
    $h = @{}
    try {
        foreach ($f in @(Get-PnPFolderItem -FolderSiteRelativeUrl $FolderSiteRel -ItemType File -Connection $Conn -ErrorAction Stop)) {
            $len = -1
            try { $len = [long]$f.Length } catch { $len = -1 }
            $h[[string]$f.Name] = $len
        }
    }
    catch { }
    return $h
}

# =============================================================================================
# CLEANUP
# =============================================================================================
if ($Cleanup) {
    $conns = @{}
    foreach ($site in @('Hub', 'Ops')) {
        $url = if ($site -eq 'Hub') { $names.HubUrl } else { $names.OpsUrl }
        try { $conns[$site] = Connect-CoursePnP -Url $url -ClientId $ClientId -Tenant $names.TenantDomain }
        catch { Write-Step "Cannot connect to $url ($($_.Exception.Message)); skipping its cleanup." -Level Warn }
    }

    function Remove-Uploaded($Conn, [string]$LocalDir, [string]$RemoteDir) {
        $remoteFiles = Get-RemoteFiles $Conn $RemoteDir
        foreach ($f in @(Get-ChildItem -LiteralPath $LocalDir -File | Where-Object { -not $_.Name.StartsWith('.') })) {
            if (-not $remoteFiles.ContainsKey($f.Name)) { continue }
            $null = Invoke-CourseAction -Cmdlet $PSCmdlet -Target "$RemoteDir/$($f.Name)" -Action 'Delete file' -ScriptBlock {
                Remove-PnPFile -SiteRelativeUrl "$RemoteDir/$($f.Name)" -Force -Connection $Conn
            }
        }
        foreach ($d in @(Get-ChildItem -LiteralPath $LocalDir -Directory)) {
            if ($protectedFolders -contains $d.Name) {
                Remove-Uploaded $Conn $d.FullName "$RemoteDir/$($d.Name)"
                continue
            }
            $exists = $true
            try { $null = Get-PnPFolder -Url "$RemoteDir/$($d.Name)" -Connection $Conn -ErrorAction Stop } catch { $exists = $false }
            if (-not $exists) { continue }
            $null = Invoke-CourseAction -Cmdlet $PSCmdlet -Target "$RemoteDir/$($d.Name)" -Action 'Delete folder and its files' -ScriptBlock {
                Remove-PnPFolder -Name $d.Name -Folder $RemoteDir -Force -Connection $Conn
            }
        }
    }

    foreach ($m in $map) {
        if (-not $conns.ContainsKey($m.Site)) { continue }
        if (-not (Test-Path -LiteralPath $m.Local)) { Write-Step "Local folder $($m.Local) missing; nothing to match" -Level Skip; continue }
        Write-Step "Cleaning $($m.Site)/$($m.Library)" -Level Info
        Remove-Uploaded $conns[$m.Site] $m.Local $m.Library
    }

    if ($conns.ContainsKey('Hub') -and (Test-Path -LiteralPath $vendorsCsv)) {
        $ids = @{}
        foreach ($r in (Import-Csv -LiteralPath $vendorsCsv)) { $ids[[string]$r.VendorId] = $true }
        $items = @()
        try { $items = @(Get-PnPListItem -List $names.VendorsList -PageSize 2000 -Fields 'VendorId' -Connection $conns['Hub']) } catch { $items = @() }
        $targets = @($items | Where-Object { $ids.ContainsKey([string]$_['VendorId']) })
        if ($targets.Count -gt 0) {
            $null = Invoke-CourseAction -Cmdlet $PSCmdlet -Target $names.VendorsList -Action "Delete $($targets.Count) list items" -ScriptBlock {
                for ($i = 0; $i -lt $targets.Count; $i += $BatchSize) {
                    $batch = New-PnPBatch -Connection $conns['Hub']
                    foreach ($it in $targets[$i..([Math]::Min($i + $BatchSize, $targets.Count) - 1)]) {
                        Remove-PnPListItem -List $names.VendorsList -Identity $it.Id -Batch $batch -Force
                    }
                    Invoke-PnPBatch -Batch $batch -Connection $conns['Hub']
                    Write-Progress -Activity 'Deleting Vendors items' -PercentComplete ([int](100 * [Math]::Min($i + $BatchSize, $targets.Count) / $targets.Count))
                }
                Write-Progress -Activity 'Deleting Vendors items' -Completed
            }
        }
        else { Write-Step 'No Vendors items to delete' -Level Skip }
    }
    Write-Step '03 cleanup complete' -Level Ok
    return
}

# =============================================================================================
# 1. Generators
# =============================================================================================
$genDir = Join-Path $repo 'tools/generate-data'
function Invoke-Generator([string]$Script, [string]$OutPath, [string]$Label) {
    $gen = Join-Path $genDir $Script
    if (-not (Test-Path -LiteralPath $gen)) { Write-Step "$Script not found; $Label will be missing." -Level Warn; return }
    $null = Invoke-CourseAction -Cmdlet $PSCmdlet -Target $OutPath -Action "Generate $Label with $Script" -ScriptBlock {
        & $PythonPath $gen --out $OutPath
        if ($LASTEXITCODE -ne 0) { throw "$Script exited with code $LASTEXITCODE" }
    }
}
if ($SkipGenerators) { Write-Step 'Generators skipped (-SkipGenerators)' -Level Skip }
else {
    if (Test-Path -LiteralPath $handbook) { Write-Step 'Employee-Handbook-Full.docx present' -Level Skip }
    else { Invoke-Generator 'generate_oversized_handbook.py' $handbook 'oversized handbook' }
    $archiveCount = @(Get-LocalFiles $archiveLocal).Count
    if ($archiveCount -gt 0) { Write-Step "Archive-Bulk present ($archiveCount files)" -Level Skip }
    else { Invoke-Generator 'generate_archive_bulk.py' $archiveLocal 'Archive-Bulk' }
}
if (-not $WhatIfPreference) {
    if (-not (Test-Path -LiteralPath $handbook)) { Write-Step "Expected $handbook after generation, not found. Lab 3 oversized-file test will lack it." -Level Warn }
}

# =============================================================================================
# 2. Upload files
# =============================================================================================
$conns = @{
    Hub = Connect-CoursePnP -Url $names.HubUrl -ClientId $ClientId -Tenant $names.TenantDomain
    Ops = Connect-CoursePnP -Url $names.OpsUrl -ClientId $ClientId -Tenant $names.TenantDomain
}
$uploaded = 0; $skipped = 0
foreach ($m in $map) {
    $files = Get-LocalFiles $m.Local
    if ($files.Count -eq 0) { Write-Step "No local files in $($m.Local)" -Level Warn; continue }
    Write-Step "$($m.Site)/$($m.Library): $($files.Count) local files" -Level Info
    $conn = $conns[$m.Site]
    $folderCache = @{}
    $n = 0
    foreach ($grp in ($files | Group-Object DirectoryName)) {
        $rel = Get-RelDir $m.Local $grp.Name
        $remote = if ($rel) { "$($m.Library)/$rel" } else { $m.Library }
        if ($rel) { Confirm-CourseFolder -SiteRelativePath $remote -Connection $conn -Cache $folderCache -WhatIf:$WhatIfPreference -Confirm:$false }
        $existing = Get-RemoteFiles $conn $remote
        foreach ($f in $grp.Group) {
            $n++
            Write-Progress -Activity "Uploading to $($m.Library)" -Status $f.Name -PercentComplete ([int](100 * $n / $files.Count))
            if ($existing.ContainsKey($f.Name) -and ($existing[$f.Name] -eq $f.Length -or $existing[$f.Name] -lt 0)) { $skipped++; continue }
            $r = Invoke-CourseAction -Cmdlet $PSCmdlet -Target "$remote/$($f.Name)" -Action 'Upload file' -ScriptBlock {
                Add-PnPFile -Path $f.FullName -Folder $remote -Connection $conn | Out-Null; $true
            }
            if ($r) { $uploaded++ }
        }
    }
    Write-Progress -Activity "Uploading to $($m.Library)" -Completed
}
Write-Step "Files uploaded: $uploaded, skipped (same name and size): $skipped" -Level Ok

# =============================================================================================
# 3. Vendors list
# =============================================================================================
if (-not (Test-Path -LiteralPath $vendorsCsv)) {
    Write-Step 'Vendors.csv not found; list import skipped.' -Level Warn
}
else {
    $rows = @(Import-Csv -LiteralPath $vendorsCsv)
    $hubConn = $conns['Hub']
    $existingIds = @{}
    foreach ($it in @(Get-PnPListItem -List $names.VendorsList -PageSize 2000 -Fields 'VendorId' -Connection $hubConn)) {
        $v = [string]$it['VendorId']; if ($v) { $existingIds[$v] = $true }
    }
    $new = @($rows | Where-Object { -not $existingIds.ContainsKey([string]$_.VendorId) })
    Write-Step "Vendors: $($rows.Count) rows in CSV, $($existingIds.Count) already in list, $($new.Count) to add" -Level Info
    $numberCols = @('ContractValue'); $dateCols = @('RenewalDate')
    $inv = [System.Globalization.CultureInfo]::InvariantCulture
    if ($new.Count -gt 0) {
        $null = Invoke-CourseAction -Cmdlet $PSCmdlet -Target $names.VendorsList -Action "Add $($new.Count) items in batches of $BatchSize" -ScriptBlock {
            for ($i = 0; $i -lt $new.Count; $i += $BatchSize) {
                $batch = New-PnPBatch -Connection $hubConn
                foreach ($row in $new[$i..([Math]::Min($i + $BatchSize, $new.Count) - 1)]) {
                    $values = @{}
                    foreach ($p in $row.PSObject.Properties) {
                        $val = [string]$p.Value
                        if ([string]::IsNullOrWhiteSpace($val)) { continue }
                        $internal = if ($p.Name -eq 'Title') { 'Title' } else { ($p.Name -replace '[^A-Za-z0-9]', '') }
                        if ($numberCols -contains $p.Name) { $values[$internal] = [double]::Parse($val, $inv) }
                        elseif ($dateCols -contains $p.Name) { $values[$internal] = [datetime]::Parse($val, $inv) }
                        else { $values[$internal] = $val }
                    }
                    Add-PnPListItem -List $names.VendorsList -Values $values -Batch $batch | Out-Null
                }
                Invoke-PnPBatch -Batch $batch -Connection $hubConn
                Write-Progress -Activity 'Importing Vendors' -PercentComplete ([int](100 * [Math]::Min($i + $BatchSize, $new.Count) / $new.Count))
            }
            Write-Progress -Activity 'Importing Vendors' -Completed
        }
    }
}

Write-Step '03 upload complete. Next: 04-apply-labels.ps1' -Level Ok
