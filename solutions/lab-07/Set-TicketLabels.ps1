#Requires -Version 7.0
<#
.SYNOPSIS
    Lab 7 break-it C-07-d: removes the `title` and `url` semantic labels from the hleTickets connector schema,
    or restores them with -Cleanup.

.DESCRIPTION
    Semantic labels can be changed after a schema is registered (limits.md GC-04). This script reads the
    registered schema of the connection, removes the `title` label from property `title` and the `url` label
    from property `url` (or adds them back with -Cleanup), sends the full property list with
    PATCH /external/connections/{id}/schema, and polls the schema operation from the Location header.

    It signs in with the same app registration and certificate as data/connector/ingest-tickets.ps1
    (ExternalConnection.ReadWrite.OwnedBy). Idempotent: if the labels are already in the requested state,
    nothing is sent.

    Only the labels are changed. Items are not re-sent. Record what changes in search results and in agent
    citations, then run again with -Cleanup.

.PARAMETER TenantId
    Tenant ID (GUID) or primary domain.

.PARAMETER ClientId
    Application (client) ID of the HLE-Tickets-Connector app registration.

.PARAMETER CertificateThumbprint
    Thumbprint of the app certificate in the current user's certificate store.

.PARAMETER TenantUrl
    Accepted for consistency with the other course scripts. Not used.

.PARAMETER Prefix
    Course prefix (default HLE). Used for the default connection ID <prefix>Tickets.

.PARAMETER ConnectionId
    Connection ID. Default: <prefix>Tickets, which is hleTickets.

.PARAMETER Cleanup
    Restores the `title` and `url` labels.

.EXAMPLE
    ./Set-TicketLabels.ps1 -TenantId <tid> -ClientId <appId> -CertificateThumbprint <thumb>

.EXAMPLE
    ./Set-TicketLabels.ps1 -TenantId <tid> -ClientId <appId> -CertificateThumbprint <thumb> -Cleanup

.NOTES
    Course: Microsoft 365 Copilot agent building, Lab 7. Module: Microsoft.Graph.Authentication 2.x.
    Schema design: data/connector/schema-design.md section 3.4.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$TenantId,
    [Parameter(Mandatory)][string]$ClientId,
    [Parameter(Mandatory)][string]$CertificateThumbprint,
    [string]$TenantUrl,
    [ValidatePattern('^[A-Za-z][A-Za-z0-9]{1,7}$')]
    [string]$Prefix = 'HLE',
    [ValidatePattern('^[A-Za-z0-9]{3,32}$')]
    [string]$ConnectionId,
    [switch]$Cleanup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $ConnectionId) { $ConnectionId = "$($Prefix.ToLowerInvariant())Tickets" }
$ConnPath = "v1.0/external/connections/$ConnectionId"
$Targets = [ordered]@{ title = 'title'; url = 'url' }   # property name = label name

if (-not (Get-Command Connect-MgGraph -ErrorAction SilentlyContinue)) {
    throw 'Microsoft.Graph.Authentication is required. Run: Install-Module Microsoft.Graph.Authentication -Scope CurrentUser'
}
Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint -NoWelcome
Write-Host "Connected. Connection ID: $ConnectionId"

$connection = Invoke-MgGraphRequest -Method GET -Uri $ConnPath
if ($connection['state'] -ne 'ready') { throw "Connection $ConnectionId is in state '$($connection['state'])'. Run ingest-tickets.ps1 first." }

$schema = Invoke-MgGraphRequest -Method GET -Uri "$ConnPath/schema"
$changed = $false
$props = [System.Collections.Generic.List[object]]::new()
foreach ($p in @($schema['properties'])) {
    $copy = [ordered]@{}
    foreach ($k in $p.Keys) { if ($k -notlike '@odata*') { $copy[$k] = $p[$k] } }
    $name = [string]$copy['name']
    if ($Targets.Contains($name)) {
        $label = $Targets[$name]
        $labels = [System.Collections.Generic.List[string]]::new()
        if ($copy.Contains('labels') -and $copy['labels']) { foreach ($l in @($copy['labels'])) { $labels.Add([string]$l) } }
        if ($Cleanup -and -not $labels.Contains($label)) { $labels.Add($label); $changed = $true }
        if (-not $Cleanup -and $labels.Contains($label)) { [void]$labels.Remove($label); $changed = $true }
        $copy['labels'] = @($labels)
    }
    $props.Add($copy)
}

if (-not $changed) {
    Write-Host ("Labels already {0}. Nothing to do." -f $(if ($Cleanup) { 'present' } else { 'removed' }))
    return
}

Write-Host ("{0} the title and url semantic labels." -f $(if ($Cleanup) { 'Restoring' } else { 'Removing' }))
$h = $null
Invoke-MgGraphRequest -Method PATCH -Uri "$ConnPath/schema" -ContentType 'application/json' `
    -Body (@{ baseType = 'microsoft.graph.externalItem'; properties = $props } | ConvertTo-Json -Depth 20 -Compress) `
    -ResponseHeadersVariable h | Out-Null

$location = $null
if ($h) { foreach ($k in $h.Keys) { if ($k -eq 'Location') { $location = [string](@($h[$k])[0]) } } }
if (-not $location) { Write-Warning 'No Location header returned. Check the schema later with GET .../schema.'; return }

$deadline = (Get-Date).AddMinutes(30)
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 30
    $op = Invoke-MgGraphRequest -Method GET -Uri $location
    Write-Host "  Schema operation status: $($op['status'])"
    if ($op['status'] -eq 'completed') { Write-Host 'Done. Re-test search results and agent citations (Lab 7 break-it C-07-d).'; return }
    if ($op['status'] -eq 'failed') { throw "Schema operation failed: $($op | ConvertTo-Json -Depth 10 -Compress)" }
}
Write-Warning 'Timed out after 30 minutes. The operation may still complete; re-run to check.'
