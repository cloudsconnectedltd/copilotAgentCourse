<#
.SYNOPSIS
    Read-only tenant readiness check for the Harbourline Energy Copilot agent course.

.DESCRIPTION
    Checks what can be read with Microsoft Graph, PnP.PowerShell and (if installed) MicrosoftTeams,
    and prints a manual checklist for the rest. Nothing in the tenant is changed.

    Checks:
      1. Licenses (Graph subscribedSkus): SKUs whose skuPartNumber contains "Copilot", with
         enabled, consumed and free units. All SKUs are listed so you can choose
         -BaseSkuPartNumber and -CopilotSkuPartNumber for 01-provision-users.ps1.
      2. Directory roles held by the signed-in user (active assignments, including via groups).
      3. SharePoint tenant settings (Get-PnPTenant): SharingCapability, guest expiration,
         EnableAIPIntegration (sensitivity labels for Office files), Restricted SharePoint Search.
      4. Teams app setup policy "Upload custom apps" (limits.md DA-17). Uses
         Get-CsTeamsAppSetupPolicy when the MicrosoftTeams module is installed, otherwise MANUAL.
      5. Manual checklist: Agents settings (ADM-01, ADM-02), Copilot Studio app deployment and
         generative AI in Power Platform (ADM-07), authors group (ADM-08), pay-as-you-go (LIC-07, LIC-08).

    Output is a summary table with Status PASS, WARN or MANUAL.

.PARAMETER TenantUrl
    Root SharePoint URL, for example https://contoso.sharepoint.com.

.PARAMETER Prefix
    Course object prefix. Default HLE.

.PARAMETER ClientId
    Application (client) ID of your Entra app registration for PnP.PowerShell interactive sign-in.
    Without it the SharePoint checks are reported as MANUAL. Defaults to $env:ENTRAID_APP_ID.

.PARAMETER GraphClientId
    Optional client ID for Connect-MgGraph. Omit to use the Microsoft Graph Command Line Tools app.

.PARAMETER RequiredCopilotSeats
    Number of Microsoft 365 Copilot seats the course needs (learner plus hr, tech, fin personas). Default 4.

.PARAMETER ReportPath
    Optional CSV path to save the summary table.

.PARAMETER Cleanup
    No-op. This script is read-only; it prints a message and exits.

.EXAMPLE
    ./setup/00-prereqs-check.ps1 -TenantUrl https://contoso.sharepoint.com -ClientId 11111111-2222-3333-4444-555555555555

.EXAMPLE
    ./setup/00-prereqs-check.ps1 -TenantUrl https://contoso.sharepoint.com -Prefix HLE -ReportPath ./prereqs.csv

.NOTES
    Required delegated Graph scopes: Organization.Read.All, Directory.Read.All.
    Required role for SharePoint checks: SharePoint Administrator or Global Administrator.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$TenantUrl,
    [ValidatePattern('^[A-Za-z][A-Za-z0-9]{1,9}$')][string]$Prefix = 'HLE',
    [string]$ClientId = $env:ENTRAID_APP_ID,
    [string]$GraphClientId,
    [int]$RequiredCopilotSeats = 4,
    [string]$ReportPath,
    [switch]$Cleanup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'common.psm1') -Force -Verbose:$false

Write-Step '00 Prerequisites check (read-only)' -Level Header
if ($Cleanup) {
    Write-Step '-Cleanup is a no-op for 00-prereqs-check.ps1: this script makes no changes, so there is nothing to remove.' -Level Info
    return
}

$names = Get-CourseNames -TenantUrl $TenantUrl -Prefix $Prefix
$results = New-Object System.Collections.Generic.List[object]
function Add-Result([string]$Area, [string]$Check, [ValidateSet('PASS', 'WARN', 'MANUAL')][string]$Status, [string]$Detail) {
    $results.Add([pscustomobject]@{ Area = $Area; Check = $Check; Status = $Status; Detail = $Detail })
}

# ---------------------------------------------------------------------------------------------
# 1 and 2: Graph (licenses, roles)
# ---------------------------------------------------------------------------------------------
$graphOk = $false
try {
    Assert-Module -Name 'Microsoft.Graph.Authentication', 'Microsoft.Graph.Identity.DirectoryManagement'
    $null = Connect-CourseGraph -Scopes 'Organization.Read.All', 'Directory.Read.All' -TenantId $names.TenantDomain -ClientId $GraphClientId
    $graphOk = $true
}
catch {
    Add-Result 'Graph' 'Connect Microsoft Graph' 'WARN' "Could not connect: $($_.Exception.Message)"
}

if ($graphOk) {
    Write-Step 'Licenses (subscribedSkus)' -Level Header
    $skus = @(Get-MgSubscribedSku -All)
    $skuRows = foreach ($s in $skus) {
        $enabled = [int]$s.PrepaidUnits.Enabled
        [pscustomobject]@{
            SkuPartNumber = $s.SkuPartNumber
            Enabled       = $enabled
            Consumed      = [int]$s.ConsumedUnits
            Free          = $enabled - [int]$s.ConsumedUnits
            Status        = $s.CapabilityStatus
        }
    }
    Write-Host 'All subscribed SKUs (use these part numbers for 01-provision-users.ps1):'
    $skuRows | Sort-Object SkuPartNumber | Format-Table -AutoSize | Out-String -Width 200 | Write-Host

    $copilot = @($skuRows | Where-Object { $_.SkuPartNumber -match 'Copilot' })
    # SKUs mentioning Copilot Studio are not the Microsoft 365 Copilot add-on; report them separately.
    $m365Copilot = @($copilot | Where-Object { $_.SkuPartNumber -notmatch 'Studio' })
    $studio = @($copilot | Where-Object { $_.SkuPartNumber -match 'Studio' })
    if ($m365Copilot.Count -eq 0) {
        Add-Result 'Licensing' 'Microsoft 365 Copilot SKU present' 'WARN' 'No SKU with "Copilot" in skuPartNumber (excluding Studio). Personas hr, tech, fin and the learner need Copilot (LIC-01).'
    }
    else {
        foreach ($c in $m365Copilot) {
            $detail = "$($c.SkuPartNumber): enabled $($c.Enabled), consumed $($c.Consumed), free $($c.Free). Course needs up to $RequiredCopilotSeats seats (fewer if already assigned)."
            # Free seats cover the course only if the personas are not yet licensed; WARN asks you to check.
            $status = if ($c.Free -ge $RequiredCopilotSeats) { 'PASS' } else { 'WARN' }
            Add-Result 'Licensing' 'Microsoft 365 Copilot seats' $status $detail
        }
    }
    foreach ($c in $studio) {
        Add-Result 'Licensing' 'Copilot Studio SKU (info)' 'PASS' "$($c.SkuPartNumber): enabled $($c.Enabled), consumed $($c.Consumed). Capacity pack or pay-as-you-go needed for Labs 3 to 12 (LIC-06, LIC-07)."
    }
    if ($studio.Count -eq 0) {
        Add-Result 'Licensing' 'Copilot Studio capacity or pay-as-you-go' 'MANUAL' 'No SKU with "Copilot" and "Studio" found. Confirm a capacity pack (LIC-06) or pay-as-you-go billing plan (LIC-07) exists.'
    }

    Write-Step 'Directory roles of the signed-in user' -Level Header
    $wanted = @('Global Administrator', 'AI Administrator', 'SharePoint Administrator', 'Teams Administrator',
        'Power Platform Administrator', 'Search Administrator', 'Compliance Administrator')
    $held = @()
    try {
        $roles = @(Invoke-CourseGraph -Uri 'v1.0/me/transitiveMemberOf/microsoft.graph.directoryRole?$select=displayName,roleTemplateId' -All)
        $held = @($roles | ForEach-Object { Get-CourseProp $_ 'displayName' })
    }
    catch {
        Add-Result 'Roles' 'Read role membership' 'WARN' "Could not read roles: $($_.Exception.Message)"
    }
    $isGA = $held -contains 'Global Administrator'
    foreach ($r in $wanted) {
        if ($held -contains $r) {
            Add-Result 'Roles' $r 'PASS' 'Active assignment found.'
        }
        elseif ($isGA) {
            Add-Result 'Roles' $r 'PASS' 'Not assigned directly; Global Administrator covers it. The course recommends least privilege for daily work.'
        }
        else {
            Add-Result 'Roles' $r 'WARN' 'Not active. If it is PIM-eligible, activate it before the lab that needs it (see PLAN.md section 3).'
        }
    }
}

# ---------------------------------------------------------------------------------------------
# 3: SharePoint tenant settings
# ---------------------------------------------------------------------------------------------
Write-Step 'SharePoint tenant settings' -Level Header
if (-not $ClientId) {
    Add-Result 'SharePoint' 'Tenant settings' 'MANUAL' 'No -ClientId given (PnP needs your own Entra app). In SharePoint admin center > Policies > Sharing, confirm external sharing allows "New and existing guests" or "Existing guests"; confirm sensitivity labels for files are on.'
}
else {
    try {
        Assert-Module -Name 'PnP.PowerShell'
        $admin = Connect-CoursePnP -Url $names.AdminUrl -ClientId $ClientId -Tenant $names.TenantDomain
        $t = Get-PnPTenant -Connection $admin

        $sharing = [string](Get-CourseProp $t 'SharingCapability')
        if ($sharing -in @('ExternalUserSharingOnly', 'ExternalUserAndGuestSharing')) {
            Add-Result 'SharePoint' 'Tenant SharingCapability' 'PASS' "$sharing (the Operations site needs ExternalUserSharingOnly or higher at tenant level)."
        }
        else {
            Add-Result 'SharePoint' 'Tenant SharingCapability' 'WARN' "$sharing. The Operations site needs guest sharing; the tenant level must allow at least ExternalUserSharingOnly."
        }

        $expReq = Get-CourseProp $t 'ExternalUserExpirationRequired'
        $expDays = Get-CourseProp $t 'ExternalUserExpireInDays'
        if ($expReq -eq $true) {
            Add-Result 'SharePoint' 'Guest access expiration' 'WARN' "Guest access expires after $expDays days. Re-invite the guest if the course runs longer."
        }
        else {
            Add-Result 'SharePoint' 'Guest access expiration' 'PASS' 'Not required.'
        }

        $aip = Get-CourseProp $t 'EnableAIPIntegration'
        if ($aip -eq $true) {
            Add-Result 'SharePoint' 'Sensitivity labels for Office files (EnableAIPIntegration)' 'PASS' 'Enabled.'
        }
        elseif ($null -eq $aip) {
            Add-Result 'SharePoint' 'Sensitivity labels for Office files' 'MANUAL' 'Property not returned by this PnP version. Check with Get-SPOTenant | Select EnableAIPIntegration.'
        }
        else {
            Add-Result 'SharePoint' 'Sensitivity labels for Office files (EnableAIPIntegration)' 'WARN' 'Disabled. 04-apply-labels.ps1 needs it for the Lab 3 encrypted file (CS-K08).'
        }

        if (Get-Command -Name 'Get-PnPTenantRestrictedSearchMode' -ErrorAction SilentlyContinue) {
            $rss = Get-PnPTenantRestrictedSearchMode -Connection $admin
            $rssText = ($rss | Out-String).Trim()
            if ($rssText -match 'Enabled') {
                Add-Result 'SharePoint' 'Restricted SharePoint Search' 'WARN' "Appears enabled ($rssText). SharePoint knowledge is unavailable in Agent Builder when RSS is on (AB-07)."
            }
            else {
                Add-Result 'SharePoint' 'Restricted SharePoint Search' 'PASS' "Reported: $rssText"
            }
        }
        else {
            Add-Result 'SharePoint' 'Restricted SharePoint Search' 'MANUAL' 'Cmdlet not in this PnP version. In SharePoint Online Management Shell run Get-SPOTenantRestrictedSearchMode; expected Disabled (AB-07).'
        }

        foreach ($u in @($names.HubUrl, $names.OpsUrl)) {
            $s = Get-CourseTenantSite -Url $u -Connection $admin
            $state = if ($s) { 'exists (02 will reuse it)' } else { 'not created yet' }
            Add-Result 'SharePoint' "Course site $u" 'PASS' $state
        }
    }
    catch {
        Add-Result 'SharePoint' 'Tenant settings' 'WARN' "PnP check failed: $($_.Exception.Message). Check manually in SharePoint admin center."
    }
}

# ---------------------------------------------------------------------------------------------
# 4: Teams custom app upload (DA-17)
# ---------------------------------------------------------------------------------------------
Write-Step 'Teams custom app upload' -Level Header
$teamsManual = 'Teams admin center > Teams apps > Setup policies > Global (Org-wide default): Upload custom apps = On (DA-17). Also confirm custom apps are allowed in Teams apps > Manage apps > Org-wide app settings.'
if (Test-CourseModule -Name 'MicrosoftTeams') {
    try {
        Import-Module MicrosoftTeams -Verbose:$false | Out-Null
        Write-Step 'Connecting MicrosoftTeams (interactive)' -Level Action
        Connect-MicrosoftTeams | Out-Null
        $pol = Get-CsTeamsAppSetupPolicy -Identity Global
        if ($pol.AllowSideLoading) {
            Add-Result 'Teams' 'Global setup policy AllowSideLoading' 'PASS' 'Upload custom apps is On in the Global policy.'
        }
        else {
            Add-Result 'Teams' 'Global setup policy AllowSideLoading' 'WARN' "Off. $teamsManual"
        }
        Add-Result 'Teams' 'Org-wide custom app setting' 'MANUAL' 'Teams admin center > Teams apps > Manage apps > Org-wide app settings: custom apps allowed.'
    }
    catch {
        Add-Result 'Teams' 'Upload custom apps' 'MANUAL' "MicrosoftTeams check failed ($($_.Exception.Message)). $teamsManual"
    }
}
else {
    Add-Result 'Teams' 'Upload custom apps' 'MANUAL' $teamsManual
}

# ---------------------------------------------------------------------------------------------
# 5: Manual checklist
# ---------------------------------------------------------------------------------------------
Add-Result 'M365 admin' 'Agents > Settings > User access' 'MANUAL' 'Microsoft 365 admin center > Agents > Settings > User access: All users, or a group that includes the learner and personas (ADM-01, ADM-02).'
Add-Result 'M365 admin' 'Agents > Settings > Sharing' 'MANUAL' "Allow the learner (for example $($names.Groups.CourseMakers)) to share Agent Builder agents (ADM-01, ADM-03)."
Add-Result 'M365 admin' 'Copilot Studio app deployed' 'MANUAL' 'Microsoft 365 admin center > Integrated apps: Copilot Studio app deployed to users (ADM-07).'
Add-Result 'Power Platform' 'Generative AI features' 'MANUAL' 'Power Platform admin center: generative AI features enabled for the course environments (ADM-07).'
Add-Result 'Power Platform' 'Copilot Studio authors group' 'MANUAL' "Power Platform admin center > Tenant settings > Copilot Studio authors: include $($names.Groups.CourseMakers) (ADM-08)."
Add-Result 'Billing' 'Pay-as-you-go (if used)' 'MANUAL' 'Billing plan linked to an Azure subscription (LIC-07). Needs Azure Owner or Contributor plus Global, Billing or AI Admin (LIC-08).'
Add-Result 'Power Platform' 'Environments' 'MANUAL' "Create $Prefix-Dev (developer), $Prefix-Test and $Prefix-Prod as described in PLAN.md section 3 (ENV-01, ENV-03)."
Add-Result 'Purview' 'Audit (Standard)' 'MANUAL' 'Microsoft Purview portal > Audit: confirm auditing is on (used in Lab 11, AUD-01).'
Add-Result 'M365 Apps' 'Update channel' 'MANUAL' 'Current Channel or Monthly Enterprise Channel for Office apps (PLAN.md section 3).'

Write-CourseSummary -Rows $results.ToArray() -Title 'Prerequisites summary'
if ($ReportPath) {
    $results | Export-Csv -LiteralPath $ReportPath -NoTypeInformation -Encoding utf8
    Write-Step "Report saved to $ReportPath" -Level Ok
}
