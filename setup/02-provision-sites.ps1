<#
.SYNOPSIS
    Creates the two Harbourline SharePoint sites, their libraries, the Vendors list and permissions.

.DESCRIPTION
    Idempotent. Implements reference/site-map.md:

    Harbourline-Hub (communication site, /sites/<Prefix>-Harbourline-Hub, owner: learner)
      Libraries   Getting-Started, HR-Policies (with Restricted folder), Finance
      List        Vendors (columns taken from data/sharepoint/Harbourline-Hub/Vendors.csv header)
      Members     <Prefix>-HR, <Prefix>-Finance      Visitors  <Prefix>-AllStaff
      HR-Policies/Restricted  unique permissions: site Owners (Full Control) and <Prefix>-HR (Edit) only
      Finance     unique permissions: <Prefix>-Finance Edit, site Members reduced to Read, Visitors Read

    Harbourline-Operations (team site with Microsoft 365 group, /sites/<Prefix>-Harbourline-Operations)
      Libraries   Procedures (with Incoming folder), Archive-Bulk
      Sharing     SharingCapability ExternalUserSharingOnly (guest access)
      Group       members: tech persona, nolic persona, guest (-GuestEmail); learner is owner

    Graph calls go through Invoke-PnPGraphMethod, so the PnP app registration needs the Graph
    delegated permissions listed in setup/README.md.

.PARAMETER TenantUrl
    Root SharePoint URL, for example https://contoso.sharepoint.com.

.PARAMETER Prefix
    Course object prefix. Default HLE.

.PARAMETER ClientId
    Application (client) ID of your Entra app registration for PnP.PowerShell. Defaults to $env:ENTRAID_APP_ID.

.PARAMETER Domain
    Persona UPN domain. Default: the tenant's default verified domain.

.PARAMETER GuestEmail
    Guest contractor address invited by 01-provision-users.ps1. Optional; without it the guest is not added.

.PARAMETER Cleanup
    Deletes the Hub site and the Operations Microsoft 365 group (which deletes its site). With
    -Force, or after you confirm the prompt, also purges both from the recycle bins.

.PARAMETER Force
    With -Cleanup: purge from recycle bins without prompting.

.EXAMPLE
    ./setup/02-provision-sites.ps1 -TenantUrl https://contoso.sharepoint.com -ClientId 11111111-2222-3333-4444-555555555555 -GuestEmail someone@outlook.com

.EXAMPLE
    ./setup/02-provision-sites.ps1 -TenantUrl https://contoso.sharepoint.com -Cleanup -Force

.NOTES
    Role: SharePoint Administrator (and Groups Administrator or Global Administrator for the M365 group).
    Site provisioning usually takes a few minutes; the script polls until each site is Active.
    Permission level names (Full Control, Edit, Read) assume an English-language site.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$TenantUrl,
    [ValidatePattern('^[A-Za-z][A-Za-z0-9]{1,9}$')][string]$Prefix = 'HLE',
    [string]$ClientId = $env:ENTRAID_APP_ID,
    [string]$Domain,
    [string]$GuestEmail,
    [switch]$Cleanup,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'common.psm1') -Verbose:$false

Write-Step "02 Provision SharePoint sites$(if ($Cleanup) { ' (CLEANUP)' })" -Level Header
if (-not $ClientId) { throw 'Pass -ClientId (your Entra app for PnP.PowerShell) or set $env:ENTRAID_APP_ID. See setup/README.md.' }
Assert-Module -Name 'PnP.PowerShell'

$names0 = Get-CourseNames -TenantUrl $TenantUrl -Prefix $Prefix
$admin = Connect-CoursePnP -Url $names0.AdminUrl -ClientId $ClientId -Tenant $names0.TenantDomain
Set-CourseGraphTransport -PnPConnection $admin
$Domain = Resolve-CourseDomain -Domain $Domain
$names = Get-CourseNames -TenantUrl $TenantUrl -Prefix $Prefix -Domain $Domain

function Get-OpsGroup {
    $f = ConvertTo-CourseFilter ("mailNickname eq '{0}'" -f $names.OpsAlias)
    $r = @(Invoke-CourseGraph -Uri ('v1.0/groups?$select=id,displayName,mailNickname&$filter=' + $f) -All)
    if ($r.Count -eq 0) { return $null }
    return $r[0]
}

# =============================================================================================
# CLEANUP
# =============================================================================================
if ($Cleanup) {
    $purge = $Force
    if (-not $purge -and -not $WhatIfPreference) {
        $purge = $PSCmdlet.ShouldContinue('Also permanently delete both sites and the Operations group from the recycle bins? This cannot be undone.', 'Purge deleted sites')
    }

    # Hub (communication site, no group)
    $hub = Get-CourseTenantSite -Url $names.HubUrl -Connection $admin
    if ($hub) {
        $null = Invoke-CourseAction -Cmdlet $PSCmdlet -Target $names.HubUrl -Action 'Delete site (to recycle bin)' -ScriptBlock {
            Remove-PnPTenantSite -Url $names.HubUrl -Force -Connection $admin
        }
    }
    else { Write-Step "Hub site not found" -Level Skip }
    if ($purge) {
        $null = Invoke-CourseAction -Cmdlet $PSCmdlet -Target $names.HubUrl -Action 'Purge site from recycle bin' -ScriptBlock {
            try { Remove-PnPTenantDeletedSite -Identity $names.HubUrl -Force -Connection $admin }
            catch { Write-Step "Hub not in deleted sites yet ($($_.Exception.Message)). Re-run cleanup later to purge." -Level Warn }
        }
    }

    # Operations (group-connected): delete the Microsoft 365 group; SharePoint deletes the site.
    $og = Get-OpsGroup
    if ($og) {
        $ogId = Get-CourseProp $og 'id'
        $null = Invoke-CourseAction -Cmdlet $PSCmdlet -Target $names.OpsAlias -Action 'Delete Microsoft 365 group (and its site)' -ScriptBlock {
            Invoke-CourseGraph -Method DELETE -Uri "v1.0/groups/$ogId" | Out-Null
        }
        if ($purge) {
            $null = Invoke-CourseAction -Cmdlet $PSCmdlet -Target $names.OpsAlias -Action 'Purge group from Entra deleted items' -ScriptBlock {
                $ok = Wait-CourseCondition -Description 'deleted group to appear' -TimeoutSeconds 120 -IntervalSeconds 10 -Condition {
                    Invoke-CourseGraph -Method DELETE -Uri "v1.0/directory/deletedItems/$ogId" | Out-Null; $true
                }
                if (-not $ok) { Write-Step 'Could not purge the group yet. Purge it in Entra admin center > Groups > Deleted groups.' -Level Warn }
            }
        }
    }
    else { Write-Step 'Operations group not found' -Level Skip }
    if ($purge) {
        $null = Invoke-CourseAction -Cmdlet $PSCmdlet -Target $names.OpsUrl -Action 'Purge Operations site from recycle bin' -ScriptBlock {
            $ok = Wait-CourseCondition -Description 'Operations site to reach deleted sites' -TimeoutSeconds 600 -IntervalSeconds 30 -Condition {
                Remove-PnPTenantDeletedSite -Identity $names.OpsUrl -Force -Connection $admin; $true
            }
            if (-not $ok) { Write-Step 'Operations site not purged yet (group deletion is asynchronous). Re-run cleanup later, or purge it in SharePoint admin center > Deleted sites.' -Level Warn }
        }
    }
    Write-Step '02 cleanup complete' -Level Ok
    return
}

# =============================================================================================
# PROVISION
# =============================================================================================
$me = Invoke-CourseGraph -Uri 'v1.0/me?$select=id,userPrincipalName'
Write-Step "Learner (site owner) is $(Get-CourseProp $me 'userPrincipalName')" -Level Info

# ---- Tenant sharing check --------------------------------------------------------------------
$tenant = Get-PnPTenant -Connection $admin
$tenantSharing = [string](Get-CourseProp $tenant 'SharingCapability')
if ($tenantSharing -notin @('ExternalUserSharingOnly', 'ExternalUserAndGuestSharing')) {
    Write-Step "Tenant SharingCapability is $tenantSharing. A site cannot be more permissive than the tenant, so guest sharing on Operations will not apply until the tenant allows it." -Level Warn
}

# ---- Sites -----------------------------------------------------------------------------------
function Wait-SiteActive([string]$Url) {
    $ok = Wait-CourseCondition -Description "site $Url to be Active" -TimeoutSeconds 1200 -IntervalSeconds 20 -Condition {
        $s = Get-CourseTenantSite -Url $Url -Connection $admin
        ($s -and ([string](Get-CourseProp $s 'Status')) -eq 'Active')
    }
    if (-not $ok) { throw "Site $Url did not become Active in time. Re-run this script later." }
}

$hubSite = Get-CourseTenantSite -Url $names.HubUrl -Connection $admin
if ($hubSite) { Write-Step "Hub site exists: $($names.HubUrl)" -Level Skip }
else {
    $null = Invoke-CourseAction -Cmdlet $PSCmdlet -Target $names.HubUrl -Action 'Create communication site' -ScriptBlock {
        New-PnPSite -Type CommunicationSite -Title $names.HubTitle -Url $names.HubUrl `
            -Description 'Harbourline Energy Co. intranet hub: onboarding, HR policies, finance, vendors (course data).' -Connection $admin
    }
    if (-not $WhatIfPreference) { Wait-SiteActive $names.HubUrl }
}

$opsSite = Get-CourseTenantSite -Url $names.OpsUrl -Connection $admin
if ($opsSite) { Write-Step "Operations site exists: $($names.OpsUrl)" -Level Skip }
else {
    $created = Invoke-CourseAction -Cmdlet $PSCmdlet -Target $names.OpsUrl -Action 'Create team site with Microsoft 365 group' -ScriptBlock {
        New-PnPSite -Type TeamSite -Title $names.OpsTitle -Alias $names.OpsAlias `
            -Description 'Harbourline Energy Co. field operations: procedures and archive (course data).' -Connection $admin
    }
    if ($created -and ([string]$created).TrimEnd('/') -ne $names.OpsUrl) {
        Write-Step "Team site was created at $created, not $($names.OpsUrl). The alias may have been taken. Fix and re-run." -Level Warn
    }
    if (-not $WhatIfPreference) { Wait-SiteActive $names.OpsUrl }
}

if ($WhatIfPreference -and (-not $hubSite -or -not $opsSite)) {
    Write-Step 'WhatIf: sites do not exist yet, so library and permission steps cannot be previewed.' -Level Skip
    return
}

# ---- Guest sharing on Operations -------------------------------------------------------------
$opsSite = Get-CourseTenantSite -Url $names.OpsUrl -Connection $admin
if ([string](Get-CourseProp $opsSite 'SharingCapability') -ne 'ExternalUserSharingOnly') {
    $null = Invoke-CourseAction -Cmdlet $PSCmdlet -Target $names.OpsUrl -Action 'Set SharingCapability ExternalUserSharingOnly' -ScriptBlock {
        Set-PnPTenantSite -Identity $names.OpsUrl -SharingCapability ExternalUserSharingOnly -Connection $admin
    }
}
else { Write-Step 'Operations sharing already ExternalUserSharingOnly' -Level Skip }

# ---- Common SharePoint helpers ---------------------------------------------------------------
function Confirm-Library($Conn, [string]$Title) {
    $l = $null
    try { $l = Get-PnPList -Identity $Title -Connection $Conn -ErrorAction Stop } catch { $l = $null }
    if ($l) { Write-Step "Library $Title exists" -Level Skip; return }
    $null = Invoke-CourseAction -Cmdlet $PSCmdlet -Target $Title -Action 'Create document library' -ScriptBlock {
        New-PnPList -Title $Title -Url $Title -Template DocumentLibrary -OnQuickLaunch -Connection $Conn
    }
}
function Add-SiteGroupMember($Conn, $SpGroup, [string]$LoginName, [string]$Label) {
    $existing = @(Get-PnPGroupMember -Group $SpGroup -Connection $Conn | ForEach-Object { [string]$_.LoginName })
    if ($existing -icontains $LoginName) { Write-Step "$Label already in '$($SpGroup.Title)'" -Level Skip; return }
    $null = Invoke-CourseAction -Cmdlet $PSCmdlet -Target $SpGroup.Title -Action "Add $Label" -ScriptBlock {
        Add-PnPGroupMember -Group $SpGroup -LoginName $LoginName -Connection $Conn
    }
}
function Get-GroupClaim([string]$Name) {
    $g = Get-CourseEntraGroup -DisplayName $Name
    if (-not $g) { throw "Entra group $Name not found. Run 01-provision-users.ps1 first." }
    return (Get-CourseGroupClaim -GroupId (Get-CourseProp $g 'id'))
}

# ---- Hub content structures ------------------------------------------------------------------
$hub = Connect-CoursePnP -Url $names.HubUrl -ClientId $ClientId -Tenant $names.TenantDomain
foreach ($lib in $names.HubLibraries) { Confirm-Library $hub $lib }
Confirm-CourseFolder -SiteRelativePath $names.RestrictedPath -Connection $hub -WhatIf:$WhatIfPreference -Confirm:$false

# Vendors list: columns follow the CSV header when the file exists.
$vendorsCsv = Join-Path (Get-CourseRepoRoot) 'data/sharepoint/Harbourline-Hub/Vendors.csv'
$defaultHeader = @('Title', 'VendorId', 'Category', 'Region', 'ContractValue', 'Currency', 'Status', 'RenewalDate', 'PrimaryContact', 'ContactEmail', 'RiskRating')
$typeMap = @{ ContractValue = 'Number'; RenewalDate = 'Date'; Category = 'Choice'; Region = 'Choice'; Status = 'Choice'; RiskRating = 'Choice' }
$defaultChoices = @{
    Category   = @('Engineering Consulting', 'Facilities', 'Fleet', 'IT Services', 'Line Construction', 'Metering', 'Professional Services', 'Safety Equipment', 'Transformers', 'Vegetation Management')
    Region     = @('Ontario', 'New York', 'Ohio')
    Status     = @('Active', 'Pending Review', 'Expired', 'Suspended')
    RiskRating = @('Low', 'Medium', 'High')
}
$rows = @()
if (Test-Path -LiteralPath $vendorsCsv) {
    $rows = @(Import-Csv -LiteralPath $vendorsCsv)
    $header = @((Get-Content -LiteralPath $vendorsCsv -TotalCount 1).Split(',') | ForEach-Object { $_.Trim().Trim('"') })
    Write-Step "Vendors.csv found: $($rows.Count) rows, columns $($header -join ', ')" -Level Info
}
else {
    $header = $defaultHeader
    Write-Step 'Vendors.csv not found; using the default column set from reference/site-map.md' -Level Warn
}

$vl = $null
try { $vl = Get-PnPList -Identity $names.VendorsList -Connection $hub -ErrorAction Stop } catch { $vl = $null }
if (-not $vl) {
    $null = Invoke-CourseAction -Cmdlet $PSCmdlet -Target $names.VendorsList -Action 'Create custom list' -ScriptBlock {
        New-PnPList -Title $names.VendorsList -Url "Lists/$($names.VendorsList)" -Template GenericList -OnQuickLaunch -Connection $hub
    }
}
else { Write-Step 'Vendors list exists' -Level Skip }

$viewFields = @('LinkTitle')
foreach ($col in $header) {
    if ($col -eq 'Title' -or -not $col) { continue }
    $internal = ($col -replace '[^A-Za-z0-9]', '')
    $viewFields += $internal
    $existingField = $null
    try { $existingField = Get-PnPField -List $names.VendorsList -Identity $internal -Connection $hub -ErrorAction Stop } catch { $existingField = $null }
    if ($existingField) { Write-Step "Column $col exists" -Level Skip; continue }
    $type = if ($typeMap.ContainsKey($col)) { $typeMap[$col] } else { 'Text' }
    $dn = [System.Security.SecurityElement]::Escape($col)
    switch ($type) {
        'Number' { $xml = "<Field Type=`"Number`" DisplayName=`"$dn`" Name=`"$internal`" StaticName=`"$internal`" Decimals=`"2`" />" }
        'Date'   { $xml = "<Field Type=`"DateTime`" DisplayName=`"$dn`" Name=`"$internal`" StaticName=`"$internal`" Format=`"DateOnly`" />" }
        'Choice' {
            $choices = if ($rows.Count -gt 0) { @($rows | ForEach-Object { $_.$col } | Where-Object { $_ } | Sort-Object -Unique) } else { $defaultChoices[$col] }
            $cx = ($choices | ForEach-Object { "<CHOICE>$([System.Security.SecurityElement]::Escape($_))</CHOICE>" }) -join ''
            $xml = "<Field Type=`"Choice`" DisplayName=`"$dn`" Name=`"$internal`" StaticName=`"$internal`" Format=`"Dropdown`" FillInChoice=`"TRUE`"><CHOICES>$cx</CHOICES></Field>"
        }
        default {
            $idx = if ($col -eq 'VendorId') { ' Indexed="TRUE"' } else { '' }
            $xml = "<Field Type=`"Text`" DisplayName=`"$dn`" Name=`"$internal`" StaticName=`"$internal`" MaxLength=`"255`"$idx />"
        }
    }
    $null = Invoke-CourseAction -Cmdlet $PSCmdlet -Target "Vendors.$col" -Action "Add $type column" -ScriptBlock {
        Add-PnPFieldFromXml -List $names.VendorsList -FieldXml $xml -Connection $hub
    }
}
try {
    $defView = Get-PnPView -List $names.VendorsList -Connection $hub | Where-Object { $_.DefaultView } | Select-Object -First 1
    if ($defView) {
        $null = Invoke-CourseAction -Cmdlet $PSCmdlet -Target "Vendors view $($defView.Title)" -Action 'Set view columns' -ScriptBlock {
            Set-PnPView -List $names.VendorsList -Identity $defView.Id -Fields $viewFields -Connection $hub
        }
    }
}
catch { Write-Step "Could not update the Vendors default view: $($_.Exception.Message)" -Level Warn }

# ---- Hub permissions -------------------------------------------------------------------------
$ownersGrp = Get-PnPGroup -AssociatedOwnerGroup -Connection $hub
$membersGrp = Get-PnPGroup -AssociatedMemberGroup -Connection $hub
$visitorsGrp = Get-PnPGroup -AssociatedVisitorGroup -Connection $hub
$hrClaim = Get-GroupClaim $names.Groups.HR
$finClaim = Get-GroupClaim $names.Groups.Finance
$allClaim = Get-GroupClaim $names.Groups.AllStaff

Add-SiteGroupMember $hub $membersGrp $hrClaim $names.Groups.HR
Add-SiteGroupMember $hub $membersGrp $finClaim $names.Groups.Finance
Add-SiteGroupMember $hub $visitorsGrp $allClaim $names.Groups.AllStaff

# HR-Policies/Restricted: break inheritance without copying, then grant Owners + HR only.
$caml = "<View><Query><Where><And><Eq><FieldRef Name='FileLeafRef'/><Value Type='File'>Restricted</Value></Eq><Eq><FieldRef Name='FSObjType'/><Value Type='Integer'>1</Value></Eq></And></Where></Query></View>"
$restrictedItem = @(Get-PnPListItem -List 'HR-Policies' -Query $caml -Connection $hub) | Select-Object -First 1
if (-not $restrictedItem) { throw 'HR-Policies/Restricted folder not found after creation.' }
$null = Invoke-CourseAction -Cmdlet $PSCmdlet -Target $names.RestrictedPath -Action 'Reset unique permissions: Owners Full Control, HR Edit (Members and Visitors removed)' -ScriptBlock {
    Set-PnPListItemPermission -List 'HR-Policies' -Identity $restrictedItem.Id -Group $ownersGrp.Title -AddRole 'Full Control' -ClearExisting -Connection $hub
    Set-PnPListItemPermission -List 'HR-Policies' -Identity $restrictedItem.Id -User $hrClaim -AddRole 'Edit' -Connection $hub
}

# Finance library: Finance group Edit; everyone else Read.
$finList = Get-PnPList -Identity 'Finance' -Includes HasUniqueRoleAssignments -Connection $hub
if (-not $finList.HasUniqueRoleAssignments) {
    $null = Invoke-CourseAction -Cmdlet $PSCmdlet -Target 'Finance' -Action 'Break permission inheritance (copy existing)' -ScriptBlock {
        Set-PnPList -Identity 'Finance' -BreakRoleInheritance -CopyRoleAssignments -Connection $hub
    }
}
$null = Invoke-CourseAction -Cmdlet $PSCmdlet -Target 'Finance' -Action "Grant $($names.Groups.Finance) Edit; site Members Read" -ScriptBlock {
    Set-PnPListPermission -Identity 'Finance' -User $finClaim -AddRole 'Edit' -Connection $hub
    Set-PnPListPermission -Identity 'Finance' -Group $membersGrp.Title -AddRole 'Read' -Connection $hub
    try { Set-PnPListPermission -Identity 'Finance' -Group $membersGrp.Title -RemoveRole 'Edit' -Connection $hub }
    catch { Write-Step 'Members group had no Edit role on Finance (already reduced)' -Level Skip }
}

# ---- Operations content structures -----------------------------------------------------------
$ops = Connect-CoursePnP -Url $names.OpsUrl -ClientId $ClientId -Tenant $names.TenantDomain
foreach ($lib in $names.OpsLibraries) { Confirm-Library $ops $lib }
Confirm-CourseFolder -SiteRelativePath $names.IncomingPath -Connection $ops -WhatIf:$WhatIfPreference -Confirm:$false

# ---- Operations Microsoft 365 group membership -----------------------------------------------
$og = Get-OpsGroup
if (-not $og) { throw "Microsoft 365 group $($names.OpsAlias) not found." }
$ogId = Get-CourseProp $og 'id'
$currentMembers = @(Invoke-CourseGraph -Uri "v1.0/groups/$ogId/members?`$select=id" -All | ForEach-Object { Get-CourseProp $_ 'id' })
$toAdd = @()
foreach ($k in @('tech', 'nolic')) {
    $upn = $names.Personas.$k.Upn
    $u = Get-CourseEntraUser -UserPrincipalName $upn
    if ($u) { $toAdd += [pscustomobject]@{ Id = (Get-CourseProp $u 'id'); Label = $upn } }
    else { Write-Step "User $upn not found. Run 01-provision-users.ps1 first." -Level Warn }
}
if ($GuestEmail) {
    $gu = Get-CourseEntraUser -Mail $GuestEmail
    if ($gu) { $toAdd += [pscustomobject]@{ Id = (Get-CourseProp $gu 'id'); Label = "guest $GuestEmail" } }
    else { Write-Step "Guest $GuestEmail not found. Run 01-provision-users.ps1 -GuestEmail first." -Level Warn }
}
else { Write-Step 'No -GuestEmail: guest not added to the Operations group.' -Level Warn }
foreach ($m in $toAdd) {
    if ($currentMembers -contains $m.Id) { Write-Step "$($m.Label) already in $($names.OpsAlias)" -Level Skip; continue }
    $null = Invoke-CourseAction -Cmdlet $PSCmdlet -Target $names.OpsAlias -Action "Add member $($m.Label)" -ScriptBlock {
        Invoke-CourseGraph -Method POST -Uri "v1.0/groups/$ogId/members/`$ref" -Body @{ '@odata.id' = "https://graph.microsoft.com/v1.0/directoryObjects/$($m.Id)" } | Out-Null
    }
}

Write-Step '02 provisioning complete. Next: 03-upload-content.ps1' -Level Ok
