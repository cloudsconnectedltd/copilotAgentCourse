<#
.SYNOPSIS
    Creates the "<Prefix> HR Confidential" encrypting sensitivity label, publishes it, and applies it to
    HR-Policies/Compensation-Bands-2025.docx for the Lab 3 encryption caveat (CS-K08).

.DESCRIPTION
    Idempotent. Steps:
      1. Checks that sensitivity labels are enabled for Office files in SharePoint and OneDrive
         (Get-PnPTenant EnableAIPIntegration). If not, WARN and print the manual path; the label is
         still created but not applied.
      2. Connect-IPPSSession (ExchangeOnlineManagement). Creates label <Prefix>-HR-Confidential
         (display name "<Prefix> HR Confidential") with encryption that grants co-author rights
         (including VIEW and EXTRACT) to <Prefix>-HR. If the group has no email address (security
         groups created by 01 are not mail-enabled), rights are granted to each current member by UPN
         instead. Nobody else gets rights; the Rights Management owner (the person who applies the
         label) keeps full control.
      3. Publishes label policy <Prefix>-HR-Label-Policy to the learner and the HR persona.
         Policy and label changes can take time to reach apps and SharePoint; check Microsoft Learn
         for current propagation guidance before assuming the label is missing.
      4. Applies the label to Compensation-Bands-2025.docx with Microsoft Graph
         POST /drives/{drive-id}/items/{item-id}/assignSensitivityLabel. This is a metered
         (protected) Graph API: the calling app must be set up for metered billing. If the call fails
         for any reason, manual steps for the SharePoint UI are printed.

.PARAMETER TenantUrl
    Root SharePoint URL, for example https://contoso.sharepoint.com.

.PARAMETER Prefix
    Course object prefix. Default HLE.

.PARAMETER ClientId
    Application (client) ID of your Entra app registration for PnP.PowerShell. Defaults to $env:ENTRAID_APP_ID.

.PARAMETER Domain
    Persona UPN domain. Default: the tenant's default verified domain.

.PARAMETER UserPrincipalName
    Optional UPN passed to Connect-IPPSSession.

.PARAMETER FileName
    File in HR-Policies to label. Default Compensation-Bands-2025.docx.

.PARAMETER SkipAssign
    Create and publish the label but do not apply it to the file.

.PARAMETER Cleanup
    Prints how to remove the label from the file (03 -Cleanup deletes the file itself), then
    removes the label policy and the label.

.EXAMPLE
    ./setup/04-apply-labels.ps1 -TenantUrl https://contoso.sharepoint.com -ClientId 11111111-2222-3333-4444-555555555555

.EXAMPLE
    ./setup/04-apply-labels.ps1 -TenantUrl https://contoso.sharepoint.com -SkipAssign

.EXAMPLE
    ./setup/04-apply-labels.ps1 -TenantUrl https://contoso.sharepoint.com -Cleanup

.NOTES
    Roles: Compliance Administrator (or Information Protection Administrator) for labels,
    SharePoint Administrator for the tenant check. The PnP app needs Graph Files.ReadWrite.All
    and Sites.Read.All (delegated) for the assign step.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$TenantUrl,
    [ValidatePattern('^[A-Za-z][A-Za-z0-9]{1,9}$')][string]$Prefix = 'HLE',
    [string]$ClientId = $env:ENTRAID_APP_ID,
    [string]$Domain,
    [string]$UserPrincipalName,
    [string]$FileName = 'Compensation-Bands-2025.docx',
    [switch]$SkipAssign,
    [switch]$Cleanup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'common.psm1') -Force -Verbose:$false

Write-Step "04 Sensitivity label$(if ($Cleanup) { ' (CLEANUP)' })" -Level Header
if (-not $ClientId) { throw 'Pass -ClientId (your Entra app for PnP.PowerShell) or set $env:ENTRAID_APP_ID. See setup/README.md.' }
Assert-Module -Name 'PnP.PowerShell', 'ExchangeOnlineManagement'

$names0 = Get-CourseNames -TenantUrl $TenantUrl -Prefix $Prefix
$admin = Connect-CoursePnP -Url $names0.AdminUrl -ClientId $ClientId -Tenant $names0.TenantDomain
Set-CourseGraphTransport -PnPConnection $admin
$Domain = Resolve-CourseDomain -Domain $Domain
$names = Get-CourseNames -TenantUrl $TenantUrl -Prefix $Prefix -Domain $Domain

$manualApply = @"
Manual steps to apply the label in SharePoint:
  1. Sign in as the learner (the label policy includes you) and open $($names.HubUrl)/HR-Policies.
  2. Select $FileName, open the details pane (the i icon), and set Sensitivity to "$($names.LabelDisplayName)".
     Alternatively open the file in Word for the web and choose Sensitivity > $($names.LabelDisplayName).
  3. Confirm the Sensitivity column shows the label. If the label is not listed yet, the policy has
     not reached you; wait and retry (check Microsoft Learn for current propagation guidance).
"@

function Connect-Compliance {
    Write-Step 'Connecting Security and Compliance PowerShell (Connect-IPPSSession)' -Level Action
    $p = @{ ShowBanner = $false }
    if ($UserPrincipalName) { $p['UserPrincipalName'] = $UserPrincipalName }
    Connect-IPPSSession @p
}
function Get-LabelOrNull([string]$Id) { try { return Get-Label -Identity $Id -ErrorAction Stop } catch { return $null } }
function Get-PolicyOrNull([string]$Id) { try { return Get-LabelPolicy -Identity $Id -ErrorAction Stop } catch { return $null } }

# =============================================================================================
# CLEANUP
# =============================================================================================
if ($Cleanup) {
    Write-Step "Label on $FileName : there is no Graph v1.0 call used here to remove it. 03-upload-content.ps1 -Cleanup deletes the file (teardown runs it next). To keep the file but drop the label, open it in SharePoint and clear Sensitivity." -Level Info
    Connect-Compliance
    $pol = Get-PolicyOrNull $names.LabelPolicyName
    if ($pol) {
        $null = Invoke-CourseAction -Cmdlet $PSCmdlet -Target $names.LabelPolicyName -Action 'Remove label policy' -ScriptBlock {
            Remove-LabelPolicy -Identity $names.LabelPolicyName -Confirm:$false
        }
    }
    else { Write-Step 'Label policy not found' -Level Skip }
    $lbl = Get-LabelOrNull $names.LabelName
    if ($lbl) {
        $null = Invoke-CourseAction -Cmdlet $PSCmdlet -Target $names.LabelName -Action 'Remove label' -ScriptBlock {
            try { Remove-Label -Identity $names.LabelName -Confirm:$false }
            catch { Write-Step "Remove-Label failed ($($_.Exception.Message)). Policy removal may still be propagating; re-run -Cleanup later." -Level Warn }
        }
    }
    else { Write-Step 'Label not found' -Level Skip }
    Write-Step '04 cleanup complete' -Level Ok
    return
}

# =============================================================================================
# 1. Tenant support
# =============================================================================================
$tenant = Get-PnPTenant -Connection $admin
$aip = Get-CourseProp $tenant 'EnableAIPIntegration'
$canAssign = -not $SkipAssign
if ($aip -ne $true) {
    Write-Step 'Sensitivity labels for Office files in SharePoint and OneDrive appear to be OFF (EnableAIPIntegration is not true).' -Level Warn
    Write-Step 'Turn it on in the Microsoft Purview portal (Information Protection settings) or with Set-SPOTenant -EnableAIPIntegration $true, then re-run. Check Microsoft Learn for the current path. The label will be created but not applied.' -Level Warn
    $canAssign = $false
}
else { Write-Step 'Sensitivity labels are enabled for SharePoint files' -Level Ok }

# =============================================================================================
# 2. Rights holders and label
# =============================================================================================
$hrGroup = Get-CourseEntraGroup -DisplayName $names.Groups.HR
if (-not $hrGroup) { throw "Group $($names.Groups.HR) not found. Run 01-provision-users.ps1 first." }
$coAuthor = 'VIEW,VIEWRIGHTSDATA,DOCEDIT,EDIT,PRINT,EXTRACT,REPLY,REPLYALL,FORWARD,OBJMODEL'
$hrMail = [string](Get-CourseProp $hrGroup 'mail')
if ($hrMail) {
    $identities = @($hrMail)
}
else {
    $hrId = Get-CourseProp $hrGroup 'id'
    $members = @(Invoke-CourseGraph -Uri "v1.0/groups/$hrId/members?`$select=userPrincipalName,mail" -All)
    $identities = @($members | ForEach-Object { [string](Get-CourseProp $_ 'userPrincipalName') } | Where-Object { $_ })
    Write-Step "$($names.Groups.HR) has no email address, so encryption rights are granted to its current members: $($identities -join ', '). Re-run 04 if HR membership changes, or use a mail-enabled security group." -Level Warn
}
if ($identities.Count -eq 0) { throw "No rights holders resolved for $($names.Groups.HR)." }
$rights = ($identities | ForEach-Object { "$($_):$coAuthor" }) -join ';'

Connect-Compliance
$label = Get-LabelOrNull $names.LabelName
if (-not $label) {
    $label = Invoke-CourseAction -Cmdlet $PSCmdlet -Target $names.LabelName -Action 'Create encrypting sensitivity label' -ScriptBlock {
        New-Label -Name $names.LabelName -DisplayName $names.LabelDisplayName `
            -Tooltip 'Harbourline HR confidential. Only HR can open. Course data.' `
            -Comment "[$($names.Tag)] Lab 3 encryption caveat (CS-K08)." `
            -EncryptionEnabled $true -EncryptionProtectionType 'Template' `
            -EncryptionRightsDefinitions $rights `
            -EncryptionContentExpiredOnDateInDaysOrNever 'Never' `
            -EncryptionOfflineAccessDays 7
    }
}
else {
    Write-Step "Label $($names.LabelName) exists; refreshing rights definitions" -Level Skip
    $null = Invoke-CourseAction -Cmdlet $PSCmdlet -Target $names.LabelName -Action 'Update encryption rights' -ScriptBlock {
        Set-Label -Identity $names.LabelName -EncryptionRightsDefinitions $rights
    }
}

# =============================================================================================
# 3. Label policy
# =============================================================================================
$learnerUpn = [string](Get-CourseProp (Invoke-CourseGraph -Uri 'v1.0/me?$select=userPrincipalName') 'userPrincipalName')
$scope = @($learnerUpn, $names.Personas.hr.Upn)
$policy = Get-PolicyOrNull $names.LabelPolicyName
if (-not $policy) {
    $null = Invoke-CourseAction -Cmdlet $PSCmdlet -Target $names.LabelPolicyName -Action "Publish label to $($scope -join ', ')" -ScriptBlock {
        New-LabelPolicy -Name $names.LabelPolicyName -Labels $names.LabelName -ExchangeLocation $scope `
            -Comment "[$($names.Tag)] Publishes $($names.LabelDisplayName) to the learner and HR persona."
    }
}
else {
    $current = @()
    try { $current = @($policy.ExchangeLocation | ForEach-Object { [string]$_.Name }) } catch { $current = @() }
    $missing = @($scope | Where-Object { $current -notcontains $_ })
    if ($missing.Count -gt 0) {
        $null = Invoke-CourseAction -Cmdlet $PSCmdlet -Target $names.LabelPolicyName -Action "Add users $($missing -join ', ')" -ScriptBlock {
            Set-LabelPolicy -Identity $names.LabelPolicyName -AddExchangeLocation $missing
        }
    }
    else { Write-Step 'Label policy exists with the expected users' -Level Skip }
}
Write-Step 'Label and policy changes can take time to reach SharePoint and Office apps; check Microsoft Learn for current guidance. Re-run this script later if the assign step fails.' -Level Info

# =============================================================================================
# 4. Apply to the file (metered Graph API)
# =============================================================================================
if (-not $canAssign) {
    Write-Host $manualApply
    Write-Step '04 finished without applying the label (see warnings above)' -Level Warn
    return
}
if ($WhatIfPreference -and -not $label) {
    Write-Step 'WhatIf: label not created, so the assign step cannot be previewed.' -Level Skip
    return
}

$labelId = [string](Get-CourseProp $label 'ImmutableId')
if (-not $labelId) { $labelId = [string](Get-CourseProp $label 'Guid') }
try {
    $hubHost = ([uri]$names.RootUrl).Host
    $site = Invoke-CourseGraph -Uri "v1.0/sites/$($hubHost):/sites/$($names.HubAlias)?`$select=id"
    $siteId = Get-CourseProp $site 'id'
    $drives = @(Invoke-CourseGraph -Uri "v1.0/sites/$siteId/drives?`$select=id,name" -All)
    $drive = @($drives | Where-Object { (Get-CourseProp $_ 'name') -eq 'HR-Policies' }) | Select-Object -First 1
    if (-not $drive) { throw 'HR-Policies drive not found. Run 02 and 03 first.' }
    $driveId = Get-CourseProp $drive 'id'
    $item = Invoke-CourseGraph -Uri "v1.0/drives/$driveId/root:/$([uri]::EscapeDataString($FileName))?`$select=id,name"
    $itemId = Get-CourseProp $item 'id'

    $already = $false
    try {
        $ext = Invoke-CourseGraph -Method POST -Uri "v1.0/drives/$driveId/items/$itemId/extractSensitivityLabels"
        $already = @(Get-CourseProp $ext 'labels' | Where-Object { (Get-CourseProp $_ 'sensitivityLabelId') -eq $labelId }).Count -gt 0
    }
    catch { Write-Step "Could not read current label ($($_.Exception.Message)); will try to assign." -Level Info }

    if ($already) { Write-Step "$FileName already has $($names.LabelDisplayName)" -Level Skip }
    else {
        $null = Invoke-CourseAction -Cmdlet $PSCmdlet -Target $FileName -Action "Assign label $($names.LabelDisplayName) (metered Graph API)" -ScriptBlock {
            Invoke-CourseGraph -Method POST -Uri "v1.0/drives/$driveId/items/$itemId/assignSensitivityLabel" -Body @{
                sensitivityLabelId = $labelId
                assignmentMethod   = 'standard'
                justificationText  = "Course setup ($($names.Tag))"
            } | Out-Null
            Write-Step 'Assignment accepted. It runs asynchronously; check the Sensitivity column in a few minutes.' -Level Ok
        }
    }
}
catch {
    if ($_.Exception.Message -match 'PaymentRequired|Payment Required') {
        Write-Step 'Automatic assignment skipped: assignSensitivityLabel is a metered (paid) Graph API and your app has no billing set up. This is expected for most course tenants. The label and policy are in place; apply the label by hand with the steps below.' -Level Warn
    }
    else {
        Write-Step "Automatic assignment failed: $($_.Exception.Message)" -Level Warn
        Write-Step 'Common causes: the metered API is not set up for your app, the label has not propagated yet, or labels are not enabled for SharePoint files.' -Level Warn
    }
    Write-Host $manualApply
}

Write-Step '04 complete' -Level Ok
