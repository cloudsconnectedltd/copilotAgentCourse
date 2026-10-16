<#
.SYNOPSIS
    Creates the CaseWorks test accounts (CWT) and assigns their licenses.

.DESCRIPTION
    Uses the same helpers and conventions as setup/01-provision-users.ps1 (setup/common.psm1).
    Idempotent. Creates (only if missing):
        CWT Test Coordinator    cwt.coordinator@<domain>  base licenses + Copilot
        CWT Test Drafter        cwt.drafter@<domain>      base licenses
        CWT Test Reviewer       cwt.reviewer@<domain>     base licenses
        CWT Test Reader         cwt.reader@<domain>       base licenses
        CWT Test Gas Reviewer   cwt.gas@<domain>          base licenses
        CWT Test No Access      cwt.outsider@<domain>     base licenses

    "Base licenses" are every SKU passed in -BaseSkuPartNumber, for example Business Premium (no Teams)
    and Teams Enterprise. The script adds no group memberships: CaseWorks group membership is part of
    the test and is managed separately. cwt.outsider must stay out of every CaseWorks group.

    Every user created is tagged so -Cleanup only removes what this script created:
        onPremisesExtensionAttributes.extensionAttribute15 = "CWT-TestSetup"

    Initial passwords of newly created users are written once to -PasswordFile (readable only by you).
    They are never printed. Users must change the password at first sign-in.

    Run without -BaseSkuPartNumber to print the tenant's SKUs and free seats, then stop.

.PARAMETER TenantUrl
    Root SharePoint URL, for example https://cloudsconnected.sharepoint.com. Used to derive the tenant.

.PARAMETER Domain
    UPN domain. Default cloudsconnected.com.

.PARAMETER UsageLocation
    Two-letter usage location set on new users (needed before licensing). Required.

.PARAMETER BaseSkuPartNumber
    One or more skuPartNumbers assigned to every test user.

.PARAMETER CopilotSkuPartNumber
    skuPartNumber of the Microsoft 365 Copilot add-on, assigned to cwt.coordinator only. If omitted and
    exactly one SKU contains "Copilot" (and not "Studio"), that SKU is used.

.PARAMETER Only
    Limit the run to these account keys: coordinator, drafter, reviewer, reader, gas, outsider.

.PARAMETER PasswordFile
    Where to append initial passwords. Default: ~/.caseworks-test/CWT-initial-passwords.csv

.PARAMETER GraphClientId
    Optional client ID for Connect-MgGraph. Omit to use the Microsoft Graph Command Line Tools app.

.PARAMETER Cleanup
    Removes the tagged test users.

.PARAMETER PurgeDeleted
    With -Cleanup: also permanently deletes the removed users from the Entra recycle bin.

.EXAMPLE
    ./tools/caseworks-test-users/provision-test-users.ps1 -TenantUrl https://cloudsconnected.sharepoint.com -UsageLocation GB

    Lists SKUs so you can pick the part numbers.

.EXAMPLE
    ./tools/caseworks-test-users/provision-test-users.ps1 -TenantUrl https://cloudsconnected.sharepoint.com -UsageLocation GB `
        -BaseSkuPartNumber '<Business Premium no Teams>', '<Teams Enterprise>' -CopilotSkuPartNumber Microsoft_365_Copilot -WhatIf

.EXAMPLE
    ./tools/caseworks-test-users/provision-test-users.ps1 -TenantUrl https://cloudsconnected.sharepoint.com -UsageLocation GB -Cleanup -PurgeDeleted

.NOTES
    Delegated Graph scopes: User.ReadWrite.All, Directory.ReadWrite.All, Organization.Read.All.
    Role: User Administrator plus License Administrator, or Global Administrator.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$TenantUrl,
    [string]$Domain = 'cloudsconnected.com',
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z]{2}$')][string]$UsageLocation,
    [string[]]$BaseSkuPartNumber,
    [string]$CopilotSkuPartNumber,
    [ValidateSet('coordinator', 'drafter', 'reviewer', 'reader', 'gas', 'outsider')][string[]]$Only,
    [string]$PasswordFile,
    [string]$GraphClientId,
    [switch]$Cleanup,
    [switch]$PurgeDeleted
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../../setup/common.psm1') -Force -Verbose:$false

Write-Step "CaseWorks test users$(if ($Cleanup) { ' (CLEANUP)' })" -Level Header
Assert-Module -Name 'Microsoft.Graph.Authentication', 'Microsoft.Graph.Users', 'Microsoft.Graph.Users.Actions',
    'Microsoft.Graph.Identity.DirectoryManagement'

$tag = 'CWT-TestSetup'
$accountDefs = @(
    @{ Key = 'coordinator'; GivenName = 'CWT Test'; Surname = 'Coordinator';   JobTitle = 'Global coordinator'; Copilot = $true }
    @{ Key = 'drafter';     GivenName = 'CWT Test'; Surname = 'Drafter';       JobTitle = 'FERC drafter';       Copilot = $false }
    @{ Key = 'reviewer';    GivenName = 'CWT Test'; Surname = 'Reviewer';      JobTitle = 'FERC reviewer';      Copilot = $false }
    @{ Key = 'reader';      GivenName = 'CWT Test'; Surname = 'Reader';        JobTitle = 'Global reader';      Copilot = $false }
    @{ Key = 'gas';         GivenName = 'CWT Test'; Surname = 'Gas Reviewer';  JobTitle = 'Gas reviewer';       Copilot = $false }
    @{ Key = 'outsider';    GivenName = 'CWT Test'; Surname = 'No Access';     JobTitle = 'No CaseWorks access'; Copilot = $false }
)
$accounts = @($accountDefs | Where-Object { -not $Only -or $Only -contains $_.Key } | ForEach-Object {
    [pscustomobject]@{
        Key          = $_.Key
        DisplayName  = "$($_.GivenName) $($_.Surname)"
        GivenName    = $_.GivenName
        Surname      = $_.Surname
        JobTitle     = $_.JobTitle
        MailNickname = "cwt.$($_.Key)"
        Upn          = "cwt.$($_.Key)@$Domain"
        Copilot      = $_.Copilot
    }
})

$names = Get-CourseNames -TenantUrl $TenantUrl
$null = Connect-CourseGraph -TenantId $names.TenantDomain -ClientId $GraphClientId -Scopes @(
    'User.ReadWrite.All', 'Directory.ReadWrite.All', 'Organization.Read.All')
$userProps = @('Id', 'DisplayName', 'UserPrincipalName', 'UsageLocation', 'AssignedLicenses', 'OnPremisesExtensionAttributes')

function Get-UserByUpn([string]$Upn) {
    $u = @(Get-MgUser -Filter ("userPrincipalName eq '{0}'" -f $Upn.Replace("'", "''")) -Property $userProps)
    if ($u.Count -eq 0) { return $null }
    return $u[0]
}

# =============================================================================================
# CLEANUP
# =============================================================================================
if ($Cleanup) {
    foreach ($a in $accounts) {
        $u = Get-UserByUpn $a.Upn
        if (-not $u) { Write-Step "User $($a.Upn) not found" -Level Skip; continue }
        if (-not (Test-CourseTagged -User $u -Tag $tag)) {
            Write-Step "User $($a.Upn) exists but is not tagged $tag. Not removing it." -Level Warn
            continue
        }
        $done = Invoke-CourseAction -Cmdlet $PSCmdlet -Target $a.Upn -Action 'Delete user' -ScriptBlock { Remove-MgUser -UserId $u.Id; $true }
        if ($done -and $PurgeDeleted) {
            $purged = $false
            for ($i = 0; $i -lt 6 -and -not $purged; $i++) {
                try {
                    Invoke-MgGraphRequest -Method DELETE -Uri "https://graph.microsoft.com/v1.0/directory/deletedItems/$($u.Id)" | Out-Null
                    $purged = $true
                    Write-Step "Purged $($a.Upn) from the Entra recycle bin" -Level Ok
                }
                catch { Start-Sleep -Seconds 10 }
            }
            if (-not $purged) { Write-Step "Could not purge $($a.Upn) yet. Purge it in the Entra admin center." -Level Warn }
        }
    }
    Write-Step 'Cleanup complete' -Level Ok
    return
}

# =============================================================================================
# PROVISION
# =============================================================================================

# ---- SKUs ------------------------------------------------------------------------------------
$skus = @(Get-MgSubscribedSku -All)
if (-not $BaseSkuPartNumber) {
    Write-Step 'No -BaseSkuPartNumber given. Tenant SKUs are listed below; re-run with the part numbers you need.' -Level Warn
    $skus | Sort-Object SkuPartNumber | ForEach-Object {
        [pscustomobject]@{ SkuPartNumber = $_.SkuPartNumber; Enabled = [int]$_.PrepaidUnits.Enabled; Consumed = [int]$_.ConsumedUnits; Free = [int]$_.PrepaidUnits.Enabled - [int]$_.ConsumedUnits }
    } | Format-Table -AutoSize | Out-String -Width 200 | Write-Host
    return
}

function Resolve-Sku([string]$PartNumber, [string]$Label, [int]$Needed) {
    $s = @($skus | Where-Object { $_.SkuPartNumber -ieq $PartNumber })
    if ($s.Count -eq 0) { throw "$Label SKU '$PartNumber' not found. Run without -BaseSkuPartNumber to list SKUs." }
    $free = [int]$s[0].PrepaidUnits.Enabled - [int]$s[0].ConsumedUnits
    $level = if ($free -lt $Needed) { 'Warn' } else { 'Info' }
    Write-Step "$Label SKU $($s[0].SkuPartNumber) ($($s[0].SkuId)), $free free, up to $Needed needed" -Level $level
    return $s[0]
}

if (-not $CopilotSkuPartNumber -and @($accounts | Where-Object Copilot).Count -gt 0) {
    $cand = @($skus | Where-Object { $_.SkuPartNumber -match 'Copilot' -and $_.SkuPartNumber -notmatch 'Studio' })
    if ($cand.Count -eq 1) {
        $CopilotSkuPartNumber = $cand[0].SkuPartNumber
        Write-Step "Auto-selected Copilot SKU $CopilotSkuPartNumber (override with -CopilotSkuPartNumber)" -Level Info
    }
    else {
        Write-Step "Could not auto-select a Copilot SKU ($($cand.Count) candidates). Pass -CopilotSkuPartNumber. Copilot licensing skipped." -Level Warn
    }
}
$baseSkus = @($BaseSkuPartNumber | ForEach-Object { Resolve-Sku $_ 'Base' $accounts.Count })
$copilotSku = if ($CopilotSkuPartNumber) { Resolve-Sku $CopilotSkuPartNumber 'Copilot' @($accounts | Where-Object Copilot).Count } else { $null }

function Set-TestLicenses($User, [bool]$WantCopilot) {
    $have = @($User.AssignedLicenses | ForEach-Object { [string]$_.SkuId })
    $want = @($baseSkus) + $(if ($WantCopilot -and $copilotSku) { @($copilotSku) } else { @() })
    $add = @($want | Where-Object { $have -notcontains [string]$_.SkuId } | ForEach-Object { @{ SkuId = $_.SkuId } })
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

# ---- Users -----------------------------------------------------------------------------------
$newSecrets = New-Object System.Collections.Generic.List[string]
foreach ($a in $accounts) {
    $u = Get-UserByUpn $a.Upn
    if ($u) {
        if (-not (Test-CourseTagged -User $u -Tag $tag)) {
            Write-Step "User $($a.Upn) exists but is not tagged $tag. Leaving it unchanged." -Level Warn
            continue
        }
        Write-Step "User $($a.Upn) exists" -Level Skip
    }
    else {
        $pw = New-CoursePassword
        $body = @{
            AccountEnabled    = $true
            DisplayName       = $a.DisplayName
            GivenName         = $a.GivenName
            Surname           = $a.Surname
            JobTitle          = $a.JobTitle
            Department        = 'CaseWorks Test'
            CompanyName       = 'Clouds Connected'
            MailNickname      = $a.MailNickname
            UserPrincipalName = $a.Upn
            UsageLocation     = $UsageLocation
            PasswordProfile   = @{ Password = $pw; ForceChangePasswordNextSignIn = $true }
            OnPremisesExtensionAttributes = @{ ExtensionAttribute15 = $tag }
        }
        $created = Invoke-CourseAction -Cmdlet $PSCmdlet -Target $a.Upn -Action "Create user $($a.DisplayName)" -ScriptBlock { New-MgUser -BodyParameter $body }
        if (-not $created) { continue }
        $newSecrets.Add("$($a.Upn),$pw")
        $u = Wait-CourseCondition -Description "user $($a.Upn) to replicate" -TimeoutSeconds 120 -IntervalSeconds 5 -Condition { Get-UserByUpn $a.Upn }
        if (-not $u) { Write-Step "User $($a.Upn) not readable yet. Re-run the script to finish licensing." -Level Warn; continue }
    }
    Set-TestLicenses -User $u -WantCopilot $a.Copilot
}

# ---- Secrets ---------------------------------------------------------------------------------
if ($newSecrets.Count -gt 0) {
    if (-not $PasswordFile) { $PasswordFile = Join-Path $HOME '.caseworks-test/CWT-initial-passwords.csv' }
    $lines = @("# $(Get-Date -Format s) initial passwords (change at first sign-in)") + $newSecrets.ToArray()
    Save-CourseSecret -Path $PasswordFile -Lines $lines -WhatIf:$WhatIfPreference -Confirm:$false
}
else {
    Write-Step 'No new users, so no passwords written. Reset a password in the Entra admin center if you lost it.' -Level Info
}

Write-Step 'CaseWorks test users complete. Add them to the CaseWorks groups next (never cwt.outsider).' -Level Ok
