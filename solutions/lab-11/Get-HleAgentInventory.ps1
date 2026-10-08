<#
.SYNOPSIS
    Lab 11 Part F: list course agents, or pending agent requests, from the Microsoft 365 agent
    inventory through the package management Graph API (PREVIEW, ADM-05).

.DESCRIPTION
    Calls GET https://graph.microsoft.com/<ApiVersion>/copilot/admin/catalog/packages with the
    Microsoft.Graph PowerShell SDK (Invoke-MgGraphRequest). With -PendingOnly it adds
    $filter=requestStatus eq 'pending', which the API reference documents as "the open request
    queue". Follows @odata.nextLink. Filters to display names that contain the course prefix unless
    -AllAgents is set.

    Read-only. Permission: CopilotPackages.Read.All (delegated). The Microsoft 365 admin center
    page says the API works with the AI Administrator role.

    Sources, read 2026-09-30: MicrosoftDocs/m365copilot-docs docs/api/admin-settings/package/
    copilotpackages-list.md (the page shows both beta and v1.0 pivots) and the Agent Registry admin
    page, which labels the API preview (ADM-05). The default here is beta; check Learn and pass
    -ApiVersion v1.0 if that is now the documented version.

.PARAMETER TenantUrl
    SharePoint tenant URL. Not used; accepted for consistency with the course scripts.

.PARAMETER Prefix
    Course prefix (default HLE). Agents whose displayName contains it are shown.

.PARAMETER PendingOnly
    Only packages with an open request (requestStatus eq 'pending').

.PARAMETER AllAgents
    Do not filter by prefix.

.PARAMETER ApiVersion
    beta (default) or v1.0.

.PARAMETER OutputCsv
    Optional CSV path for the results.

.PARAMETER Cleanup
    Delete -OutputCsv if it exists and disconnect from Graph. Makes no tenant change.

.EXAMPLE
    ./Get-HleAgentInventory.ps1 -PendingOnly
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$TenantUrl,

    [ValidatePattern('^[A-Za-z][A-Za-z0-9]{1,7}$')]
    [string]$Prefix = 'HLE',

    [switch]$PendingOnly,

    [switch]$AllAgents,

    [ValidateSet('beta', 'v1.0')]
    [string]$ApiVersion = 'beta',

    [string]$OutputCsv,

    [switch]$Cleanup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Prop($Object, [string]$Name) {
    if ($Object -is [System.Collections.IDictionary]) { if ($Object.Contains($Name)) { return $Object[$Name] } else { return $null } }
    $p = $Object.PSObject.Properties[$Name]
    if ($p) { return $p.Value } else { return $null }
}

if ($Cleanup) {
    if ($OutputCsv -and (Test-Path $OutputCsv) -and $PSCmdlet.ShouldProcess($OutputCsv, 'Remove output CSV')) {
        Remove-Item -LiteralPath $OutputCsv
    }
    if (Get-Command Disconnect-MgGraph -ErrorAction SilentlyContinue) { Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null }
    Write-Host 'Cleanup complete. This script makes no tenant changes.'
    return
}

if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
    throw 'Install the Microsoft Graph PowerShell SDK: Install-Module Microsoft.Graph.Authentication -Scope CurrentUser'
}
Import-Module Microsoft.Graph.Authentication
$ctx = Get-MgContext
if (-not $ctx -or -not ($ctx.Scopes -contains 'CopilotPackages.Read.All' -or $ctx.Scopes -contains 'CopilotPackages.ReadWrite.All')) {
    Connect-MgGraph -Scopes 'CopilotPackages.Read.All' -NoWelcome
}

$uri = "https://graph.microsoft.com/$ApiVersion/copilot/admin/catalog/packages"
if ($PendingOnly) { $uri += "?`$filter=" + [uri]::EscapeDataString("requestStatus eq 'pending'") }

$items = [System.Collections.Generic.List[object]]::new()
while ($uri) {
    $resp = Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType PSObject
    foreach ($v in @(Get-Prop $resp 'value')) { if ($null -ne $v) { $items.Add($v) } }
    $uri = Get-Prop $resp '@odata.nextLink'
}

$rows = foreach ($i in $items) {
    [pscustomobject]@{
        displayName   = Get-Prop $i 'displayName'
        type          = Get-Prop $i 'type'
        platform      = Get-Prop $i 'platform'
        isBlocked     = Get-Prop $i 'isBlocked'
        availableTo   = Get-Prop $i 'availableTo'
        deployedTo    = Get-Prop $i 'deployedTo'
        requestType   = Get-Prop $i 'requestType'
        requestStatus = Get-Prop $i 'requestStatus'
        lastModified  = Get-Prop $i 'lastModifiedDateTime'
        id            = Get-Prop $i 'id'
    }
}
if (-not $AllAgents) { $rows = @($rows | Where-Object { "$($_.displayName)" -like "*$Prefix*" }) }

Write-Host "Packages returned: $($items.Count); shown: $(@($rows).Count) (API $ApiVersion, preview per ADM-05)"
$rows | Format-Table displayName, platform, type, isBlocked, availableTo, deployedTo, requestType, requestStatus -AutoSize

if ($OutputCsv -and $PSCmdlet.ShouldProcess($OutputCsv, 'Write CSV')) {
    $dir = Split-Path -Parent $OutputCsv
    if ($dir) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $rows | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding utf8
}
