<#
.SYNOPSIS
    Lab 11 fallback deployment: export HLEHarbourlineOps from HLE-Dev and import it as a managed
    solution into HLE-Test or HLE-Prod with the Power Platform CLI (pac).

.DESCRIPTION
    Use this script when a pipeline is not available (for example the targets are not managed
    environments, see README Part D2 and break-it C-11-a). It is idempotent:

      1. Checks that pac is on PATH.
      2. Creates pac auth profiles <Prefix>-Dev and <Prefix>-<Stage> only if they do not exist
         (interactive sign-in), then uses --environment on every command so the active profile
         does not matter.
      3. Confirms the solution exists in the source environment and reads its version.
      4. Exports the unmanaged zip (for source control) and the managed zip, unless zips for that
         version already exist in -OutputFolder (use -ForceExport to export again).
      5. Creates deployment-settings.<Stage>.json with 'pac solution create-settings' if it does
         not exist, then stops so you can fill in the values.
      6. Refuses to import while any environment variable value or connection ID is empty.
      7. Imports the managed zip with --settings-file and --skip-lower-version (so re-running with
         the same version does nothing). It never passes --force-overwrite (see break-it C-11-c).
      8. Lists the solutions in the target.

    -Cleanup deletes the solution from the TARGET environment (never from the source), removes the
    zips and settings files this script wrote for that version and stage, and with
    -RemoveAuthProfiles deletes the pac auth profiles it created. Deleting a managed solution
    removes its components and the rows of its custom tables (hle_Asset, hle_Crew, hle_WorkOrder).

    pac parameter names were taken from the Power Platform CLI reference (pac solution, pac auth)
    in the MicrosoftDocs/power-platform repository on 2026-09-30. pac prints human-readable tables;
    the parsing of 'pac solution list' output below is a best effort. If it fails, check the output
    format of your pac version.

.PARAMETER TenantUrl
    SharePoint tenant URL (for example https://contoso.sharepoint.com). Not used by pac. Accepted
    for consistency with the other course scripts and printed in the summary.

.PARAMETER Prefix
    Course prefix (default HLE). The solution unique name is <Prefix>HarbourlineOps.

.PARAMETER SourceEnvironmentUrl
    Dataverse URL of the development environment (HLE-Dev), for example https://hle-dev-xxxx.crm.dynamics.com

.PARAMETER TargetEnvironmentUrl
    Dataverse URL of the target environment (HLE-Test or HLE-Prod).

.PARAMETER Stage
    Test or Prod. Used for the auth profile name and the settings file name.

.PARAMETER OutputFolder
    Folder for the exported zips and the settings file. Default ./out/lab-11

.PARAMETER SettingsFile
    Path to the deployment settings file. Default <OutputFolder>/deployment-settings.<Stage>.json

.PARAMETER ForceExport
    Export again even if zips for the current version exist.

.PARAMETER Cleanup
    Delete the solution from the target and remove local files this script created.

.PARAMETER RemoveAuthProfiles
    With -Cleanup, also delete the pac auth profiles <Prefix>-Dev and <Prefix>-<Stage>.

.EXAMPLE
    ./Invoke-HleSolutionDeployment.ps1 -SourceEnvironmentUrl https://hle-dev.crm.dynamics.com -TargetEnvironmentUrl https://hle-test.crm.dynamics.com -Stage Test

.EXAMPLE
    ./Invoke-HleSolutionDeployment.ps1 -SourceEnvironmentUrl https://hle-dev.crm.dynamics.com -TargetEnvironmentUrl https://hle-prod.crm.dynamics.com -Stage Prod -Cleanup -WhatIf
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [string]$TenantUrl,

    [ValidatePattern('^[A-Za-z][A-Za-z0-9]{1,7}$')]
    [string]$Prefix = 'HLE',

    [Parameter(Mandatory)]
    [ValidatePattern('^https://')]
    [string]$SourceEnvironmentUrl,

    [Parameter(Mandatory)]
    [ValidatePattern('^https://')]
    [string]$TargetEnvironmentUrl,

    [Parameter(Mandatory)]
    [ValidateSet('Test', 'Prod')]
    [string]$Stage,

    [string]$OutputFolder = (Join-Path (Get-Location) 'out/lab-11'),

    [string]$SettingsFile,

    [switch]$ForceExport,

    [switch]$Cleanup,

    [switch]$RemoveAuthProfiles
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$SolutionName = "$($Prefix.ToUpperInvariant())HarbourlineOps"
$SourceEnvironmentUrl = $SourceEnvironmentUrl.TrimEnd('/')
$TargetEnvironmentUrl = $TargetEnvironmentUrl.TrimEnd('/')
$DevProfile = "$Prefix-Dev"
$TargetProfile = "$Prefix-$Stage"
if (-not $SettingsFile) { $SettingsFile = Join-Path $OutputFolder "deployment-settings.$Stage.json" }

function Write-Step([string]$Message) { Write-Host "==> $Message" -ForegroundColor Cyan }

function Invoke-Pac {
    <# Runs pac with the given arguments, returns stdout lines, throws on a non-zero exit code. #>
    param([Parameter(Mandatory)][string[]]$Arguments, [switch]$AllowFailure)
    Write-Verbose ("pac " + ($Arguments -join ' '))
    $out = & pac @Arguments 2>&1 | ForEach-Object { "$_" }
    $code = $LASTEXITCODE
    if ($code -ne 0 -and -not $AllowFailure) {
        throw "pac $($Arguments[0]) $($Arguments[1]) failed (exit $code):`n$($out -join [Environment]::NewLine)"
    }
    return $out
}

function Assert-Pac {
    if (-not (Get-Command pac -ErrorAction SilentlyContinue)) {
        throw 'The Power Platform CLI (pac) is not on PATH. Install it (for example: dotnet tool install --global Microsoft.PowerApps.CLI.Tool) and open a new shell.'
    }
}

function Initialize-AuthProfile([string]$Name, [string]$Url) {
    $list = Invoke-Pac -Arguments @('auth', 'list')
    $exists = $list | Where-Object { $_ -match "(^|\s)$([regex]::Escape($Name))(\s|$)" }
    if ($exists) {
        Write-Host "pac auth profile '$Name' exists"
        return
    }
    if ($PSCmdlet.ShouldProcess($Name, "Create pac auth profile for $Url (interactive sign-in)")) {
        Invoke-Pac -Arguments @('auth', 'create', '--name', $Name, '--environment', $Url) | Out-Null
        Write-Host "Created pac auth profile '$Name'"
    }
}

function Get-SolutionVersion([string]$EnvironmentUrl) {
    <# Returns the version string of $SolutionName in the environment, or $null. #>
    $lines = Invoke-Pac -Arguments @('solution', 'list', '--environment', $EnvironmentUrl)
    foreach ($line in $lines) {
        if ($line -match "(^|\s)$([regex]::Escape($SolutionName))(\s)") {
            $m = [regex]::Match($line, '\b\d+\.\d+\.\d+\.\d+\b')
            if ($m.Success) { return $m.Value }
            return 'unknown'
        }
    }
    return $null
}

function Test-SettingsComplete([string]$Path) {
    $json = Get-Content -Raw -Path $Path | ConvertFrom-Json
    $missing = [System.Collections.Generic.List[string]]::new()
    if ($json.PSObject.Properties.Name -contains 'EnvironmentVariables') {
        foreach ($ev in @($json.EnvironmentVariables)) {
            if ([string]::IsNullOrWhiteSpace([string]$ev.Value) -or [string]$ev.Value -match '[<>]') { $missing.Add("EnvironmentVariables: $($ev.SchemaName) has no Value (or still holds a <placeholder>)") }
            elseif ([string]$ev.Value -match 'devtunnels\.ms' -and $Stage -eq 'Prod') {
                Write-Warning "$($ev.SchemaName) points at a dev tunnel in a Prod settings file (break-it C-11-f)."
            }
        }
    }
    if ($json.PSObject.Properties.Name -contains 'ConnectionReferences') {
        foreach ($cr in @($json.ConnectionReferences)) {
            if ([string]::IsNullOrWhiteSpace([string]$cr.ConnectionId) -or [string]$cr.ConnectionId -match '[<>]') { $missing.Add("ConnectionReferences: $($cr.LogicalName) has no ConnectionId (or still holds a <placeholder>)") }
        }
    }
    return , $missing.ToArray()
}

# ------------------------------------------------------------------ main
Assert-Pac
if ($SourceEnvironmentUrl -eq $TargetEnvironmentUrl) {
    throw 'Source and target are the same environment. You cannot import a managed solution into the environment that holds the originating unmanaged solution.'
}

Write-Host "Solution:  $SolutionName"
Write-Host "Source:    $SourceEnvironmentUrl ($DevProfile)"
Write-Host "Target:    $TargetEnvironmentUrl ($TargetProfile, stage $Stage)"
if ($TenantUrl) { Write-Host "Tenant:    $TenantUrl" }

if ($Cleanup) {
    $targetVersion = Get-SolutionVersion $TargetEnvironmentUrl
    if ($targetVersion) {
        if ($PSCmdlet.ShouldProcess("$SolutionName in $TargetEnvironmentUrl", 'Delete solution (managed: removes components and custom table data)')) {
            Invoke-Pac -Arguments @('solution', 'delete', '--solution-name', $SolutionName, '--environment', $TargetEnvironmentUrl) | Out-Null
            Write-Host "Deleted $SolutionName $targetVersion from $TargetEnvironmentUrl"
        }
    }
    else {
        Write-Host "$SolutionName is not in the target; nothing to delete there."
    }
    $patterns = @("$($SolutionName)_*.zip", "deployment-settings.$Stage.json")
    foreach ($p in $patterns) {
        foreach ($f in @(Get-ChildItem -Path $OutputFolder -Filter $p -ErrorAction SilentlyContinue)) {
            if ($PSCmdlet.ShouldProcess($f.FullName, 'Remove local file')) { Remove-Item -LiteralPath $f.FullName }
        }
    }
    if ($RemoveAuthProfiles) {
        foreach ($name in @($DevProfile, $TargetProfile)) {
            if ($PSCmdlet.ShouldProcess($name, 'Delete pac auth profile')) {
                Invoke-Pac -Arguments @('auth', 'delete', '--name', $name) -AllowFailure | Out-Null
            }
        }
    }
    Write-Host 'Cleanup complete. The source solution in HLE-Dev was not touched.'
    return
}

Write-Step 'Auth profiles'
Initialize-AuthProfile $DevProfile $SourceEnvironmentUrl
Initialize-AuthProfile $TargetProfile $TargetEnvironmentUrl

Write-Step 'Source solution'
$sourceVersion = Get-SolutionVersion $SourceEnvironmentUrl
if (-not $sourceVersion) {
    throw "$SolutionName not found in $SourceEnvironmentUrl. Run data/dataverse/import-dataverse.ps1 -SkipData against HLE-Dev and complete README Part B."
}
Write-Host "Source version: $sourceVersion"
$versionTag = $sourceVersion -replace '\.', '_'

New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
$unmanagedZip = Join-Path $OutputFolder "$($SolutionName)_$versionTag.zip"
$managedZip = Join-Path $OutputFolder "$($SolutionName)_$($versionTag)_managed.zip"

Write-Step 'Export'
foreach ($item in @(@{ Path = $unmanagedZip; Managed = $false }, @{ Path = $managedZip; Managed = $true })) {
    if ((Test-Path $item.Path) -and -not $ForceExport) {
        Write-Host "Exists, not exporting again: $($item.Path)"
        continue
    }
    $kind = if ($item.Managed) { 'managed' } else { 'unmanaged' }
    if ($PSCmdlet.ShouldProcess($item.Path, "Export $SolutionName $sourceVersion ($kind)")) {
        $exportArgs = @('solution', 'export', '--name', $SolutionName, '--path', $item.Path, '--environment', $SourceEnvironmentUrl, '--overwrite')
        if ($item.Managed) { $exportArgs += '--managed' }
        Invoke-Pac -Arguments $exportArgs | Out-Null
        Write-Host "Exported $kind zip: $($item.Path)"
    }
}

Write-Step 'Deployment settings'
if (-not (Test-Path $SettingsFile)) {
    if ($PSCmdlet.ShouldProcess($SettingsFile, 'Create deployment settings file with pac solution create-settings')) {
        Invoke-Pac -Arguments @('solution', 'create-settings', '--solution-zip', $managedZip, '--settings-file', $SettingsFile) | Out-Null
        Write-Host "Created $SettingsFile"
        Write-Host 'Fill in every Value and ConnectionId (see solutions/lab-11/deployment-settings.sample.json), then run this script again.'
    }
    return
}
$missing = Test-SettingsComplete $SettingsFile
if ($missing.Count -gt 0) {
    $missing | ForEach-Object { Write-Warning $_ }
    throw "Deployment settings are incomplete in $SettingsFile. Not importing (break-it C-11-f)."
}

Write-Step 'Import'
$targetVersion = Get-SolutionVersion $TargetEnvironmentUrl
if ($targetVersion) { Write-Host "Target currently has version $targetVersion" } else { Write-Host 'Target does not have the solution yet' }
if ($targetVersion -and $targetVersion -ne 'unknown' -and ([version]$targetVersion -ge [version]$sourceVersion)) {
    Write-Host "Target already has $targetVersion (source $sourceVersion). Nothing to import. Bump the version in HLE-Dev to deploy a change."
}
elseif ($PSCmdlet.ShouldProcess($TargetEnvironmentUrl, "Import $managedZip (managed) with $SettingsFile")) {
    Invoke-Pac -Arguments @('solution', 'import', '--path', $managedZip, '--environment', $TargetEnvironmentUrl,
        '--settings-file', $SettingsFile, '--skip-lower-version', '--async', '--max-async-wait-time', '60') | ForEach-Object { Write-Host $_ }
}

Write-Step 'Verify'
$after = Get-SolutionVersion $TargetEnvironmentUrl
Write-Host "Target now reports $SolutionName version: $(if ($after) { $after } else { 'not found' })"
Write-Host 'Next: README Part E (load data with import-dataverse.ps1, check flows are On, publish the agent in the target).'
