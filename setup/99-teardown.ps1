<#
.SYNOPSIS
    Removes everything the setup scripts created, in reverse order (04, 03, 02, 01).

.DESCRIPTION
    Asks for confirmation once (skip with -Force), then runs:
      04-apply-labels.ps1     -Cleanup   label policy and label
      03-upload-content.ps1   -Cleanup   uploaded files and Vendors list items
      02-provision-sites.ps1  -Cleanup   Hub site, Operations group and site (purge with -Force)
      01-provision-users.ps1  -Cleanup   tagged personas, guest and groups (-PurgeDeleted optional)
    00-prereqs-check.ps1 is read-only and has nothing to remove.

    A failure in one step is reported and the next step still runs. -WhatIf is passed through, so
    ./99-teardown.ps1 -WhatIf previews every deletion without changing anything.

    Artifacts created during the labs (agents, Power Platform environments, app registrations,
    connector connections and so on) are NOT removed. The script lists each labs/*/cleanup.md so
    you can work through them.

.PARAMETER TenantUrl
    Root SharePoint URL, for example https://contoso.sharepoint.com.

.PARAMETER Prefix
    Course object prefix. Default HLE.

.PARAMETER ClientId
    Application (client) ID of your Entra app registration for PnP.PowerShell. Defaults to $env:ENTRAID_APP_ID.

.PARAMETER Domain
    Persona UPN domain. Default: the tenant's default verified domain.

.PARAMETER GuestEmail
    Guest address, so 01 can find the guest directly (otherwise it searches by tag).

.PARAMETER GraphClientId
    Optional client ID for Connect-MgGraph in 01.

.PARAMETER Force
    Skip the confirmation prompt and purge deleted sites and groups from recycle bins.

.PARAMETER PurgeDeleted
    Also permanently delete removed users and groups from the Entra recycle bin (passed to 01).

.PARAMETER Cleanup
    Accepted for consistency with the other scripts. Teardown always cleans up.

.EXAMPLE
    ./setup/99-teardown.ps1 -TenantUrl https://contoso.sharepoint.com -WhatIf

.EXAMPLE
    ./setup/99-teardown.ps1 -TenantUrl https://contoso.sharepoint.com -ClientId 11111111-2222-3333-4444-555555555555 -GuestEmail someone@outlook.com

.EXAMPLE
    ./setup/99-teardown.ps1 -TenantUrl https://contoso.sharepoint.com -Force -PurgeDeleted
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][string]$TenantUrl,
    [ValidatePattern('^[A-Za-z][A-Za-z0-9]{1,9}$')][string]$Prefix = 'HLE',
    [string]$ClientId = $env:ENTRAID_APP_ID,
    [string]$Domain,
    [string]$GuestEmail,
    [string]$GraphClientId,
    [switch]$Force,
    [switch]$PurgeDeleted,
    [switch]$Cleanup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'common.psm1') -Verbose:$false

$names = Get-CourseNames -TenantUrl $TenantUrl -Prefix $Prefix
Write-Step "99 Teardown for prefix $Prefix on $($names.RootUrl)" -Level Header
Write-Host @"
This removes:
  - label policy $($names.LabelPolicyName) and label $($names.LabelName)
  - uploaded course files and Vendors list items
  - sites $($names.HubUrl) and $($names.OpsUrl) (and the $($names.OpsAlias) Microsoft 365 group)
  - persona users, the guest and the $Prefix-* course groups (only objects tagged $($names.Tag))
"@
if (-not $ClientId) { throw 'Pass -ClientId (your Entra app for PnP.PowerShell) or set $env:ENTRAID_APP_ID.' }

if (-not $WhatIfPreference -and -not $Force) {
    if (-not $PSCmdlet.ShouldContinue("Delete all course objects for prefix '$Prefix'? This cannot be fully undone.", 'Confirm teardown')) {
        Write-Step 'Teardown cancelled' -Level Skip
        return
    }
}

$common = @{ TenantUrl = $TenantUrl; Prefix = $Prefix; Cleanup = $true; WhatIf = [bool]$WhatIfPreference; Confirm = $false }
$steps = @(
    @{ Script = '04-apply-labels.ps1';    Extra = @{ ClientId = $ClientId } }
    @{ Script = '03-upload-content.ps1';  Extra = @{ ClientId = $ClientId } }
    @{ Script = '02-provision-sites.ps1'; Extra = @{ ClientId = $ClientId; Force = [bool]$Force } }
    @{ Script = '01-provision-users.ps1'; Extra = @{ PurgeDeleted = [bool]$PurgeDeleted } }
)
if ($Domain) { foreach ($s in $steps) { if ($s.Script -ne '03-upload-content.ps1') { $s.Extra['Domain'] = $Domain } } }
if ($GuestEmail) { $steps[3].Extra['GuestEmail'] = $GuestEmail }
if ($GraphClientId) { $steps[3].Extra['GraphClientId'] = $GraphClientId }

$outcome = New-Object System.Collections.Generic.List[object]
foreach ($s in $steps) {
    $path = Join-Path $PSScriptRoot $s.Script
    $splat = $common.Clone()
    foreach ($k in $s.Extra.Keys) { $splat[$k] = $s.Extra[$k] }
    # 02 prompts for purge unless -Force; with teardown's own confirmation that prompt is still shown.
    if ($s.Script -eq '02-provision-sites.ps1' -and -not $Force) { $splat.Remove('Force') }
    try {
        & $path @splat
        $outcome.Add([pscustomobject]@{ Area = 'Teardown'; Check = $s.Script; Status = 'PASS'; Detail = 'Cleanup ran' })
    }
    catch {
        Write-Step "$($s.Script) -Cleanup failed: $($_.Exception.Message)" -Level Error
        $outcome.Add([pscustomobject]@{ Area = 'Teardown'; Check = $s.Script; Status = 'WARN'; Detail = $_.Exception.Message })
    }
}
Write-CourseSummary -Rows $outcome.ToArray() -Title 'Teardown summary'

# ---- Lab artifacts reminder ------------------------------------------------------------------
Write-Step 'Lab-created artifacts are not removed by this script' -Level Header
$labsDir = Join-Path (Get-CourseRepoRoot) 'labs'
$cleanupDocs = @()
if (Test-Path -LiteralPath $labsDir) { $cleanupDocs = @(Get-ChildItem -LiteralPath $labsDir -Filter 'cleanup.md' -Recurse -File | Sort-Object FullName) }
if ($cleanupDocs.Count -gt 0) {
    Write-Host 'Work through each lab cleanup file:'
    foreach ($d in $cleanupDocs) { Write-Host "  - $([System.IO.Path]::GetRelativePath((Get-CourseRepoRoot), $d.FullName))" }
}
else {
    Write-Host 'No labs/*/cleanup.md files found in this checkout.'
}
Write-Host @"
Typical lab artifacts to remove by hand:
  - Agent Builder agents (Labs 1, 2) and Copilot Studio agents (Labs 3, 4, 5, 9, 10, 12)
  - Declarative agent app packages uploaded to Teams (Lab 6) and custom engine agent resources (Lab 8)
  - Power Platform environments $Prefix-Dev, $Prefix-Test, $Prefix-Prod, pipelines, solutions (Labs 4, 11)
  - Entra app registrations for PnP, connectors, the mock API and the Agents SDK bot (Labs 5 to 8)
  - The Copilot connector connection and its items (Lab 7: ingest-tickets.ps1 -Cleanup)
  - Azure resources: Functions app, SQL database, Bot Service, Foundry project (Labs 5 to 8)
  - Pay-as-you-go billing plan, if it was created only for the course
  - The local initial-password file under ~/.harbourline-course/
"@
