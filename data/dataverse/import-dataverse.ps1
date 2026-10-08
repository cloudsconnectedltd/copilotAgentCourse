#Requires -Version 7.0
<#
.SYNOPSIS
    Creates the Harbourline Dataverse tables (Asset, Crew, Work Order) and loads the seed CSV files.

.DESCRIPTION
    Uses the Dataverse Web API (v9.2) directly from PowerShell 7. Steps:
      1. Publisher and unmanaged solution (created only if missing).
      2. Tables <prefix>_Asset, <prefix>_Crew, <prefix>_WorkOrder with their primary name columns.
      3. Columns, including local choice columns such as <prefix>_Priority (Emergency, High, Routine, Deferred).
      4. One-to-many relationships: WorkOrder N:1 Asset and WorkOrder N:1 Crew (lookups <prefix>_Asset, <prefix>_Crew).
      5. PublishXml for the three tables.
      6. Rows from Crews.csv, Assets.csv and WorkOrders.csv, sent as $batch upserts.

    Idempotent: every metadata item is looked up before it is created, and every row is written with
    PATCH <entityset>(<guid>) where the GUID is derived from the business key (for example TX-ON-10423).
    PATCH on a missing row creates it with that GUID, so re-running the script updates rows in place and
    never duplicates them. See data/dataverse/schema.md section 2.1.

    Authentication (one approach, as documented for Dataverse Web API with PowerShell on Microsoft Learn,
    "Quick start Web API with PowerShell"): the Az.Accounts module. The script calls Connect-AzAccount when no
    Azure session exists, then Get-AzAccessToken -ResourceUrl <EnvironmentUrl> -AsSecureString. You need
    Az.Accounts installed (Install-Module Az.Accounts) and a user with System Customizer or System
    Administrator in the environment. No Azure subscription is required; use Connect-AzAccount -TenantId
    <tenant> first if you have no subscriptions.

    Alternatively (default when the az command is installed) the Azure CLI: run
    az login --tenant <tenant> --allow-no-subscriptions, and the script calls
    az account get-access-token --resource <EnvironmentUrl>. See -AuthMode.

    The token is refreshed automatically every 40 minutes during long imports.

.PARAMETER EnvironmentUrl
    Dataverse environment URL, for example https://harbourline-dev.crm.dynamics.com

.PARAMETER Prefix
    Course prefix (default HLE). Lowercased, it becomes the Dataverse customization prefix (hle_...).

.PARAMETER TenantUrl
    Accepted for consistency with the other course scripts. Not used for Dataverse calls.

.PARAMETER DataPath
    Folder containing Assets.csv, Crews.csv and WorkOrders.csv. Defaults to the script folder.

.PARAMETER BatchSize
    Requests per $batch call (1 to 1000, default 200).

.PARAMETER SkipData
    Create or verify metadata only. Do not load rows.

.PARAMETER AuthMode
    How to get the Dataverse token. Auto (default) uses the Azure CLI when the az command is installed,
    otherwise Az.Accounts. AzureCli: run 'az login --tenant <tenant> --allow-no-subscriptions' first; this
    path avoids the macOS sign-in broker error "Interactive requests with mac broker enabled must be executed
    on the main thread". AzPowerShell: Connect-AzAccount and Get-AzAccessToken.

.PARAMETER Cleanup
    Delete all rows, then the three tables (work orders first), then the solution and, if this script
    created it, the publisher.

.EXAMPLE
    ./import-dataverse.ps1 -EnvironmentUrl https://harbourline-dev.crm.dynamics.com

.EXAMPLE
    ./import-dataverse.ps1 -EnvironmentUrl https://harbourline-dev.crm.dynamics.com -Prefix HLE -Cleanup

.NOTES
    Course: Microsoft 365 Copilot agent building, Labs 4, 5, 10, 11.
    Choice values and column names: data/dataverse/schema.md.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^https://')]
    [string]$EnvironmentUrl,

    [ValidatePattern('^[A-Za-z][A-Za-z0-9]{1,7}$')]
    [string]$Prefix = 'HLE',

    [string]$TenantUrl,

    [string]$DataPath = $PSScriptRoot,

    [ValidateRange(1, 1000)]
    [int]$BatchSize = 200,

    [switch]$SkipData,

    [ValidateSet('Auto', 'AzureCli', 'AzPowerShell')]
    [string]$AuthMode = 'Auto',

    [switch]$Cleanup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ------------------------------------------------------------------ settings
$EnvironmentUrl = $EnvironmentUrl.TrimEnd('/') + '/'
$ApiBase = $EnvironmentUrl + 'api/data/v9.2/'
$ApiPath = '/api/data/v9.2/'
$p = $Prefix.ToLowerInvariant()
$PublisherUniqueName = "${p}harbourline"
$PublisherOptionPrefix = 71480
$SolutionUniqueName = "$($Prefix.ToUpperInvariant())HarbourlineOps"
$Lcid = 1033

$script:Token = $null
$script:TokenAcquired = [datetime]::MinValue

# ------------------------------------------------------------------ auth and HTTP helpers
function Get-DvToken {
    if ($script:Token -and ((Get-Date) - $script:TokenAcquired).TotalMinutes -lt 40) {
        return $script:Token
    }
    $useCli = ($AuthMode -eq 'AzureCli') -or ($AuthMode -eq 'Auto' -and (Get-Command az -ErrorAction SilentlyContinue))
    if ($useCli) {
        if (-not (Get-Command az -ErrorAction SilentlyContinue)) { throw 'Azure CLI (az) not found. Install it, or use -AuthMode AzPowerShell.' }
        $cliToken = & az account get-access-token --resource $EnvironmentUrl.TrimEnd('/') --query accessToken --output tsv 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $cliToken) {
            throw 'Azure CLI could not get a Dataverse token. Run: az login --tenant <your tenant ID or domain> --allow-no-subscriptions, then re-run this script.'
        }
        $script:Token = ([string]$cliToken).Trim()
        $script:TokenAcquired = Get-Date
        return $script:Token
    }
    if (-not (Get-Command Get-AzAccessToken -ErrorAction SilentlyContinue)) {
        throw 'Az.Accounts is required for -AuthMode AzPowerShell. Run: Install-Module Az.Accounts -Scope CurrentUser'
    }
    if ($null -eq (Get-AzTenant -ErrorAction SilentlyContinue)) {
        Connect-AzAccount | Out-Null
    }
    $secure = (Get-AzAccessToken -ResourceUrl $EnvironmentUrl -AsSecureString).Token
    $script:Token = ConvertFrom-SecureString -SecureString $secure -AsPlainText
    $script:TokenAcquired = Get-Date
    return $script:Token
}

function Get-DvHeaders {
    param([hashtable]$Extra)
    $h = @{
        'Authorization'    = 'Bearer ' + (Get-DvToken)
        'Accept'           = 'application/json'
        'OData-MaxVersion' = '4.0'
        'OData-Version'    = '4.0'
    }
    if ($Extra) { foreach ($k in $Extra.Keys) { $h[$k] = $Extra[$k] } }
    return $h
}

function Invoke-Dv {
    <#
      Sends one Web API request. Returns a PSCustomObject with StatusCode, Json (parsed body or $null) and
      Headers. Retries 429 and 503 using Retry-After. Throws on other errors unless -AllowNotFound and 404.
    #>
    param(
        [Parameter(Mandatory)][ValidateSet('GET', 'POST', 'PATCH', 'PUT', 'DELETE')][string]$Method,
        [Parameter(Mandatory)][string]$Path,
        [object]$Body,
        [hashtable]$Headers,
        [switch]$AllowNotFound,
        [switch]$InSolution
    )
    $uri = if ($Path -match '^https://') { $Path } else { $ApiBase + $Path }
    $extra = @{}
    if ($Headers) { foreach ($k in $Headers.Keys) { $extra[$k] = $Headers[$k] } }
    if ($InSolution) { $extra['MSCRM.SolutionUniqueName'] = $SolutionUniqueName }
    for ($attempt = 1; $attempt -le 6; $attempt++) {
        $params = @{
            Method             = $Method
            Uri                = $uri
            Headers            = (Get-DvHeaders -Extra $extra)
            SkipHttpErrorCheck = $true
        }
        if ($null -ne $Body) {
            $params.Body = [System.Text.Encoding]::UTF8.GetBytes(($Body | ConvertTo-Json -Depth 30 -Compress))
            $params.ContentType = 'application/json; charset=utf-8'
        }
        $resp = Invoke-WebRequest @params
        $code = [int]$resp.StatusCode
        if ($code -eq 429 -or $code -eq 503) {
            $wait = 5 * $attempt
            $ra = $resp.Headers['Retry-After']
            if ($ra) { $wait = [int]([string]($ra | Select-Object -First 1)) }
            Write-Verbose "Throttled ($code). Waiting $wait s."
            Start-Sleep -Seconds $wait
            continue
        }
        $json = $null
        if ($resp.Content -and $resp.Content.Length -gt 0) {
            $text = if ($resp.Content -is [byte[]]) { [System.Text.Encoding]::UTF8.GetString($resp.Content) } else { [string]$resp.Content }
            if ($text.TrimStart().StartsWith('{')) { $json = $text | ConvertFrom-Json -Depth 50 }
        }
        if ($code -eq 404 -and $AllowNotFound) {
            return [pscustomobject]@{ StatusCode = 404; Json = $json; Headers = $resp.Headers }
        }
        if ($code -ge 400) {
            $msg = if ($json -and $json.PSObject.Properties['error']) { $json.error.message } else { $resp.Content }
            throw "Dataverse $Method $Path failed ($code): $msg"
        }
        return [pscustomobject]@{ StatusCode = $code; Json = $json; Headers = $resp.Headers }
    }
    throw "Dataverse $Method $Path still throttled after retries."
}

function Invoke-DvBatch {
    <#
      Sends up to 1,000 requests in one $batch (no change set) with Prefer: odata.continue-on-error.
      Each request: @{ Method = 'PATCH'; Url = 'hle_assets(<guid>)'; Body = <hashtable or $null> }
      Returns the number of failed requests and writes their messages as warnings.
    #>
    param([Parameter(Mandatory)][System.Collections.IEnumerable]$Requests)
    $boundary = 'batch_' + [guid]::NewGuid().ToString()
    $sb = [System.Text.StringBuilder]::new()
    foreach ($r in $Requests) {
        [void]$sb.Append("--$boundary`r`n")
        [void]$sb.Append("Content-Type: application/http`r`n")
        [void]$sb.Append("Content-Transfer-Encoding: binary`r`n`r`n")
        [void]$sb.Append("$($r.Method) $ApiPath$($r.Url) HTTP/1.1`r`n")
        if ($null -ne $r.Body) {
            [void]$sb.Append("Content-Type: application/json; type=entry`r`n`r`n")
            [void]$sb.Append(($r.Body | ConvertTo-Json -Depth 10 -Compress))
            [void]$sb.Append("`r`n")
        }
        else {
            [void]$sb.Append("`r`n")
        }
    }
    [void]$sb.Append("--$boundary--`r`n")
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($sb.ToString())
    for ($attempt = 1; $attempt -le 6; $attempt++) {
        $resp = Invoke-WebRequest -Method POST -Uri ($ApiBase + '$batch') -SkipHttpErrorCheck `
            -Headers (Get-DvHeaders -Extra @{ 'Prefer' = 'odata.continue-on-error'; 'If-None-Match' = 'null' }) `
            -ContentType "multipart/mixed; boundary=`"$boundary`"" -Body $bytes
        $code = [int]$resp.StatusCode
        if ($code -eq 429 -or $code -eq 503) {
            $wait = 5 * $attempt
            $ra = $resp.Headers['Retry-After']
            if ($ra) { $wait = [int]([string]($ra | Select-Object -First 1)) }
            Write-Verbose "Batch throttled ($code). Waiting $wait s."
            Start-Sleep -Seconds $wait
            continue
        }
        if ($code -ge 400) { throw "Batch request failed ($code): $($resp.Content)" }
        $text = if ($resp.Content -is [byte[]]) { [System.Text.Encoding]::UTF8.GetString($resp.Content) } else { [string]$resp.Content }
        $failed = 0
        foreach ($m in [regex]::Matches($text, 'HTTP/1\.1 (\d{3})')) {
            if ([int]$m.Groups[1].Value -ge 400) { $failed++ }
        }
        if ($failed -gt 0) {
            foreach ($e in ([regex]::Matches($text, '"message":"([^"]+)"') | Select-Object -First 5)) {
                Write-Warning "Batch item error: $($e.Groups[1].Value)"
            }
        }
        return $failed
    }
    throw 'Batch still throttled after retries.'
}

# ------------------------------------------------------------------ metadata payload helpers
function New-Label([string]$Text) {
    [ordered]@{
        '@odata.type'   = 'Microsoft.Dynamics.CRM.Label'
        LocalizedLabels = @(
            [ordered]@{ '@odata.type' = 'Microsoft.Dynamics.CRM.LocalizedLabel'; Label = $Text; LanguageCode = $Lcid }
        )
    }
}

function New-RequiredLevel([string]$Value = 'None') {
    [ordered]@{ Value = $Value; CanBeChanged = $true; ManagedPropertyLogicalName = 'canmodifyrequirementlevelsettings' }
}

function New-AttrBase([string]$ODataType, [string]$AttributeType, [string]$TypeName, [string]$SchemaName, [string]$Display, [string]$Description) {
    [ordered]@{
        '@odata.type'     = "Microsoft.Dynamics.CRM.$ODataType"
        AttributeType     = $AttributeType
        AttributeTypeName = @{ Value = $TypeName }
        SchemaName        = $SchemaName
        DisplayName       = (New-Label $Display)
        Description       = (New-Label $Description)
        RequiredLevel     = (New-RequiredLevel)
    }
}

function New-StringAttr([string]$SchemaName, [string]$Display, [int]$MaxLength, [string]$Description, [switch]$Primary) {
    $a = New-AttrBase 'StringAttributeMetadata' 'String' 'StringType' $SchemaName $Display $Description
    $a.FormatName = @{ Value = 'Text' }
    $a.MaxLength = $MaxLength
    if ($Primary) { $a.IsPrimaryName = $true }
    return $a
}

function New-MemoAttr([string]$SchemaName, [string]$Display, [int]$MaxLength, [string]$Description) {
    $a = New-AttrBase 'MemoAttributeMetadata' 'Memo' 'MemoType' $SchemaName $Display $Description
    $a.Format = 'TextArea'
    $a.ImeMode = 'Disabled'
    $a.MaxLength = $MaxLength
    return $a
}

function New-IntAttr([string]$SchemaName, [string]$Display, [int]$Min, [int]$Max, [string]$Description) {
    $a = New-AttrBase 'IntegerAttributeMetadata' 'Integer' 'IntegerType' $SchemaName $Display $Description
    $a.Format = 'None'
    $a.MinValue = $Min
    $a.MaxValue = $Max
    return $a
}

function New-DecimalAttr([string]$SchemaName, [string]$Display, [double]$Max, [int]$Precision, [string]$Description) {
    $a = New-AttrBase 'DecimalAttributeMetadata' 'Decimal' 'DecimalType' $SchemaName $Display $Description
    $a.MinValue = 0.0
    $a.MaxValue = $Max
    $a.Precision = $Precision
    return $a
}

function New-DateOnlyAttr([string]$SchemaName, [string]$Display, [string]$Description) {
    $a = New-AttrBase 'DateTimeAttributeMetadata' 'DateTime' 'DateTimeType' $SchemaName $Display $Description
    $a.Format = 'DateOnly'
    $a.ImeMode = 'Disabled'
    $a.DateTimeBehavior = @{ Value = 'DateOnly' }
    return $a
}

function New-ChoiceAttr([string]$SchemaName, [string]$Display, [System.Collections.IDictionary]$Options, [string]$Description) {
    $a = New-AttrBase 'PicklistAttributeMetadata' 'Picklist' 'PicklistType' $SchemaName $Display $Description
    $a.SourceTypeMask = 0
    $a.OptionSet = [ordered]@{
        '@odata.type' = 'Microsoft.Dynamics.CRM.OptionSetMetadata'
        IsGlobal      = $false
        OptionSetType = 'Picklist'
        Options       = @(foreach ($k in $Options.Keys) { [ordered]@{ Value = [int]$Options[$k]; Label = (New-Label $k) } })
    }
    return $a
}

# ------------------------------------------------------------------ schema definition (matches schema.md)
$Choices = @{
    Priority          = [ordered]@{ 'Emergency' = 714800000; 'High' = 714800001; 'Routine' = 714800002; 'Deferred' = 714800003 }
    Status            = [ordered]@{ 'New' = 714800100; 'Scheduled' = 714800101; 'In Progress' = 714800102; 'On Hold' = 714800103; 'Completed' = 714800104; 'Cancelled' = 714800105 }
    AssetType         = [ordered]@{ 'Pole' = 714800200; 'Transformer' = 714800201; 'Switch' = 714800202; 'Breaker' = 714800203; 'Recloser' = 714800204; 'Voltage Regulator' = 714800205 }
    Region            = [ordered]@{ 'Ontario' = 714800300; 'New York' = 714800301; 'Ohio' = 714800302 }
    OperationalStatus = [ordered]@{ 'In Service' = 714800400; 'Out of Service' = 714800401; 'Retired' = 714800402 }
    WorkType          = [ordered]@{ 'Inspection' = 714800500; 'Preventive Maintenance' = 714800501; 'Corrective Repair' = 714800502; 'Replacement' = 714800503; 'Emergency Restoration' = 714800504; 'Vegetation Clearance' = 714800505 }
}

$Tables = [ordered]@{
    Asset     = @{
        Schema      = "${p}_Asset"; Display = 'Asset'; Plural = 'Assets'
        Description = 'Harbourline network assets: poles, transformers, switches, breakers, reclosers and regulators.'
        Primary     = (New-StringAttr "${p}_AssetNumber" 'Asset Number' 100 'Asset ID such as TX-ON-10423. TX = transformer, POLE, SW = switch, BRK = breaker, RCL = recloser, REG = regulator.' -Primary)
        Columns     = @(
            (New-ChoiceAttr "${p}_AssetType" 'Asset Type' $Choices.AssetType 'Type of equipment.')
            (New-ChoiceAttr "${p}_Region" 'Region' $Choices.Region 'Operating region: Ontario, New York or Ohio.')
            (New-StringAttr "${p}_SiteCode" 'Site Code' 10 'Short code of the station or service centre.')
            (New-StringAttr "${p}_SiteName" 'Site' 100 'Station or service centre the asset belongs to.')
            (New-StringAttr "${p}_City" 'City' 60 'City of the site.')
            (New-StringAttr "${p}_Manufacturer" 'Manufacturer' 100 'Equipment manufacturer.')
            (New-StringAttr "${p}_Rating" 'Rating' 60 'Nameplate rating or pole class.')
            (New-IntAttr "${p}_InstallYear" 'Install Year' 1900 2100 'Year the asset was installed.')
            (New-IntAttr "${p}_ConditionScore" 'Condition Score' 0 100 'Health index from 0 (failed) to 100 (as new). Below 30 is poor condition.')
            (New-ChoiceAttr "${p}_OperationalStatus" 'Operational Status' $Choices.OperationalStatus 'In service, out of service or retired.')
            (New-DateOnlyAttr "${p}_LastInspectionDate" 'Last Inspection' 'Date of the most recent inspection.')
        )
    }
    Crew      = @{
        Schema      = "${p}_Crew"; Display = 'Crew'; Plural = 'Crews'
        Description = 'Harbourline field crews with region, specialty, lead and certifications.'
        Primary     = (New-StringAttr "${p}_CrewCode" 'Crew Code' 100 'Crew ID such as CREW-ON-03.' -Primary)
        Columns     = @(
            (New-StringAttr "${p}_CrewName" 'Crew Name' 100 'Descriptive crew name.')
            (New-ChoiceAttr "${p}_Region" 'Region' $Choices.Region 'Home region of the crew.')
            (New-StringAttr "${p}_BaseDepot" 'Base Depot' 100 'Depot where the crew is based.')
            (New-StringAttr "${p}_Specialty" 'Specialty' 60 'Main type of work.')
            (New-StringAttr "${p}_CrewLead" 'Crew Lead' 100 'Crew lead (foreman).')
            (New-IntAttr "${p}_CrewSize" 'Crew Size' 1 20 'Number of workers in the crew.')
            (New-MemoAttr "${p}_Certifications" 'Certifications' 2000 'Semicolon separated list of crew certifications.')
        )
    }
    WorkOrder = @{
        Schema      = "${p}_WorkOrder"; Display = 'Work Order'; Plural = 'Work Orders'
        Description = 'Harbourline maintenance and restoration work orders (WO).'
        Primary     = (New-StringAttr "${p}_WorkOrderNumber" 'Work Order Number' 100 'Work order ID such as WO-2026-01043.' -Primary)
        Columns     = @(
            (New-StringAttr "${p}_Title" 'Title' 200 'Short title of the work.')
            (New-MemoAttr "${p}_Description" 'Description' 4000 'Details of the work.')
            (New-ChoiceAttr "${p}_WorkType" 'Work Type' $Choices.WorkType 'Kind of work.')
            (New-ChoiceAttr "${p}_Priority" 'Priority' $Choices.Priority 'Emergency, High, Routine or Deferred.')
            (New-ChoiceAttr "${p}_Status" 'Status' $Choices.Status 'Open statuses: New, Scheduled, In Progress, On Hold.')
            (New-ChoiceAttr "${p}_Region" 'Region' $Choices.Region 'Region of the asset.')
            (New-DateOnlyAttr "${p}_OpenedOn" 'Opened On' 'Date the work order was raised.')
            (New-DateOnlyAttr "${p}_DueDate" 'Due Date' 'Target completion date.')
            (New-DateOnlyAttr "${p}_CompletedOn" 'Completed On' 'Date the work was completed.')
            (New-DecimalAttr "${p}_EstimatedHours" 'Estimated Hours' 10000 2 'Planned labour hours.')
            (New-DecimalAttr "${p}_ActualHours" 'Actual Hours' 10000 2 'Actual labour hours.')
            (New-DecimalAttr "${p}_EstimatedCost" 'Estimated Cost' 100000000 2 'Estimated cost in local currency (see Currency).')
            (New-StringAttr "${p}_Currency" 'Currency' 3 'CAD for Ontario, USD for New York and Ohio.')
        )
    }
}

$Relationships = @(
    @{ Schema = "${p}_Asset_WorkOrder"; Referenced = "${p}_asset"; Lookup = "${p}_Asset"; LookupDisplay = 'Asset'; MenuLabel = 'Work Orders' }
    @{ Schema = "${p}_Crew_WorkOrder"; Referenced = "${p}_crew"; Lookup = "${p}_Crew"; LookupDisplay = 'Assigned Crew'; MenuLabel = 'Work Orders' }
)

# ------------------------------------------------------------------ metadata operations
function Get-TableMetadata([string]$LogicalName) {
    $r = Invoke-Dv GET "EntityDefinitions(LogicalName='$LogicalName')?`$select=MetadataId,EntitySetName,LogicalName,PrimaryIdAttribute" -AllowNotFound
    if ($r.StatusCode -eq 404) { return $null }
    return $r.Json
}

function Test-Attribute([string]$Table, [string]$Column) {
    $r = Invoke-Dv GET "EntityDefinitions(LogicalName='$Table')/Attributes(LogicalName='$Column')?`$select=LogicalName" -AllowNotFound
    return ($r.StatusCode -ne 404)
}

function Initialize-PublisherAndSolution {
    $pubs = (Invoke-Dv GET "publishers?`$select=publisherid,uniquename,customizationoptionvalueprefix&`$filter=customizationprefix eq '$p'").Json.value
    if (@($pubs).Count -gt 0) {
        $pub = @($pubs)[0]
        Write-Host "Publisher with prefix '$p' exists: $($pub.uniquename)"
        if ($pub.customizationoptionvalueprefix -ne $PublisherOptionPrefix) {
            Write-Warning "Publisher choice value prefix is $($pub.customizationoptionvalueprefix), not $PublisherOptionPrefix. Choice values are still sent explicitly (714800000 and up)."
        }
        $pubId = $pub.publisherid
    }
    else {
        $r = Invoke-Dv POST 'publishers' -Body ([ordered]@{
                friendlyname                   = "Harbourline Energy Co. (course, $Prefix)"
                uniquename                     = $PublisherUniqueName
                description                    = 'Publisher for the Microsoft 365 Copilot agent course Harbourline tables.'
                customizationprefix            = $p
                customizationoptionvalueprefix = $PublisherOptionPrefix
            })
        $pubId = ([string]($r.Headers['OData-EntityId'] | Select-Object -First 1)) -replace '^.*\(([0-9a-fA-F-]{36})\).*$', '$1'
        Write-Host "Created publisher $PublisherUniqueName"
    }
    $sol = (Invoke-Dv GET "solutions?`$select=solutionid&`$filter=uniquename eq '$SolutionUniqueName'").Json.value
    if (@($sol).Count -eq 0) {
        Invoke-Dv POST 'solutions' -Body ([ordered]@{
                friendlyname             = "Harbourline Operations ($Prefix)"
                uniquename               = $SolutionUniqueName
                description              = 'Asset, Crew and Work Order tables for Labs 4, 5, 10 and 11.'
                version                  = '1.0.0.0'
                'publisherid@odata.bind' = "publishers($pubId)"
            }) | Out-Null
        Write-Host "Created solution $SolutionUniqueName"
    }
    else {
        Write-Host "Solution $SolutionUniqueName exists"
    }
}

function Initialize-Table([hashtable]$Def) {
    $logical = $Def.Schema.ToLowerInvariant()
    if (-not (Get-TableMetadata $logical)) {
        $body = [ordered]@{
            '@odata.type'         = 'Microsoft.Dynamics.CRM.EntityMetadata'
            SchemaName            = $Def.Schema
            DisplayName           = (New-Label $Def.Display)
            DisplayCollectionName = (New-Label $Def.Plural)
            Description           = (New-Label $Def.Description)
            OwnershipType         = 'UserOwned'
            IsActivity            = $false
            HasActivities         = $false
            HasNotes              = $false
            PrimaryNameAttribute  = $Def.Primary.SchemaName.ToLowerInvariant()
            Attributes            = @($Def.Primary)
        }
        Write-Host "Creating table $($Def.Schema) (this can take a minute)"
        Invoke-Dv POST 'EntityDefinitions' -Body $body -InSolution | Out-Null
    }
    else {
        Write-Host "Table $($Def.Schema) exists"
    }
    foreach ($col in $Def.Columns) {
        $colLogical = $col.SchemaName.ToLowerInvariant()
        if (Test-Attribute $logical $colLogical) { continue }
        Write-Host "  Adding column $($col.SchemaName)"
        Invoke-Dv POST "EntityDefinitions(LogicalName='$logical')/Attributes" -Body $col -InSolution | Out-Null
    }
}

function Initialize-Relationship([hashtable]$Rel) {
    $existing = Invoke-Dv GET "RelationshipDefinitions(SchemaName='$($Rel.Schema)')?`$select=SchemaName" -AllowNotFound
    if ($existing.StatusCode -ne 404) {
        Write-Host "Relationship $($Rel.Schema) exists"
        return
    }
    $lookup = New-AttrBase 'LookupAttributeMetadata' 'Lookup' 'LookupType' $Rel.Lookup $Rel.LookupDisplay "Lookup to $($Rel.Referenced)."
    $body = [ordered]@{
        '@odata.type'                         = 'Microsoft.Dynamics.CRM.OneToManyRelationshipMetadata'
        SchemaName                            = $Rel.Schema
        ReferencedEntity                      = $Rel.Referenced
        ReferencedAttribute                   = "$($Rel.Referenced)id"
        ReferencingEntity                     = "${p}_workorder"
        ReferencingEntityNavigationPropertyName = $Rel.Lookup
        IsHierarchical                        = $false
        AssociatedMenuConfiguration           = [ordered]@{
            Behavior = 'UseLabel'
            Group    = 'Details'
            Label    = (New-Label $Rel.MenuLabel)
            Order    = 10000
        }
        CascadeConfiguration                  = [ordered]@{
            Assign     = 'NoCascade'
            Delete     = 'RemoveLink'
            Merge      = 'Cascade'
            Reparent   = 'NoCascade'
            Share      = 'NoCascade'
            Unshare    = 'NoCascade'
            RollupView = 'NoCascade'
        }
        Lookup                                = $lookup
    }
    Write-Host "Creating relationship $($Rel.Schema)"
    Invoke-Dv POST 'RelationshipDefinitions' -Body $body -InSolution | Out-Null
}

function Publish-Tables {
    $entities = ($Tables.Values | ForEach-Object { "<entity>$($_.Schema.ToLowerInvariant())</entity>" }) -join ''
    try {
        Invoke-Dv POST 'PublishXml' -Body @{ ParameterXml = "<importexportxml><entities>$entities</entities></importexportxml>" } | Out-Null
        Write-Host 'Published customizations for the three tables'
    }
    catch {
        Write-Warning "PublishXml failed: $($_.Exception.Message). Publish all customizations in the maker portal."
    }
}

# ------------------------------------------------------------------ data helpers
function Get-RowId([string]$LogicalName, [string]$Key) {
    $md5 = [System.Security.Cryptography.MD5]::Create()
    try {
        $bytes = $md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes("$LogicalName|$Key"))
    }
    finally { $md5.Dispose() }
    return ([guid]::new($bytes)).ToString()
}

function ConvertTo-NullableNumber([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    return [decimal]::Parse($Value, [System.Globalization.CultureInfo]::InvariantCulture)
}

function ConvertTo-NullableDate([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    return $Value
}

function Send-Rows([string]$Label, [System.Collections.Generic.List[object]]$Requests) {
    $total = $Requests.Count
    $failed = 0
    for ($i = 0; $i -lt $total; $i += $BatchSize) {
        $chunk = $Requests.GetRange($i, [Math]::Min($BatchSize, $total - $i))
        $failed += Invoke-DvBatch -Requests $chunk
        Write-Progress -Activity "Loading $Label" -Status "$([Math]::Min($i + $BatchSize, $total)) of $total" -PercentComplete ([Math]::Min(100, 100 * ($i + $BatchSize) / $total))
    }
    Write-Progress -Activity "Loading $Label" -Completed
    Write-Host ("{0}: {1} rows sent, {2} failed" -f $Label, $total, $failed)
    return $failed
}

function Import-SeedData {
    $asset = Get-TableMetadata "${p}_asset"
    $crew = Get-TableMetadata "${p}_crew"
    $wo = Get-TableMetadata "${p}_workorder"
    # Single-valued navigation property names were set explicitly when the relationships were created
    # (ReferencingEntityNavigationPropertyName = lookup schema name).
    $navAsset = "${p}_Asset"
    $navCrew = "${p}_Crew"

    $crewRows = Import-Csv -Path (Join-Path $DataPath 'Crews.csv')
    $assetRows = Import-Csv -Path (Join-Path $DataPath 'Assets.csv')
    $woRows = Import-Csv -Path (Join-Path $DataPath 'WorkOrders.csv')
    $failed = 0

    $req = [System.Collections.Generic.List[object]]::new()
    foreach ($c in $crewRows) {
        $req.Add(@{
                Method = 'PATCH'
                Url    = "$($crew.EntitySetName)($(Get-RowId "${p}_crew" $c.CrewCode))"
                Body   = [ordered]@{
                    "${p}_crewcode"       = $c.CrewCode
                    "${p}_crewname"       = $c.CrewName
                    "${p}_region"         = $Choices.Region[$c.Region]
                    "${p}_basedepot"      = $c.BaseDepot
                    "${p}_specialty"      = $c.Specialty
                    "${p}_crewlead"       = $c.CrewLead
                    "${p}_crewsize"       = [int]$c.CrewSize
                    "${p}_certifications" = $c.Certifications
                }
            })
    }
    $failed += Send-Rows 'Crews' $req

    $req = [System.Collections.Generic.List[object]]::new()
    foreach ($a in $assetRows) {
        $req.Add(@{
                Method = 'PATCH'
                Url    = "$($asset.EntitySetName)($(Get-RowId "${p}_asset" $a.AssetNumber))"
                Body   = [ordered]@{
                    "${p}_assetnumber"        = $a.AssetNumber
                    "${p}_assettype"          = $Choices.AssetType[$a.AssetType]
                    "${p}_region"             = $Choices.Region[$a.Region]
                    "${p}_sitecode"           = $a.SiteCode
                    "${p}_sitename"           = $a.SiteName
                    "${p}_city"               = $a.City
                    "${p}_manufacturer"       = $a.Manufacturer
                    "${p}_rating"             = $a.Rating
                    "${p}_installyear"        = [int]$a.InstallYear
                    "${p}_conditionscore"     = [int]$a.ConditionScore
                    "${p}_operationalstatus"  = $Choices.OperationalStatus[$a.OperationalStatus]
                    "${p}_lastinspectiondate" = (ConvertTo-NullableDate $a.LastInspectionDate)
                }
            })
    }
    $failed += Send-Rows 'Assets' $req

    $req = [System.Collections.Generic.List[object]]::new()
    foreach ($w in $woRows) {
        $req.Add(@{
                Method = 'PATCH'
                Url    = "$($wo.EntitySetName)($(Get-RowId "${p}_workorder" $w.WorkOrderNumber))"
                Body   = [ordered]@{
                    "${p}_workordernumber" = $w.WorkOrderNumber
                    "${p}_title"           = $w.Title
                    "${p}_description"     = $w.Description
                    "${p}_worktype"        = $Choices.WorkType[$w.WorkType]
                    "${p}_priority"        = $Choices.Priority[$w.Priority]
                    "${p}_status"          = $Choices.Status[$w.Status]
                    "${p}_region"          = $Choices.Region[$w.Region]
                    "${p}_openedon"        = (ConvertTo-NullableDate $w.OpenedOn)
                    "${p}_duedate"         = (ConvertTo-NullableDate $w.DueDate)
                    "${p}_completedon"     = (ConvertTo-NullableDate $w.CompletedOn)
                    "${p}_estimatedhours"  = (ConvertTo-NullableNumber $w.EstimatedHours)
                    "${p}_actualhours"     = (ConvertTo-NullableNumber $w.ActualHours)
                    "${p}_estimatedcost"   = (ConvertTo-NullableNumber $w.EstimatedCost)
                    "${p}_currency"        = $w.Currency
                    "$navAsset@odata.bind" = "/$($asset.EntitySetName)($(Get-RowId "${p}_asset" $w.AssetNumber))"
                    "$navCrew@odata.bind"  = "/$($crew.EntitySetName)($(Get-RowId "${p}_crew" $w.CrewCode))"
                }
            })
    }
    $failed += Send-Rows 'Work orders' $req

    if ($failed -gt 0) { Write-Warning "$failed rows failed. Re-run the script; it is safe to repeat." }
}

# ------------------------------------------------------------------ cleanup
function Remove-TableAndRows([string]$LogicalName) {
    $meta = Get-TableMetadata $LogicalName
    if (-not $meta) { Write-Host "Table $LogicalName not found, skipping"; return }
    $ids = [System.Collections.Generic.List[string]]::new()
    $next = "$($meta.EntitySetName)?`$select=$($meta.PrimaryIdAttribute)"
    while ($next) {
        $r = Invoke-Dv GET $next -Headers @{ 'Prefer' = 'odata.maxpagesize=5000' }
        foreach ($row in $r.Json.value) { $ids.Add($row.($meta.PrimaryIdAttribute)) }
        $next = if ($r.Json.PSObject.Properties['@odata.nextLink']) { $r.Json.'@odata.nextLink' } else { $null }
    }
    if ($ids.Count -gt 0) {
        $req = [System.Collections.Generic.List[object]]::new()
        foreach ($id in $ids) { $req.Add(@{ Method = 'DELETE'; Url = "$($meta.EntitySetName)($id)"; Body = $null }) }
        [void](Send-Rows "Delete $LogicalName rows" $req)
    }
    Write-Host "Deleting table $LogicalName"
    Invoke-Dv DELETE "EntityDefinitions($($meta.MetadataId))" | Out-Null
}

function Invoke-Cleanup {
    Remove-TableAndRows "${p}_workorder"
    Remove-TableAndRows "${p}_asset"
    Remove-TableAndRows "${p}_crew"
    $sol = (Invoke-Dv GET "solutions?`$select=solutionid&`$filter=uniquename eq '$SolutionUniqueName'").Json.value
    if (@($sol).Count -gt 0) {
        Invoke-Dv DELETE "solutions($(@($sol)[0].solutionid))" | Out-Null
        Write-Host "Deleted solution $SolutionUniqueName"
    }
    $pub = (Invoke-Dv GET "publishers?`$select=publisherid&`$filter=uniquename eq '$PublisherUniqueName'").Json.value
    if (@($pub).Count -gt 0) {
        try {
            Invoke-Dv DELETE "publishers($(@($pub)[0].publisherid))" | Out-Null
            Write-Host "Deleted publisher $PublisherUniqueName"
        }
        catch {
            Write-Warning "Publisher $PublisherUniqueName was not deleted (other solutions may use it): $($_.Exception.Message)"
        }
    }
}

# ------------------------------------------------------------------ main
Write-Host "Dataverse environment: $EnvironmentUrl (prefix $p, solution $SolutionUniqueName)"
if ($Cleanup) {
    Invoke-Cleanup
    Write-Host 'Cleanup complete.'
    return
}

foreach ($f in 'Assets.csv', 'Crews.csv', 'WorkOrders.csv') {
    if (-not (Test-Path (Join-Path $DataPath $f))) { throw "Missing $f in $DataPath" }
}

Initialize-PublisherAndSolution
foreach ($t in $Tables.Values) { Initialize-Table $t }
foreach ($r in $Relationships) { Initialize-Relationship $r }
Publish-Tables

if (-not $SkipData) { Import-SeedData }

$summary = foreach ($t in $Tables.Values) {
    $m = Get-TableMetadata $t.Schema.ToLowerInvariant()
    $count = (Invoke-Dv GET "$($m.EntitySetName)?`$count=true&`$top=1&`$select=$($m.PrimaryIdAttribute)" -Headers @{ 'Prefer' = 'odata.include-annotations="*"' }).Json.'@odata.count'
    [pscustomobject]@{ Table = $t.Schema; EntitySet = $m.EntitySetName; Rows = $count }
}
$summary | Format-Table -AutoSize
Write-Host 'Done. Expected rows: Assets 1200, Crews 60, Work orders 3000.'
