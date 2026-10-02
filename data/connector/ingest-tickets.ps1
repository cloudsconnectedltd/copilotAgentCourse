#Requires -Version 7.0
<#
.SYNOPSIS
    Creates the Harbourline tickets Copilot connector (Microsoft Graph connectors API), registers its schema
    and pushes 5,000 tickets with per-item ACLs.

.DESCRIPTION
    App-only (certificate) script built on the Microsoft Graph PowerShell SDK. It uses only
    Connect-MgGraph and Invoke-MgGraphRequest from Microsoft.Graph.Authentication, with the REST paths from
    the Microsoft Graph v1.0 reference:
        GET    /external/connections                      (find the connection)
        POST   /external/connections                      (create it)
        PATCH  /external/connections/{id}/schema          (register schema, 202 + Location header)
        GET    /external/connections/{id}/operations/{op} (poll the schema operation)
        GET    /external/connections/{id}/schema          (read the schema, used by -AddRefinableLater)
        PUT    /external/connections/{id}/items/{itemId}  (create or replace an item; sent in JSON batches of 20)
        DELETE /external/connections/{id}                 (-Cleanup)

    Idempotent:
      * the connection is created only if it does not exist;
      * the schema is registered only while the connection is in the 'draft' state (a connection in the
        'ready' state already has a schema);
      * items are written with PUT, which creates or replaces, so re-running re-sends the same items.

    ACL placeholder tokens in the source ({{GROUP_OPS_ONTARIO}}, {{GROUP_OPS_US}}, {{GROUP_HR}},
    {{GROUP_FINANCE}}, {{USER_FIN}}, {{TENANT_ID}}) are replaced with object IDs. By default groups are
    resolved by display name (<Prefix>-Ops-Ontario, <Prefix>-Ops-US, <Prefix>-HR, <Prefix>-Finance), the
    user by UPN prefix (<prefix>-fin@), and {{TENANT_ID}} with the tenant ID. Default resolution needs the
    app permissions Group.Read.All and User.Read.All; pass -GroupMap to avoid them.

    Required application permissions (admin consent): ExternalConnection.ReadWrite.OwnedBy and
    ExternalItem.ReadWrite.OwnedBy. See data/connector/app-registration.md.

.PARAMETER TenantId
    Tenant ID (GUID) or primary domain.

.PARAMETER ClientId
    Application (client) ID of the connector app registration.

.PARAMETER CertificateThumbprint
    Thumbprint of the app certificate in the current user's certificate store.

.PARAMETER Prefix
    Course prefix (default HLE). Used for group names and the default connection ID.

.PARAMETER TenantUrl
    Accepted for consistency with the other course scripts. Not used by this script.

.PARAMETER ConnectionId
    Connection ID, 3 to 32 alphanumeric characters. Default: <prefix>Tickets, which is hleTickets.

.PARAMETER SourceCsv
    Path to tickets.csv (default: tickets.csv next to this script). Ignored if -SqlConnectionString is set.

.PARAMETER SqlConnectionString
    Read tickets from dbo.vTicketIndex in the HarbourlineTickets database instead of the CSV, for example
    "Server=localhost;Database=HarbourlineTickets;Integrated Security=true;TrustServerCertificate=true".

.PARAMETER GroupMap
    Hashtable from placeholder token to object ID, for example
    @{ '{{GROUP_OPS_ONTARIO}}' = '<guid>'; '{{GROUP_OPS_US}}' = '<guid>'; '{{GROUP_HR}}' = '<guid>';
       '{{GROUP_FINANCE}}' = '<guid>'; '{{USER_FIN}}' = '<guid>' }
    Tokens you do not supply are resolved by name.

.PARAMETER MaxItems
    Push only the first N tickets (0 = all). Useful for a quick first test.

.PARAMETER AddRefinableLater
    Lab 7 "break it" step: tries to add a new refinable property (costCentre) to the registered schema.
    This is expected to fail (refinable cannot be added in a schema update, limits.md GC-04).

.PARAMETER Cleanup
    Deletes the connection, which removes its schema and all its items.

.EXAMPLE
    ./ingest-tickets.ps1 -TenantId contoso.onmicrosoft.com -ClientId <appId> -CertificateThumbprint <thumb>

.EXAMPLE
    ./ingest-tickets.ps1 -TenantId <tid> -ClientId <appId> -CertificateThumbprint <thumb> -MaxItems 50

.EXAMPLE
    ./ingest-tickets.ps1 -TenantId <tid> -ClientId <appId> -CertificateThumbprint <thumb> -AddRefinableLater

.EXAMPLE
    ./ingest-tickets.ps1 -TenantId <tid> -ClientId <appId> -CertificateThumbprint <thumb> -Cleanup

.NOTES
    Course: Microsoft 365 Copilot agent building, Lab 7. Schema rationale: data/connector/schema-design.md.
    Module: Microsoft.Graph.Authentication 2.x (Install-Module Microsoft.Graph.Authentication).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$TenantId,
    [Parameter(Mandatory)][string]$ClientId,
    [Parameter(Mandatory)][string]$CertificateThumbprint,

    [ValidatePattern('^[A-Za-z][A-Za-z0-9]{1,7}$')]
    [string]$Prefix = 'HLE',

    [string]$TenantUrl,

    [ValidatePattern('^[A-Za-z0-9]{3,32}$')]
    [string]$ConnectionId,

    [string]$SourceCsv = (Join-Path $PSScriptRoot 'tickets.csv'),

    [string]$SqlConnectionString,

    [hashtable]$GroupMap = @{},

    [ValidateRange(0, 100000)]
    [int]$MaxItems = 0,

    [switch]$AddRefinableLater,

    [switch]$Cleanup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $ConnectionId) { $ConnectionId = "$($Prefix.ToLowerInvariant())Tickets" }
$ConnPath = "v1.0/external/connections/$ConnectionId"

# ------------------------------------------------------------------ schema (see schema-design.md section 2)
function New-Prop {
    param([string]$Name, [string]$Type, [switch]$S, [switch]$Q, [switch]$R, [switch]$F, [switch]$X,
        [string[]]$Labels = @(), [string[]]$Aliases = @())
    $p = [ordered]@{ name = $Name; type = $Type }
    if ($S) { $p.isSearchable = $true }
    if ($Q) { $p.isQueryable = $true }
    if ($R) { $p.isRetrievable = $true }
    if ($F) { $p.isRefinable = $true }
    if ($X) { $p.isExactMatchRequired = $true }
    if ($Labels.Count) { $p.labels = $Labels }
    if ($Aliases.Count) { $p.aliases = $Aliases }
    return $p
}

$SchemaProperties = @(
    (New-Prop ticketId        String -Q -R -X -Aliases id, ticketNumber)
    (New-Prop title           String -S -Q -R -Labels title -Aliases subject)
    (New-Prop status          String -Q -R -F -Aliases state)
    (New-Prop priority        String -Q -R -F -Aliases urgency)
    (New-Prop category        String -Q -R -F -Aliases ticketType)
    (New-Prop region          String -Q -R -F -Aliases area)
    (New-Prop siteName        String -S -Q -R -Aliases site, depot)
    (New-Prop assetTag        String -Q -R -X -Aliases asset, assetId)
    (New-Prop assetType       String -Q -R -F -Aliases equipmentType)
    (New-Prop createdBy       String -S -Q -R -Labels createdBy -Aliases reporter, author)
    (New-Prop assignedTo      String -S -Q -R -Aliases queue, owner)
    (New-Prop tags            StringCollection -Q -R -F -X -Aliases labels)
    (New-Prop createdDateTime DateTime -Q -R -F -Labels createdDateTime -Aliases opened, created)
    (New-Prop lastModified    DateTime -Q -R -F -Labels lastModifiedDateTime -Aliases modified, updated)
    (New-Prop url             String -R -Labels url)
    (New-Prop iconUrl         String -R -Labels iconUrl)
)

# ------------------------------------------------------------------ Graph helpers
function Get-HttpStatus($ErrorRecord) {
    $code = $null
    try { $code = [int]$ErrorRecord.Exception.Response.StatusCode } catch { $code = $null }
    if (-not $code -and $ErrorRecord.Exception.Message -match '\b(4\d\d|5\d\d)\b') { $code = [int]$Matches[1] }
    return $code
}

function Invoke-Graph {
    <# Invoke-MgGraphRequest with JSON body handling and retry on 429/503/504. #>
    param(
        [Parameter(Mandatory)][string]$Method,
        [Parameter(Mandatory)][string]$Uri,
        [object]$Body,
        [string]$HeadersVariableName
    )
    for ($attempt = 1; $attempt -le 6; $attempt++) {
        $params = @{ Method = $Method; Uri = $Uri }
        if ($null -ne $Body) {
            $params.Body = ($Body | ConvertTo-Json -Depth 20 -Compress)
            $params.ContentType = 'application/json'
        }
        $captureHeaders = $HeadersVariableName -and (Get-Command Invoke-MgGraphRequest).Parameters.ContainsKey('ResponseHeadersVariable')
        if ($captureHeaders) { $params.ResponseHeadersVariable = 'graphResponseHeaders' }
        try {
            $result = Invoke-MgGraphRequest @params
            if ($captureHeaders) {
                $script:LastResponseHeaders = Get-Variable -Name graphResponseHeaders -ValueOnly -ErrorAction SilentlyContinue
            }
            return $result
        }
        catch {
            $code = Get-HttpStatus $_
            if ($code -in 429, 503, 504 -and $attempt -lt 6) {
                $wait = [Math]::Min(60, 5 * [Math]::Pow(2, $attempt - 1))
                Write-Verbose "Graph returned $code, retrying in $wait s"
                Start-Sleep -Seconds $wait
                continue
            }
            throw
        }
    }
}

function Get-Connection {
    $list = Invoke-Graph GET 'v1.0/external/connections?$select=id,name,state'
    foreach ($c in @($list['value'])) {
        if ($c['id'] -eq $ConnectionId) { return $c }
    }
    return $null
}

function Wait-SchemaOperation([string]$OperationUrl) {
    $deadline = (Get-Date).AddMinutes(30)
    while ((Get-Date) -lt $deadline) {
        if ($OperationUrl) {
            $op = Invoke-Graph GET $OperationUrl
            Write-Host "  Schema operation status: $($op['status'])"
            if ($op['status'] -eq 'completed') { return $true }
            if ($op['status'] -eq 'failed') {
                $msg = if ($op.ContainsKey('error') -and $op['error']) { $op['error']['message'] } else { 'no detail' }
                Write-Warning "Schema operation failed: $msg"
                return $false
            }
        }
        else {
            $c = Get-Connection
            Write-Host "  Connection state: $($c['state'])"
            if ($c['state'] -eq 'ready') { return $true }
        }
        Start-Sleep -Seconds 30
    }
    throw 'Timed out after 30 minutes waiting for the schema operation. Re-run the script later; it resumes.'
}

function Get-LocationHeader {
    $h = Get-Variable -Scope Script -Name LastResponseHeaders -ValueOnly -ErrorAction SilentlyContinue
    if (-not $h) { return $null }
    foreach ($k in $h.Keys) {
        if ($k -eq 'Location') { return [string](@($h[$k])[0]) }
    }
    return $null
}

# ------------------------------------------------------------------ principals
function Resolve-PrincipalMap {
    $map = @{}
    foreach ($k in $GroupMap.Keys) { $map[$k] = [string]$GroupMap[$k] }
    $map['{{TENANT_ID}}'] = (Get-MgContext).TenantId
    $groups = @{
        '{{GROUP_OPS_ONTARIO}}' = "$Prefix-Ops-Ontario"
        '{{GROUP_OPS_US}}'      = "$Prefix-Ops-US"
        '{{GROUP_HR}}'          = "$Prefix-HR"
        '{{GROUP_FINANCE}}'     = "$Prefix-Finance"
    }
    foreach ($token in $groups.Keys) {
        if ($map.ContainsKey($token)) { continue }
        $name = $groups[$token]
        $r = Invoke-Graph GET ("v1.0/groups?`$filter=displayName eq '{0}'&`$select=id,displayName" -f $name)
        $found = @($r['value'])
        if ($found.Count -ne 1) {
            throw "Could not resolve group '$name' ($($found.Count) matches). Run setup/01-provision-users.ps1 or pass -GroupMap @{ '$token' = '<object id>' }."
        }
        $map[$token] = $found[0]['id']
    }
    if (-not $map.ContainsKey('{{USER_FIN}}')) {
        $upnPrefix = "$($Prefix.ToLowerInvariant())-fin@"
        $r = Invoke-Graph GET ("v1.0/users?`$filter=startswith(userPrincipalName,'{0}')&`$select=id,userPrincipalName" -f $upnPrefix)
        $found = @($r['value'])
        if ($found.Count -ne 1) {
            throw "Could not resolve the finance persona ($upnPrefix...). Pass -GroupMap @{ '{{USER_FIN}}' = '<object id>' }."
        }
        $map['{{USER_FIN}}'] = $found[0]['id']
    }
    return $map
}

# ------------------------------------------------------------------ source rows
function Get-SourceRows {
    if ($SqlConnectionString) {
        Write-Host 'Reading tickets from SQL view dbo.vTicketIndex'
        $conn = [System.Data.SqlClient.SqlConnection]::new($SqlConnectionString)
        try {
            $conn.Open()
            $cmd = $conn.CreateCommand()
            $cmd.CommandText = 'SELECT * FROM dbo.vTicketIndex ORDER BY TicketId'
            $reader = $cmd.ExecuteReader()
            $rows = [System.Collections.Generic.List[object]]::new()
            while ($reader.Read()) {
                $o = [ordered]@{}
                for ($i = 0; $i -lt $reader.FieldCount; $i++) {
                    $v = $reader.GetValue($i)
                    $o[$reader.GetName($i)] = if ($v -is [System.DBNull]) { '' } else { [string]$v }
                }
                $rows.Add([pscustomobject]$o)
            }
            $reader.Close()
            return $rows
        }
        finally { $conn.Dispose() }
    }
    if (-not (Test-Path $SourceCsv)) { throw "Source CSV not found: $SourceCsv" }
    Write-Host "Reading tickets from $SourceCsv"
    return Import-Csv -Path $SourceCsv
}

function Add-StringProp([System.Collections.IDictionary]$Props, [string]$Name, [string]$Value) {
    if ([string]::IsNullOrEmpty($Value)) { return }
    if ($Value -match '[^\x00-\x7F]') { $Props["$Name@odata.type"] = 'String' }
    $Props[$Name] = $Value
}

function ConvertTo-ExternalItem($Row, [hashtable]$PrincipalMap) {
    $acl = @(foreach ($e in ($Row.AclJson | ConvertFrom-Json)) {
            $value = [string]$e.value
            if ($value -match '^\{\{[A-Z_]+\}\}$') {
                if (-not $PrincipalMap.ContainsKey($value)) { throw "No principal for token $value (ticket $($Row.TicketId))" }
                $value = $PrincipalMap[$value]
            }
            [ordered]@{ type = [string]$e.type; value = $value; accessType = [string]$e.accessType }
        })
    $props = [ordered]@{}
    Add-StringProp $props 'ticketId' ([string]$Row.TicketId)
    Add-StringProp $props 'title' $Row.Title
    Add-StringProp $props 'status' $Row.Status
    Add-StringProp $props 'priority' $Row.Priority
    Add-StringProp $props 'category' $Row.Category
    Add-StringProp $props 'region' $Row.Region
    Add-StringProp $props 'siteName' $Row.SiteName
    Add-StringProp $props 'assetTag' $Row.AssetTag
    Add-StringProp $props 'assetType' $Row.AssetType
    Add-StringProp $props 'createdBy' $Row.CreatedBy
    Add-StringProp $props 'assignedTo' $Row.AssignedTo
    $tags = @(([string]$Row.Tags).Split(';', [System.StringSplitOptions]::RemoveEmptyEntries))
    if ($tags.Count -gt 0) {
        $props['tags@odata.type'] = 'Collection(String)'
        $props['tags'] = $tags
    }
    $props['createdDateTime'] = $Row.CreatedDateTime
    $props['lastModified'] = $Row.LastModified
    Add-StringProp $props 'url' $Row.Url
    Add-StringProp $props 'iconUrl' $Row.IconUrl

    $text = "$($Row.Title)`n`n$($Row.Description)`n`nSite: $($Row.SiteName) ($($Row.Region))"
    if ($Row.AssetTag) { $text += "`nAsset: $($Row.AssetTag) ($($Row.AssetType))" }
    return [ordered]@{
        id   = "HLT$($Row.TicketId)"
        body = [ordered]@{
            acl        = $acl
            properties = $props
            content    = [ordered]@{ type = 'text'; value = $text }
        }
    }
}

function Send-ItemBatch([System.Collections.IList]$Items) {
    <# Sends up to 20 PUT requests in one JSON batch; retries items that return 429 or 5xx. #>
    $pending = @($Items)
    for ($attempt = 1; $attempt -le 6 -and $pending.Count -gt 0; $attempt++) {
        $requests = @(for ($i = 0; $i -lt $pending.Count; $i++) {
                [ordered]@{
                    id      = [string]($i + 1)
                    method  = 'PUT'
                    url     = "/external/connections/$ConnectionId/items/$($pending[$i].id)"
                    headers = @{ 'Content-Type' = 'application/json' }
                    body    = $pending[$i].body
                }
            })
        $resp = Invoke-Graph POST 'v1.0/$batch' -Body @{ requests = $requests }
        $retry = [System.Collections.Generic.List[object]]::new()
        $waitSeconds = 0
        foreach ($r in @($resp['responses'])) {
            $status = [int]$r['status']
            $item = $pending[[int]$r['id'] - 1]
            if ($status -ge 200 -and $status -lt 300) { continue }
            if ($status -eq 429 -or $status -ge 500) {
                $retry.Add($item)
                $ra = $null
                if ($r.ContainsKey('headers') -and $r['headers'] -and $r['headers'].ContainsKey('Retry-After')) { $ra = [int]$r['headers']['Retry-After'] }
                $waitSeconds = [Math]::Max($waitSeconds, $(if ($ra) { $ra } else { 5 * $attempt }))
                continue
            }
            $msg = if ($r.ContainsKey('body') -and $r['body'] -and $r['body'].ContainsKey('error')) { $r['body']['error']['message'] } else { '' }
            Write-Warning "Item $($item.id) failed ($status): $msg"
            $script:FailedItems++
        }
        $pending = @($retry)
        if ($pending.Count -gt 0) { Start-Sleep -Seconds $waitSeconds }
    }
    if ($pending.Count -gt 0) {
        Write-Warning "$($pending.Count) items still throttled after retries: $($pending.id -join ', ')"
        $script:FailedItems += $pending.Count
    }
}

# ------------------------------------------------------------------ main
if (-not (Get-Command Connect-MgGraph -ErrorAction SilentlyContinue)) {
    throw 'Microsoft.Graph.Authentication is required. Run: Install-Module Microsoft.Graph.Authentication -Scope CurrentUser'
}
Connect-MgGraph -ClientId $ClientId -TenantId $TenantId -CertificateThumbprint $CertificateThumbprint -NoWelcome
Write-Host "Connected to tenant $((Get-MgContext).TenantId) as app $ClientId. Connection ID: $ConnectionId"

$connection = Get-Connection

if ($Cleanup) {
    if ($connection) {
        Invoke-Graph DELETE $ConnPath | Out-Null
        Write-Host "Deleted connection $ConnectionId (schema and items are removed with it; deletion completes in the background)."
    }
    else {
        Write-Host "Connection $ConnectionId not found. Nothing to delete."
    }
    return
}

if (-not $connection) {
    Write-Host "Creating connection $ConnectionId"
    Invoke-Graph POST 'v1.0/external/connections' -Body ([ordered]@{
            id          = $ConnectionId
            name        = "$Prefix Tickets"
            description = 'Harbourline Energy Co. service tickets: field operations, outages, asset maintenance, safety, IT, facilities, HR and finance requests. Each ticket has a site (depot or station), region (Ontario, New York, Ohio) and optional asset ID such as TX-ON-10423.'
        }) | Out-Null
    $connection = Get-Connection
}
Write-Host "Connection state: $($connection['state'])"

if ($AddRefinableLater) {
    if ($connection['state'] -ne 'ready') { throw 'The schema is not registered yet. Run the script once without -AddRefinableLater first.' }
    $current = Invoke-Graph GET "$ConnPath/schema"
    $schemaObj = if ($current.ContainsKey('properties')) { $current } else { $current['value'] }
    $props = [System.Collections.Generic.List[object]]::new()
    foreach ($p in @($schemaObj['properties'])) {
        $copy = [ordered]@{}
        foreach ($k in $p.Keys) { if ($k -notlike '@odata*') { $copy[$k] = $p[$k] } }
        $props.Add($copy)
    }
    if ($props.name -contains 'costCentre') { Write-Host 'costCentre already exists in the schema.'; return }
    $props.Add((New-Prop costCentre String -Q -R -F))
    Write-Host 'Break-it step: adding refinable property costCentre to a registered schema (expected to fail, GC-04).'
    try {
        Invoke-Graph PATCH "$ConnPath/schema" -Body @{ baseType = 'microsoft.graph.externalItem'; properties = $props } -HeadersVariableName 'h' | Out-Null
        $ok = Wait-SchemaOperation (Get-LocationHeader)
        if ($ok) {
            Write-Warning 'The schema update succeeded. The documented behaviour (GC-04) says refinable cannot be added in an update; record this in the lab notes and re-check the current docs.'
        }
        else {
            Write-Host 'As expected, the schema operation failed. Fix: add costCentre without isRefinable, or delete the connection and register a new schema.'
        }
    }
    catch {
        Write-Host "As expected, the schema update was rejected: $($_.Exception.Message)"
        Write-Host 'Fix: add costCentre without isRefinable, or delete the connection (-Cleanup) and register a new schema.'
    }
    return
}

switch ($connection['state']) {
    'draft' {
        Write-Host "Registering schema ($($SchemaProperties.Count) properties). This usually takes 5 to 15 minutes."
        try {
            Invoke-Graph PATCH "$ConnPath/schema" -Body @{ baseType = 'microsoft.graph.externalItem'; properties = $SchemaProperties } -HeadersVariableName 'h' | Out-Null
            $location = Get-LocationHeader
        }
        catch {
            Write-Warning "Schema PATCH returned an error ($($_.Exception.Message)). If a registration is already running, the script waits for it."
            $location = $null
        }
        if (-not (Wait-SchemaOperation $location)) { throw 'Schema registration failed. See the warning above, fix the schema, run -Cleanup, then run again.' }
        $connection = Get-Connection
        if ($connection['state'] -ne 'ready') {
            Write-Host 'Waiting for the connection to reach the ready state'
            [void](Wait-SchemaOperation $null)
        }
    }
    'ready' { Write-Host 'Schema already registered. Skipping registration.' }
    default { throw "Connection is in state '$($connection['state'])'. Items cannot be ingested in this state." }
}

$principalMap = Resolve-PrincipalMap
Write-Host 'Resolved ACL principals:'
$principalMap.GetEnumerator() | Sort-Object Name | ForEach-Object { Write-Host ("  {0} = {1}" -f $_.Name, $_.Value) }

$rows = @(Get-SourceRows)
if ($MaxItems -gt 0) { $rows = @($rows | Select-Object -First $MaxItems) }
$total = $rows.Count
$script:FailedItems = 0
$batch = [System.Collections.Generic.List[object]]::new()
$done = 0
foreach ($row in $rows) {
    $batch.Add((ConvertTo-ExternalItem $row $principalMap))
    if ($batch.Count -eq 20) {
        Send-ItemBatch $batch
        $done += $batch.Count
        $batch.Clear()
        Write-Progress -Activity "Ingesting tickets into $ConnectionId" -Status "$done of $total" -PercentComplete (100 * $done / $total)
    }
}
if ($batch.Count -gt 0) { Send-ItemBatch $batch; $done += $batch.Count }
Write-Progress -Activity "Ingesting tickets into $ConnectionId" -Completed
Write-Host ("Ingestion finished: {0} items sent, {1} failed." -f $done, $script:FailedItems)
Write-Host "Next: in the Microsoft 365 admin center, check Copilot > Connectors for '$ConnectionId', then add it to your agents (Lab 7)."
