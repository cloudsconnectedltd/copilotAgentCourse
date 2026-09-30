<#
.SYNOPSIS
    Lab 11 Part G: search the unified audit log for Copilot interactions with course agents.

.DESCRIPTION
    Connects to Exchange Online PowerShell (ExchangeOnlineManagement), checks that unified audit
    log ingestion is on, runs Search-UnifiedAuditLog for record type CopilotInteraction in pages
    (SessionCommand ReturnLargeSet), parses the AuditData JSON of each record and writes one CSV
    row per record: time, user, operation, AppIdentity, AgentId, AgentName (if present) and the
    raw AuditData for inspection.

    Read-only against the tenant. The only thing it creates is the output CSV; -Cleanup deletes it.
    Re-running overwrites the CSV, so the script is idempotent.

    CONFIRM ON MICROSOFT LEARN BEFORE USE (reference/limits.md AUD-01 is tagged SNIP):
      - The -RecordType value 'CopilotInteraction'. If Search-UnifiedAuditLog rejects it, list valid
        values in the Search-UnifiedAuditLog reference and pass the right one with -RecordType.
      - The field names inside AuditData. This script looks for AppIdentity and AgentId at the top
        level and under CopilotEventData, and for AgentName. Change $FieldPaths if Learn shows
        different names.
      - The paging pattern (SessionId plus SessionCommand ReturnLargeSet, ResultSize up to 5000 per
        call) and the maximum date range for a search. Check the cmdlet reference.
      - How long after an interaction the record becomes searchable. No value is stated in this
        course; check Learn.
      Pages: https://learn.microsoft.com/en-us/purview/audit-copilot and the Search-UnifiedAuditLog
      cmdlet reference.

.PARAMETER TenantUrl
    SharePoint tenant URL. Not used by the audit cmdlets; accepted for consistency and printed.

.PARAMETER Prefix
    Course prefix (default HLE). Used to filter agent names that start with "<Prefix> " when
    -AgentNameLike is not given.

.PARAMETER AdminUpn
    UPN used for Connect-ExchangeOnline. Needs an audit search role in Purview.

.PARAMETER UserIds
    Optional list of UPNs to limit the search (for example hle-tech@contoso.onmicrosoft.com).

.PARAMETER StartDate
    Start of the search window. Default: 24 hours ago.

.PARAMETER EndDate
    End of the search window. Default: now.

.PARAMETER RecordType
    Audit record type. Default CopilotInteraction (confirm on Learn).

.PARAMETER AgentNameLike
    Wildcard filter applied to the parsed agent name or AppIdentity, for example '*Field Ops*'.
    Default "*<Prefix>*". Use '*' to keep every Copilot interaction.

.PARAMETER OutputCsv
    Output file. Default ./out/lab-11/copilot-interactions.csv

.PARAMETER SkipConnect
    Do not call Connect-ExchangeOnline (use an existing session).

.PARAMETER Cleanup
    Delete the output CSV and disconnect. Makes no tenant change.

.EXAMPLE
    ./Search-HleAgentAudit.ps1 -AdminUpn admin@contoso.onmicrosoft.com -UserIds hle-tech@contoso.onmicrosoft.com

.EXAMPLE
    ./Search-HleAgentAudit.ps1 -AdminUpn admin@contoso.onmicrosoft.com -AgentNameLike '*' -StartDate (Get-Date).AddDays(-7)
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$TenantUrl,

    [ValidatePattern('^[A-Za-z][A-Za-z0-9]{1,7}$')]
    [string]$Prefix = 'HLE',

    [string]$AdminUpn,

    [string[]]$UserIds,

    [datetime]$StartDate = (Get-Date).AddDays(-1),

    [datetime]$EndDate = (Get-Date),

    [string]$RecordType = 'CopilotInteraction',

    [string]$AgentNameLike,

    [string]$OutputCsv = (Join-Path (Get-Location) 'out/lab-11/copilot-interactions.csv'),

    [switch]$SkipConnect,

    [switch]$Cleanup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $AgentNameLike) { $AgentNameLike = "*$Prefix*" }

# Candidate locations of each field inside AuditData. Confirm on Learn (AUD-01 is SNIP).
$FieldPaths = @{
    AppIdentity = @('AppIdentity', 'CopilotEventData.AppIdentity')
    AgentId     = @('AgentId', 'CopilotEventData.AgentId')
    AgentName   = @('AgentName', 'CopilotEventData.AgentName')
    AppHost     = @('CopilotEventData.AppHost', 'AppHost')
}

function Get-JsonPath($Object, [string]$Path) {
    $current = $Object
    foreach ($part in $Path.Split('.')) {
        if ($null -eq $current) { return $null }
        $prop = $current.PSObject.Properties[$part]
        if (-not $prop) { return $null }
        $current = $prop.Value
    }
    return $current
}

function Get-FirstField($Object, [string[]]$Paths) {
    foreach ($p in $Paths) {
        $v = Get-JsonPath $Object $p
        if ($null -ne $v -and "$v" -ne '') { return "$v" }
    }
    return ''
}

if ($Cleanup) {
    if (Test-Path $OutputCsv) {
        if ($PSCmdlet.ShouldProcess($OutputCsv, 'Remove output CSV')) { Remove-Item -LiteralPath $OutputCsv }
    }
    else { Write-Host "Nothing to remove: $OutputCsv" }
    if (Get-Command Disconnect-ExchangeOnline -ErrorAction SilentlyContinue) {
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
    }
    Write-Host 'Cleanup complete. No tenant settings were changed by this script.'
    return
}

if (-not $SkipConnect) {
    if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
        throw 'Install the ExchangeOnlineManagement module: Install-Module ExchangeOnlineManagement -Scope CurrentUser'
    }
    Import-Module ExchangeOnlineManagement
    if (-not $AdminUpn) { throw 'Pass -AdminUpn, or connect yourself and use -SkipConnect.' }
    Connect-ExchangeOnline -UserPrincipalName $AdminUpn -ShowBanner:$false
}

Write-Host "Tenant: $TenantUrl"
$cfg = Get-AdminAuditLogConfig
if (-not $cfg.UnifiedAuditLogIngestionEnabled) {
    Write-Warning 'UnifiedAuditLogIngestionEnabled is False. Turn on auditing in the Purview portal, wait, and search again.'
}

$sessionId = "hle-lab11-" + [guid]::NewGuid().ToString('N')
$all = [System.Collections.Generic.List[object]]::new()
$page = 0
do {
    $page++
    $searchParams = @{
        StartDate      = $StartDate
        EndDate        = $EndDate
        RecordType     = $RecordType
        SessionId      = $sessionId
        SessionCommand = 'ReturnLargeSet'
        ResultSize     = 5000
    }
    if ($UserIds) { $searchParams.UserIds = $UserIds }
    Write-Verbose "Search page $page"
    $batch = @(Search-UnifiedAuditLog @searchParams)
    foreach ($r in $batch) { $all.Add($r) }
    # With ReturnLargeSet, an empty page ends the session. ResultCount on each record is the total.
    $total = if ($batch.Count -gt 0 -and $batch[0].PSObject.Properties['ResultCount']) { [int]$batch[0].ResultCount } else { 0 }
} while ($batch.Count -gt 0 -and $all.Count -lt $total)

Write-Host "Records returned for $RecordType between $StartDate and $EndDate : $($all.Count)"

$rows = foreach ($r in $all) {
    $data = $null
    try { $data = $r.AuditData | ConvertFrom-Json } catch { Write-Warning "Could not parse AuditData for record $($r.Identity)" }
    $appIdentity = if ($data) { Get-FirstField $data $FieldPaths.AppIdentity } else { '' }
    $agentName = if ($data) { Get-FirstField $data $FieldPaths.AgentName } else { '' }
    [pscustomobject]@{
        CreationDate = $r.CreationDate
        UserId       = $r.UserIds
        Operation    = $r.Operations
        RecordType   = $r.RecordType
        AppIdentity  = $appIdentity
        AgentId      = if ($data) { Get-FirstField $data $FieldPaths.AgentId } else { '' }
        AgentName    = $agentName
        AppHost      = if ($data) { Get-FirstField $data $FieldPaths.AppHost } else { '' }
        AuditData    = $r.AuditData
    }
}
$rows = @($rows | Where-Object { $AgentNameLike -eq '*' -or $_.AgentName -like $AgentNameLike -or $_.AppIdentity -like $AgentNameLike -or $_.AgentId -like $AgentNameLike })

if ($rows.Count -eq 0) {
    Write-Warning "No records matched '$AgentNameLike'. Try -AgentNameLike '*' to see every Copilot interaction and check which field holds the agent name in your tenant."
}

$dir = Split-Path -Parent $OutputCsv
if ($dir) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
if ($PSCmdlet.ShouldProcess($OutputCsv, "Write $($rows.Count) rows")) {
    $rows | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding utf8
    Write-Host "Wrote $OutputCsv"
}
$rows | Select-Object CreationDate, UserId, AppIdentity, AgentId, AgentName | Format-Table -AutoSize
