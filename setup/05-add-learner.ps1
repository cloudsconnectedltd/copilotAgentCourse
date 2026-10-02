<#
.SYNOPSIS
    Gives an additional learner the same course access as the setup owner, without running setup again.

.DESCRIPTION
    Run by the person who ran scripts 01 to 03 (the setup owner), once per additional learner.
    The additional learner runs no setup scripts. For each -LearnerUpn this script:

      - adds the learner to every course security group (<Prefix>-AllStaff, -HR, -Finance,
        -Ops-Ontario, -Ops-US, -CourseMakers), matching what 01 does for the setup owner
      - adds the learner to the Harbourline-Hub site Owners group (so they see all libraries,
        including HR-Policies/Restricted, as the setup owner does)
      - adds the learner as owner and member of the Harbourline-Operations Microsoft 365 group

    It does not assign licenses. Each learner needs their own Microsoft 365 Copilot license.
    Idempotent: re-running skips what is already in place.

.PARAMETER TenantUrl
    Root SharePoint URL, for example https://contoso.sharepoint.com.

.PARAMETER Prefix
    Course object prefix. Default HLE.

.PARAMETER LearnerUpn
    One or more user principal names of the additional learners.

.PARAMETER ClientId
    Application (client) ID of your Entra app registration for PnP.PowerShell. Defaults to $env:ENTRAID_APP_ID.

.PARAMETER Cleanup
    Removes the listed learners from the course groups, the Hub Owners group and the Operations
    group. Does not touch their accounts or licenses.

.EXAMPLE
    ./setup/05-add-learner.ps1 -TenantUrl https://contoso.sharepoint.com -LearnerUpn alex@contoso.com

.EXAMPLE
    ./setup/05-add-learner.ps1 -TenantUrl https://contoso.sharepoint.com -LearnerUpn alex@contoso.com -Cleanup

.NOTES
    Run after 01 and 02. Role: SharePoint Administrator plus Groups Administrator (or Global Administrator).
    Uses the same PnP app registration and Graph permissions as 02 (setup/README.md).
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$TenantUrl,
    [ValidatePattern('^[A-Za-z][A-Za-z0-9]{1,9}$')][string]$Prefix = 'HLE',
    [Parameter(Mandatory)][string[]]$LearnerUpn,
    [string]$ClientId = $env:ENTRAID_APP_ID,
    [switch]$Cleanup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'common.psm1') -Force -Verbose:$false

Write-Step "05 Add learner$(if ($Cleanup) { ' (CLEANUP)' })" -Level Header
if (-not $ClientId) { throw 'Pass -ClientId (your Entra app for PnP.PowerShell) or set $env:ENTRAID_APP_ID. See setup/README.md.' }
Assert-Module -Name 'PnP.PowerShell'

$names = Get-CourseNames -TenantUrl $TenantUrl -Prefix $Prefix
$admin = Connect-CoursePnP -Url $names.AdminUrl -ClientId $ClientId -Tenant $names.TenantDomain
Set-CourseGraphTransport -PnPConnection $admin

if (-not (Get-CourseTenantSite -Url $names.HubUrl -Connection $admin)) { throw "Hub site $($names.HubUrl) not found. Run 02-provision-sites.ps1 first." }
$hub = Connect-CoursePnP -Url $names.HubUrl -ClientId $ClientId -Tenant $names.TenantDomain
$hubOwners = Get-PnPGroup -AssociatedOwnerGroup -Connection $hub

$f = ConvertTo-CourseFilter ("mailNickname eq '{0}'" -f $names.OpsAlias)
$og = @(Invoke-CourseGraph -Uri ('v1.0/groups?$select=id,displayName&$filter=' + $f) -All) | Select-Object -First 1
if (-not $og) { throw "Microsoft 365 group $($names.OpsAlias) not found. Run 02-provision-sites.ps1 first." }
$ogId = Get-CourseProp $og 'id'

$courseGroups = @()
foreach ($gn in $names.Groups.PSObject.Properties.Value) {
    $g = Get-CourseEntraGroup -DisplayName $gn
    if ($g) { $courseGroups += [pscustomobject]@{ Name = $gn; Id = (Get-CourseProp $g 'id') } }
    else { Write-Step "Group $gn not found. Run 01-provision-users.ps1 first." -Level Warn }
}

function Get-MemberIds([string]$GroupId, [string]$Relation) {
    return @(Invoke-CourseGraph -Uri "v1.0/groups/$GroupId/$Relation`?`$select=id" -All | ForEach-Object { Get-CourseProp $_ 'id' })
}

foreach ($upn in $LearnerUpn) {
    $u = Get-CourseEntraUser -UserPrincipalName $upn
    if (-not $u) { Write-Step "User $upn not found in Entra ID. Skipped." -Level Warn; continue }
    $uid = Get-CourseProp $u 'id'
    $login = "i:0#.f|membership|$upn"
    Write-Step "Learner $upn" -Level Info

    # ---- Course security groups ---------------------------------------------------------------
    foreach ($g in $courseGroups) {
        $isMember = (Get-MemberIds $g.Id 'members') -contains $uid
        if ($Cleanup) {
            if (-not $isMember) { Write-Step "$upn not in $($g.Name)" -Level Skip; continue }
            $null = Invoke-CourseAction -Cmdlet $PSCmdlet -Target $g.Name -Action "Remove $upn" -ScriptBlock {
                Invoke-CourseGraph -Method DELETE -Uri "v1.0/groups/$($g.Id)/members/$uid/`$ref" | Out-Null
            }
        }
        elseif ($isMember) { Write-Step "$upn already in $($g.Name)" -Level Skip }
        else {
            $null = Invoke-CourseAction -Cmdlet $PSCmdlet -Target $g.Name -Action "Add $upn" -ScriptBlock {
                Invoke-CourseGraph -Method POST -Uri "v1.0/groups/$($g.Id)/members/`$ref" -Body @{ '@odata.id' = "https://graph.microsoft.com/v1.0/directoryObjects/$uid" } | Out-Null
            }
        }
    }

    # ---- Hub site Owners ----------------------------------------------------------------------
    $inOwners = @(Get-PnPGroupMember -Group $hubOwners -Connection $hub | ForEach-Object { [string]$_.LoginName }) -icontains $login
    if ($Cleanup) {
        if ($inOwners) {
            $null = Invoke-CourseAction -Cmdlet $PSCmdlet -Target $hubOwners.Title -Action "Remove $upn" -ScriptBlock {
                Remove-PnPGroupMember -Group $hubOwners -LoginName $login -Connection $hub
            }
        }
        else { Write-Step "$upn not in '$($hubOwners.Title)'" -Level Skip }
    }
    elseif ($inOwners) { Write-Step "$upn already in '$($hubOwners.Title)'" -Level Skip }
    else {
        $null = Invoke-CourseAction -Cmdlet $PSCmdlet -Target $hubOwners.Title -Action "Add $upn" -ScriptBlock {
            Add-PnPGroupMember -Group $hubOwners -LoginName $login -Connection $hub
        }
    }

    # ---- Operations Microsoft 365 group (owner and member) -----------------------------------
    foreach ($rel in @('owners', 'members')) {
        $has = (Get-MemberIds $ogId $rel) -contains $uid
        if ($Cleanup) {
            if (-not $has) { Write-Step "$upn not in $($names.OpsAlias) $rel" -Level Skip; continue }
            $null = Invoke-CourseAction -Cmdlet $PSCmdlet -Target "$($names.OpsAlias) $rel" -Action "Remove $upn" -ScriptBlock {
                Invoke-CourseGraph -Method DELETE -Uri "v1.0/groups/$ogId/$rel/$uid/`$ref" | Out-Null
            }
        }
        elseif ($has) { Write-Step "$upn already in $($names.OpsAlias) $rel" -Level Skip }
        else {
            $null = Invoke-CourseAction -Cmdlet $PSCmdlet -Target "$($names.OpsAlias) $rel" -Action "Add $upn" -ScriptBlock {
                Invoke-CourseGraph -Method POST -Uri "v1.0/groups/$ogId/$rel/`$ref" -Body @{ '@odata.id' = "https://graph.microsoft.com/v1.0/directoryObjects/$uid" } | Out-Null
            }
        }
    }
}

if ($Cleanup) { Write-Step '05 cleanup complete' -Level Ok; return }
Write-Step '05 complete. Share the persona passwords file with each learner through a secure channel; each learner needs their own Copilot license.' -Level Ok
Write-Step 'Group membership can take a few minutes to apply in SharePoint and Copilot.' -Level Info
