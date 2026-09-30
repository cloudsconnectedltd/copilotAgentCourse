<#
.SYNOPSIS
    Creates the course security groups, persona users and guest, and assigns licenses.

.DESCRIPTION
    Idempotent. Creates (only if missing):
      Security groups: <Prefix>-AllStaff, <Prefix>-HR, <Prefix>-Finance, <Prefix>-Ops-Ontario,
                       <Prefix>-Ops-US, <Prefix>-CourseMakers
      Users (reference/site-map.md persona table):
        Priya Nandakumar  <prefix>-hr@<domain>     Copilot   <Prefix>-HR, <Prefix>-AllStaff
        Marcus Delaney    <prefix>-tech@<domain>   Copilot   <Prefix>-Ops-Ontario, <Prefix>-AllStaff
        Sofia Brennan     <prefix>-fin@<domain>    Copilot   <Prefix>-Finance, <Prefix>-AllStaff
        Tom Whitfield     <prefix>-nolic@<domain>  no Copilot <Prefix>-Ops-US, <Prefix>-AllStaff
      Learner (signed-in account): added to every course group, Copilot license added if missing.
      Guest contractor: invited with New-MgInvitation when -GuestEmail is given. It joins the
      Operations Microsoft 365 group in 02-provision-sites.ps1.

    Every object created is tagged so -Cleanup only removes what this script created:
      users:  onPremisesExtensionAttributes.extensionAttribute15 = "<Prefix>-CourseSetup"
      groups: description starts with "[<Prefix>-CourseSetup]"

    Initial passwords of newly created users are written once to -PasswordFile (readable only by
    you). They are never printed. Users must change the password at first sign-in.

.PARAMETER TenantUrl
    Root SharePoint URL, for example https://contoso.sharepoint.com. Used to derive the tenant.

.PARAMETER Prefix
    Course object prefix. Default HLE. Persona UPNs use it in lower case (hle-hr@...).

.PARAMETER Domain
    UPN domain for personas. Default: the tenant's default verified domain.

.PARAMETER GuestEmail
    External email address for the guest contractor. Optional; skipped with a warning if missing.

.PARAMETER UsageLocation
    Two-letter usage location set on new users (needed before licensing). Default CA.

.PARAMETER BaseSkuPartNumber
    skuPartNumber of the base plan for personas (see the SKU table printed by 00-prereqs-check.ps1),
    for example ENTERPRISEPACK or SPE_E5. If omitted, no base license is assigned (WARN).

.PARAMETER CopilotSkuPartNumber
    skuPartNumber of the Microsoft 365 Copilot add-on. If omitted and exactly one SKU contains
    "Copilot" (and not "Studio"), that SKU is used.

.PARAMETER PasswordFile
    Where to append initial passwords. Default: ~/.harbourline-course/<Prefix>-initial-passwords.csv

.PARAMETER GraphClientId
    Optional client ID for Connect-MgGraph. Omit to use the Microsoft Graph Command Line Tools app.

.PARAMETER Cleanup
    Removes the tagged persona users, the tagged guest and the tagged groups. Does not remove the
    learner's licenses.

.PARAMETER PurgeDeleted
    With -Cleanup: also permanently deletes the removed users and groups from the Entra recycle bin.

.EXAMPLE
    ./setup/01-provision-users.ps1 -TenantUrl https://contoso.sharepoint.com -BaseSkuPartNumber SPE_E5 -CopilotSkuPartNumber Microsoft_365_Copilot -GuestEmail someone@outlook.com

.EXAMPLE
    ./setup/01-provision-users.ps1 -TenantUrl https://contoso.sharepoint.com -Prefix HLE -WhatIf

.EXAMPLE
    ./setup/01-provision-users.ps1 -TenantUrl https://contoso.sharepoint.com -Cleanup -PurgeDeleted

.NOTES
    Delegated Graph scopes: User.ReadWrite.All, Group.ReadWrite.All, Directory.ReadWrite.All,
    User.Invite.All, Organization.Read.All. Role: User Administrator plus License Administrator,
    or Global Administrator. Guest invitations must be allowed in Entra External Identities.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$TenantUrl,
    [ValidatePattern('^[A-Za-z][A-Za-z0-9]{1,9}$')][string]$Prefix = 'HLE',
    [string]$Domain,
    [string]$GuestEmail,
    [ValidatePattern('^[A-Za-z]{2}$')][string]$UsageLocation = 'CA',
    [string]$BaseSkuPartNumber,
    [string]$CopilotSkuPartNumber,
    [string]$PasswordFile,
    [string]$GraphClientId,
    [switch]$Cleanup,
    [switch]$PurgeDeleted
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'common.psm1') -Verbose:$false

Write-Step "01 Provision users and groups$(if ($Cleanup) { ' (CLEANUP)' })" -Level Header
Assert-Module -Name 'Microsoft.Graph.Authentication', 'Microsoft.Graph.Users', 'Microsoft.Graph.Users.Actions',
    'Microsoft.Graph.Groups', 'Microsoft.Graph.Identity.SignIns', 'Microsoft.Graph.Identity.DirectoryManagement'

$names0 = Get-CourseNames -TenantUrl $TenantUrl -Prefix $Prefix
$ctx = Connect-CourseGraph -TenantId $names0.TenantDomain -ClientId $GraphClientId -Scopes @(
    'User.ReadWrite.All', 'Group.ReadWrite.All', 'Directory.ReadWrite.All', 'User.Invite.All', 'Organization.Read.All')
$Domain = Resolve-CourseDomain -Domain $Domain
$names = Get-CourseNames -TenantUrl $TenantUrl -Prefix $Prefix -Domain $Domain
$tag = $names.Tag
$userProps = @('Id', 'DisplayName', 'UserPrincipalName', 'Mail', 'UserType', 'UsageLocation', 'AssignedLicenses', 'OnPremisesExtensionAttributes')

function Get-UserByUpn([string]$Upn) {
    $u = @(Get-MgUser -Filter ("userPrincipalName eq '{0}'" -f $Upn.Replace("'", "''")) -Property $userProps)
    if ($u.Count -eq 0) { return $null }
    return $u[0]
}
function Get-GroupByName([string]$Name) {
    $g = @(Get-MgGroup -Filter ("displayName eq '{0}'" -f $Name.Replace("'", "''")) -Property 'Id', 'DisplayName', 'Description', 'SecurityEnabled', 'MailEnabled')
    if ($g.Count -eq 0) { return $null }
    return $g[0]
}
function Remove-FromRecycleBin([string]$Id, [string]$Label) {
    if (-not $PurgeDeleted) { return }
    for ($i = 0; $i -lt 6; $i++) {
        try {
            Invoke-MgGraphRequest -Method DELETE -Uri "https://graph.microsoft.com/v1.0/directory/deletedItems/$Id" | Out-Null
            Write-Step "Purged $Label from the Entra recycle bin" -Level Ok
            return
        }
        catch { Start-Sleep -Seconds 10 }
    }
    Write-Step "Could not purge $Label ($Id) yet. It stays in Entra deleted items for up to 30 days, or purge it in the Entra admin center." -Level Warn
}

# =============================================================================================
# CLEANUP
# =============================================================================================
if ($Cleanup) {
    foreach ($p in $names.Personas.PSObject.Properties.Value) {
        $u = Get-UserByUpn $p.Upn
        if (-not $u) { Write-Step "User $($p.Upn) not found" -Level Skip; continue }
        if (-not (Test-CourseTagged -User $u -Tag $tag)) {
            Write-Step "User $($p.Upn) exists but is not tagged $tag. Not removing it." -Level Warn
            continue
        }
        $done = Invoke-CourseAction -Cmdlet $PSCmdlet -Target $p.Upn -Action 'Delete user' -ScriptBlock { Remove-MgUser -UserId $u.Id; $true }
        if ($done) { Remove-FromRecycleBin -Id $u.Id -Label $p.Upn }
    }

    # Guest: by -GuestEmail, otherwise by tag (advanced query).
    $guests = @()
    if ($GuestEmail) {
        $guests = @(Get-MgUser -Filter ("mail eq '{0}'" -f $GuestEmail.Replace("'", "''")) -Property $userProps | Where-Object { $_.UserType -eq 'Guest' })
    }
    else {
        try {
            $f = ConvertTo-CourseFilter ("onPremisesExtensionAttributes/extensionAttribute15 eq '$tag' and userType eq 'Guest'")
            $guests = @(Invoke-CourseGraph -Uri ('v1.0/users?$count=true&$select=id,userPrincipalName,mail,onPremisesExtensionAttributes&$filter=' + $f) -Headers @{ ConsistencyLevel = 'eventual' } -All)
        }
        catch {
            Write-Step "Could not search guests by tag ($($_.Exception.Message)). Re-run with -GuestEmail to remove the guest." -Level Warn
        }
    }
    foreach ($g in $guests) {
        if (-not (Test-CourseTagged -User $g -Tag $tag)) {
            Write-Step "Guest $(Get-CourseProp $g 'Mail') is not tagged $tag. Not removing it." -Level Warn
            continue
        }
        $gid = [string](Get-CourseProp $g 'Id'); if (-not $gid) { $gid = [string](Get-CourseProp $g 'id') }
        $done = Invoke-CourseAction -Cmdlet $PSCmdlet -Target $gid -Action 'Delete guest user' -ScriptBlock { Remove-MgUser -UserId $gid; $true }
        if ($done) { Remove-FromRecycleBin -Id $gid -Label 'guest' }
    }
    if ($guests.Count -eq 0) { Write-Step 'No tagged guest found' -Level Skip }

    foreach ($gn in $names.Groups.PSObject.Properties.Value) {
        $grp = Get-GroupByName $gn
        if (-not $grp) { Write-Step "Group $gn not found" -Level Skip; continue }
        if (-not ([string]$grp.Description).StartsWith("[$tag]")) {
            Write-Step "Group $gn exists but its description is not tagged [$tag]. Not removing it." -Level Warn
            continue
        }
        $done = Invoke-CourseAction -Cmdlet $PSCmdlet -Target $gn -Action 'Delete group' -ScriptBlock { Remove-MgGroup -GroupId $grp.Id; $true }
        if ($done) { Remove-FromRecycleBin -Id $grp.Id -Label $gn }
    }
    Write-Step 'The learner account keeps its licenses and roles. Remove the Copilot license manually if it was added for the course.' -Level Info
    Write-Step '01 cleanup complete' -Level Ok
    return
}

# =============================================================================================
# PROVISION
# =============================================================================================

# ---- SKUs ------------------------------------------------------------------------------------
$skus = @(Get-MgSubscribedSku -All)
function Resolve-Sku([string]$PartNumber, [string]$Label) {
    if (-not $PartNumber) { return $null }
    $s = @($skus | Where-Object { $_.SkuPartNumber -ieq $PartNumber })
    if ($s.Count -eq 0) { throw "$Label SKU '$PartNumber' not found. Run 00-prereqs-check.ps1 to list SKUs." }
    $free = [int]$s[0].PrepaidUnits.Enabled - [int]$s[0].ConsumedUnits
    Write-Step "$Label SKU $($s[0].SkuPartNumber) ($($s[0].SkuId)), $free free" -Level Info
    return $s[0]
}
if (-not $CopilotSkuPartNumber) {
    $cand = @($skus | Where-Object { $_.SkuPartNumber -match 'Copilot' -and $_.SkuPartNumber -notmatch 'Studio' })
    if ($cand.Count -eq 1) {
        $CopilotSkuPartNumber = $cand[0].SkuPartNumber
        Write-Step "Auto-selected Copilot SKU $CopilotSkuPartNumber (override with -CopilotSkuPartNumber)" -Level Info
    }
    else {
        Write-Step "Could not auto-select a Copilot SKU ($($cand.Count) candidates). Pass -CopilotSkuPartNumber. Copilot licensing skipped." -Level Warn
    }
}
$baseSku = Resolve-Sku $BaseSkuPartNumber 'Base'
$copilotSku = Resolve-Sku $CopilotSkuPartNumber 'Copilot'
if (-not $baseSku) { Write-Step 'No -BaseSkuPartNumber given. Personas get no base license (no mailbox, no OneDrive); Copilot assignment may fail without a base plan (LIC-01).' -Level Warn }

function Set-CourseLicenses($User, [bool]$WantCopilot, [bool]$WantBase) {
    $have = @($User.AssignedLicenses | ForEach-Object { [string]$_.SkuId })
    $add = @()
    if ($WantBase -and $baseSku -and ($have -notcontains [string]$baseSku.SkuId)) { $add += @{ SkuId = $baseSku.SkuId } }
    if ($WantCopilot -and $copilotSku -and ($have -notcontains [string]$copilotSku.SkuId)) { $add += @{ SkuId = $copilotSku.SkuId } }
    if ($add.Count -eq 0) { Write-Step "Licenses already correct for $($User.UserPrincipalName)" -Level Skip; return }
    if (-not $User.UsageLocation) {
        $null = Invoke-CourseAction -Cmdlet $PSCmdlet -Target $User.UserPrincipalName -Action "Set usageLocation $UsageLocation" -ScriptBlock {
            Update-MgUser -UserId $User.Id -UsageLocation $UsageLocation
        }
    }
    $skuList = ($add | ForEach-Object { $_.SkuId }) -join ', '
    $null = Invoke-CourseAction -Cmdlet $PSCmdlet -Target $User.UserPrincipalName -Action "Assign licenses $skuList" -ScriptBlock {
        Set-MgUserLicense -UserId $User.Id -AddLicenses $add -RemoveLicenses @() | Out-Null
    }
}

# ---- Groups ----------------------------------------------------------------------------------
$groupPurpose = @{
    AllStaff     = 'All Harbourline employees (course personas). Hub visitors.'
    HR           = 'Human Resources. Hub members, HR-Policies/Restricted edit, label rights.'
    Finance      = 'Finance. Hub members, Finance library edit.'
    OpsOntario   = 'Ontario operations. Connector ACLs (Lab 7).'
    OpsUS        = 'US operations (New York, Ohio). Connector ACLs (Lab 7).'
    CourseMakers = 'Course makers. Use for agent sharing and Copilot Studio authors settings.'
}
$groupIds = @{}
foreach ($prop in $names.Groups.PSObject.Properties) {
    $gn = $prop.Value
    $grp = Get-GroupByName $gn
    if ($grp) {
        if (-not ([string]$grp.Description).StartsWith("[$tag]")) {
            Write-Step "Group $gn exists without the [$tag] tag. Reusing it; -Cleanup will not delete it." -Level Warn
        }
        else { Write-Step "Group $gn exists" -Level Skip }
    }
    else {
        $body = @{
            DisplayName     = $gn
            Description     = "[$tag] $($groupPurpose[$prop.Name])"
            MailEnabled     = $false
            MailNickname    = $gn.ToLowerInvariant()
            SecurityEnabled = $true
        }
        $grp = Invoke-CourseAction -Cmdlet $PSCmdlet -Target $gn -Action 'Create security group' -ScriptBlock { New-MgGroup -BodyParameter $body }
    }
    if ($grp) { $groupIds[$gn] = $grp.Id }
}

$memberCache = @{}
function Add-CourseGroupMember([string]$GroupName, [string]$UserId, [string]$Label) {
    if (-not $groupIds.ContainsKey($GroupName) -or -not $UserId) {
        Write-Step "Skipping membership $Label -> $GroupName (group or user not available, WhatIf?)" -Level Skip
        return
    }
    $gid = $groupIds[$GroupName]
    if (-not $memberCache.ContainsKey($gid)) {
        $memberCache[$gid] = @(Get-MgGroupMember -GroupId $gid -All | ForEach-Object { $_.Id })
    }
    if ($memberCache[$gid] -contains $UserId) { Write-Step "$Label already in $GroupName" -Level Skip; return }
    $null = Invoke-CourseAction -Cmdlet $PSCmdlet -Target $GroupName -Action "Add member $Label" -ScriptBlock {
        New-MgGroupMemberByRef -GroupId $gid -BodyParameter @{ '@odata.id' = "https://graph.microsoft.com/v1.0/directoryObjects/$UserId" }
    }
    $memberCache[$gid] += $UserId
}

# ---- Personas --------------------------------------------------------------------------------
$newSecrets = New-Object System.Collections.Generic.List[string]
foreach ($p in $names.Personas.PSObject.Properties.Value) {
    $u = Get-UserByUpn $p.Upn
    if ($u) {
        if (-not (Test-CourseTagged -User $u -Tag $tag)) {
            Write-Step "User $($p.Upn) exists but is not tagged $tag. Leaving it unchanged." -Level Warn
            continue
        }
        Write-Step "User $($p.Upn) exists" -Level Skip
    }
    else {
        $pw = New-CoursePassword
        $body = @{
            AccountEnabled    = $true
            DisplayName       = $p.DisplayName
            GivenName         = $p.GivenName
            Surname           = $p.Surname
            JobTitle          = $p.JobTitle
            Department        = $p.Department
            CompanyName       = 'Harbourline Energy Co.'
            MailNickname      = $p.MailNickname
            UserPrincipalName = $p.Upn
            UsageLocation     = $UsageLocation
            PasswordProfile   = @{ Password = $pw; ForceChangePasswordNextSignIn = $true }
            OnPremisesExtensionAttributes = @{ ExtensionAttribute15 = $tag }
        }
        $created = Invoke-CourseAction -Cmdlet $PSCmdlet -Target $p.Upn -Action "Create user $($p.DisplayName)" -ScriptBlock { New-MgUser -BodyParameter $body }
        if (-not $created) { continue }
        $newSecrets.Add("$($p.Upn),$pw")
        $u = $null
        $u = Wait-CourseCondition -Description "user $($p.Upn) to replicate" -TimeoutSeconds 120 -IntervalSeconds 5 -Condition { Get-UserByUpn $p.Upn }
        if (-not $u) { Write-Step "User $($p.Upn) not readable yet. Re-run the script to finish licensing and groups." -Level Warn; continue }
    }
    Set-CourseLicenses -User $u -WantCopilot $p.Copilot -WantBase $true
    foreach ($gn in $p.Groups) { Add-CourseGroupMember -GroupName $gn -UserId $u.Id -Label $p.Upn }
}

# ---- Learner ---------------------------------------------------------------------------------
$learner = Get-MgUser -UserId $ctx.Account -Property $userProps
Write-Step "Learner is $($learner.UserPrincipalName)" -Level Info
foreach ($gn in $names.Groups.PSObject.Properties.Value) { Add-CourseGroupMember -GroupName $gn -UserId $learner.Id -Label $learner.UserPrincipalName }
Set-CourseLicenses -User $learner -WantCopilot $true -WantBase $false

# ---- Guest -----------------------------------------------------------------------------------
if (-not $GuestEmail) {
    Write-Step 'No -GuestEmail given. Guest contractor skipped; guest labs (Lab 3, Lab 7 guest tests) will not have a guest persona.' -Level Warn
}
else {
    $guest = @(Get-MgUser -Filter ("mail eq '{0}'" -f $GuestEmail.Replace("'", "''")) -Property $userProps | Where-Object { $_.UserType -eq 'Guest' }) | Select-Object -First 1
    if ($guest) {
        Write-Step "Guest $GuestEmail already exists ($($guest.UserPrincipalName))" -Level Skip
    }
    else {
        $inv = Invoke-CourseAction -Cmdlet $PSCmdlet -Target $GuestEmail -Action 'Invite guest' -ScriptBlock {
            New-MgInvitation -InvitedUserEmailAddress $GuestEmail -InvitedUserDisplayName $names.GuestDisplayName `
                -InviteRedirectUrl 'https://myapps.microsoft.com' -SendInvitationMessage:$true
        }
        if ($inv) {
            $gid = $inv.InvitedUser.Id
            $guest = Wait-CourseCondition -Description 'guest to replicate' -TimeoutSeconds 120 -IntervalSeconds 5 -Condition { Get-MgUser -UserId $gid -Property $userProps }
        }
    }
    if ($guest -and -not (Test-CourseTagged -User $guest -Tag $tag)) {
        $null = Invoke-CourseAction -Cmdlet $PSCmdlet -Target $GuestEmail -Action "Tag guest with $tag" -ScriptBlock {
            Update-MgUser -UserId $guest.Id -BodyParameter @{ OnPremisesExtensionAttributes = @{ ExtensionAttribute15 = $tag }; CompanyName = 'Harbourline contractor' }
        }
    }
    Write-Step 'The guest must redeem the invitation email before it can open the Operations site.' -Level Info
}

# ---- Secrets ---------------------------------------------------------------------------------
if ($newSecrets.Count -gt 0) {
    if (-not $PasswordFile) { $PasswordFile = Join-Path $HOME ".harbourline-course/$Prefix-initial-passwords.csv" }
    $lines = @("# $(Get-Date -Format s) initial passwords (change at first sign-in)") + $newSecrets.ToArray()
    Save-CourseSecret -Path $PasswordFile -Lines $lines -WhatIf:$WhatIfPreference -Confirm:$false
}
else {
    Write-Step 'No new users, so no passwords written. Reset a persona password in the Entra admin center if you lost it.' -Level Info
}

Write-Step '01 provisioning complete. Next: 02-provision-sites.ps1' -Level Ok
