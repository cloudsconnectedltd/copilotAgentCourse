<#
.SYNOPSIS
    Deploys the Harbourline Energy Co. mock API (Azure Functions, Node.js) to Azure, or removes it.

.DESCRIPTION
    Optional deployment for Labs 5, 6, 8 and 10 when a dev tunnel to a local Functions host is not
    suitable. Uses the Azure CLI (az). The script is idempotent: it checks for each resource before
    creating it, and running it again updates app settings and redeploys the code.

    Resources created (names derive from -Prefix plus a short hash of the subscription and group):
      - Resource group (only if missing), tagged createdBy=hle-course
      - Storage account (required by Azure Functions)
      - Function App (Node.js, Functions runtime v4) on the chosen hosting plan

    -Cleanup deletes the resource group, but only when it carries the tag createdBy=hle-course,
    so an existing group that the script did not create is never deleted.

    Hosting plans, regions and Node.js versions available for Azure Functions change over time.
    Check current support on Microsoft Learn before running, and override -HostingPlan or
    -NodeVersion if the defaults are rejected.

.PARAMETER ResourceGroup
    Resource group name. Created if it does not exist.

.PARAMETER Location
    Azure region, for example canadacentral or eastus.

.PARAMETER Prefix
    Short prefix used in resource names. Default 'HLE'.

.PARAMETER AuthMode
    Value for the AUTH_MODE app setting: none, apikey or entra. Default none.

.PARAMETER ApiKey
    API key for AUTH_MODE=apikey. If omitted, an existing API_KEY setting is kept, or a random key is generated and printed once.

.PARAMETER EntraTenantId
    Tenant ID for AUTH_MODE=entra (ENTRA_TENANT_ID app setting).

.PARAMETER EntraAudience
    Comma-separated token audiences for AUTH_MODE=entra (ENTRA_AUDIENCE app setting),
    for example 'api://<api-client-id>,<api-client-id>'.

.PARAMETER EntraRequiredScope
    Optional scope or app role the token must carry (ENTRA_REQUIRED_SCOPE), for example Outages.ReadWrite.

.PARAMETER HostingPlan
    FlexConsumption (default) or Consumption.

.PARAMETER NodeVersion
    Node.js major version for the Function App runtime. Default '22'.

.PARAMETER TenantUrl
    Accepted for consistency with the other course scripts. Not used by this script.

.PARAMETER Cleanup
    Deletes the resource group if, and only if, it is tagged createdBy=hle-course.

.EXAMPLE
    ./deploy-azure.ps1 -ResourceGroup rg-hle-course -Location canadacentral

.EXAMPLE
    ./deploy-azure.ps1 -ResourceGroup rg-hle-course -Location canadacentral -AuthMode apikey

.EXAMPLE
    ./deploy-azure.ps1 -ResourceGroup rg-hle-course -Location canadacentral -AuthMode entra `
        -EntraTenantId 11111111-2222-3333-4444-555555555555 -EntraAudience 'api://aaaa-bbbb,aaaa-bbbb'

.EXAMPLE
    ./deploy-azure.ps1 -ResourceGroup rg-hle-course -Location canadacentral -Cleanup

.NOTES
    Requires PowerShell 7 and Azure CLI, signed in with 'az login' to the target subscription.
    Requires Node.js and npm locally to build the deployment package.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[-\w\._\(\)]{1,90}$')]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $true)]
    [string]$Location,

    [ValidatePattern('^[A-Za-z][A-Za-z0-9]{0,9}$')]
    [string]$Prefix = 'HLE',

    [ValidateSet('none', 'apikey', 'entra')]
    [string]$AuthMode = 'none',

    [string]$ApiKey,

    [string]$EntraTenantId,

    [string]$EntraAudience,

    [string]$EntraRequiredScope = '',

    [ValidateSet('FlexConsumption', 'Consumption')]
    [string]$HostingPlan = 'FlexConsumption',

    [ValidatePattern('^\d{2}$')]
    [string]$NodeVersion = '22',

    [string]$TenantUrl,

    [switch]$Cleanup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$CourseTagName = 'createdBy'
$CourseTagValue = 'hle-course'
$ScriptRoot = $PSScriptRoot

function Write-Step([string]$Message) { Write-Host "==> $Message" -ForegroundColor Cyan }

function Invoke-Az {
    # Runs az and returns parsed JSON. Throws on a non-zero exit code.
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    $output = & az @Arguments --only-show-errors --output json
    if ($LASTEXITCODE -ne 0) { throw "az $($Arguments -join ' ') failed with exit code $LASTEXITCODE." }
    $text = ($output | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) { return $null }
    return $text | ConvertFrom-Json
}

function Test-Az {
    # Runs az and returns parsed JSON, or $null if the command fails (for example, resource not found).
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    $output = & az @Arguments --only-show-errors --output json 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    $text = ($output | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) { return $null }
    return $text | ConvertFrom-Json
}

function Get-ShortHash([string]$Text) {
    $bytes = [System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes($Text))
    return ([System.BitConverter]::ToString($bytes) -replace '-', '').Substring(0, 6).ToLowerInvariant()
}

function Get-TagValue($Tags, [string]$Name) {
    if ($null -eq $Tags) { return $null }
    $prop = $Tags.PSObject.Properties | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
    if ($null -eq $prop) { return $null }
    return [string]$prop.Value
}

# ------------------------------------------------------------------ prerequisites
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw 'Azure CLI (az) was not found. Install it, run az login, and try again.'
}
$account = Test-Az -Arguments @('account', 'show')
if ($null -eq $account) { throw 'Not signed in to Azure CLI. Run az login (and az account set --subscription <id>) first.' }
Write-Step "Subscription: $($account.name) ($($account.id))"
if ($TenantUrl) { Write-Verbose "TenantUrl '$TenantUrl' is not used by this script." }

$suffix = Get-ShortHash "$($account.id)|$ResourceGroup|$Prefix"
$p = $Prefix.ToLowerInvariant()
$storageName = ("{0}apist{1}" -f $p, $suffix)
if ($storageName.Length -gt 24) { $storageName = $storageName.Substring(0, 24) }
$functionAppName = "$p-outage-api-$suffix"

# ------------------------------------------------------------------ cleanup
if ($Cleanup) {
    $rg = Test-Az -Arguments @('group', 'show', '--name', $ResourceGroup)
    if ($null -eq $rg) {
        Write-Step "Resource group '$ResourceGroup' does not exist. Nothing to clean up."
        return
    }
    $tag = Get-TagValue $rg.tags $CourseTagName
    if ($tag -ne $CourseTagValue) {
        Write-Warning "Resource group '$ResourceGroup' is not tagged $CourseTagName=$CourseTagValue, so this script did not create it. It will NOT be deleted."
        Write-Warning "Remove the course resources yourself if needed: Function App '$functionAppName' and storage account '$storageName'."
        return
    }
    if ($PSCmdlet.ShouldProcess($ResourceGroup, 'Delete resource group (tagged createdBy=hle-course)')) {
        Write-Step "Deleting resource group '$ResourceGroup' (runs in the background in Azure)"
        Invoke-Az -Arguments @('group', 'delete', '--name', $ResourceGroup, '--yes', '--no-wait') | Out-Null
        Write-Host "Delete requested. Check progress with: az group show --name $ResourceGroup"
    }
    return
}

# ------------------------------------------------------------------ validate auth inputs
if ($AuthMode -eq 'entra' -and ([string]::IsNullOrWhiteSpace($EntraTenantId) -or [string]::IsNullOrWhiteSpace($EntraAudience))) {
    throw 'AuthMode entra requires -EntraTenantId and -EntraAudience.'
}
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    throw 'npm was not found. Install Node.js (which includes npm) to build the deployment package.'
}

# ------------------------------------------------------------------ resource group
$rg = Test-Az -Arguments @('group', 'show', '--name', $ResourceGroup)
if ($null -eq $rg) {
    if ($PSCmdlet.ShouldProcess($ResourceGroup, "Create resource group in $Location")) {
        Write-Step "Creating resource group '$ResourceGroup' in $Location"
        $rg = Invoke-Az -Arguments @('group', 'create', '--name', $ResourceGroup, '--location', $Location, '--tags', "$CourseTagName=$CourseTagValue", 'course=copilot-agents')
    }
}
else {
    Write-Step "Resource group '$ResourceGroup' already exists"
    if ((Get-TagValue $rg.tags $CourseTagName) -ne $CourseTagValue) {
        Write-Warning "Resource group '$ResourceGroup' was not created by this script. -Cleanup will not delete it."
    }
}

# ------------------------------------------------------------------ storage account
$sa = Test-Az -Arguments @('storage', 'account', 'show', '--name', $storageName, '--resource-group', $ResourceGroup)
if ($null -eq $sa) {
    if ($PSCmdlet.ShouldProcess($storageName, 'Create storage account')) {
        Write-Step "Creating storage account '$storageName'"
        Invoke-Az -Arguments @('storage', 'account', 'create', '--name', $storageName, '--resource-group', $ResourceGroup,
            '--location', $Location, '--sku', 'Standard_LRS', '--kind', 'StorageV2', '--min-tls-version', 'TLS1_2',
            '--allow-blob-public-access', 'false', '--tags', "$CourseTagName=$CourseTagValue") | Out-Null
    }
}
else {
    Write-Step "Storage account '$storageName' already exists"
}

# ------------------------------------------------------------------ function app
$fa = Test-Az -Arguments @('functionapp', 'show', '--name', $functionAppName, '--resource-group', $ResourceGroup)
if ($null -eq $fa) {
    if ($PSCmdlet.ShouldProcess($functionAppName, "Create Function App ($HostingPlan, Node $NodeVersion)")) {
        Write-Step "Creating Function App '$functionAppName' ($HostingPlan, Node.js $NodeVersion)"
        $createArgs = @('functionapp', 'create', '--name', $functionAppName, '--resource-group', $ResourceGroup,
            '--storage-account', $storageName, '--runtime', 'node', '--runtime-version', $NodeVersion,
            '--tags', "$CourseTagName=$CourseTagValue")
        if ($HostingPlan -eq 'FlexConsumption') {
            $createArgs += @('--flexconsumption-location', $Location)
        }
        else {
            $createArgs += @('--consumption-plan-location', $Location, '--functions-version', '4', '--os-type', 'Linux')
        }
        $fa = Invoke-Az -Arguments $createArgs
    }
}
else {
    Write-Step "Function App '$functionAppName' already exists"
}

# ------------------------------------------------------------------ app settings
$settings = [ordered]@{ AUTH_MODE = $AuthMode }
$generatedKey = $null
if ($AuthMode -eq 'apikey') {
    if ([string]::IsNullOrWhiteSpace($ApiKey)) {
        $existing = Test-Az -Arguments @('functionapp', 'config', 'appsettings', 'list', '--name', $functionAppName, '--resource-group', $ResourceGroup)
        $current = $null
        if ($null -ne $existing) { $current = $existing | Where-Object { $_.name -eq 'API_KEY' } | Select-Object -First 1 }
        if ($null -eq $current) {
            $bytes = [byte[]]::new(24)
            [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
            $generatedKey = 'hle-' + ([Convert]::ToBase64String($bytes) -replace '[+/=]', '')
            $settings['API_KEY'] = $generatedKey
        }
    }
    else {
        $settings['API_KEY'] = $ApiKey
    }
}
if ($AuthMode -eq 'entra') {
    $settings['ENTRA_TENANT_ID'] = $EntraTenantId
    $settings['ENTRA_AUDIENCE'] = $EntraAudience
    $settings['ENTRA_REQUIRED_SCOPE'] = $EntraRequiredScope
}
if ($PSCmdlet.ShouldProcess($functionAppName, 'Set app settings')) {
    Write-Step "Setting app settings: $($settings.Keys -join ', ')"
    $pairs = foreach ($k in $settings.Keys) { "$k=$($settings[$k])" }
    Invoke-Az -Arguments (@('functionapp', 'config', 'appsettings', 'set', '--name', $functionAppName, '--resource-group', $ResourceGroup, '--settings') + $pairs) | Out-Null
}
else {
    $generatedKey = $null
}

# ------------------------------------------------------------------ build and deploy code
if ($PSCmdlet.ShouldProcess($functionAppName, 'Build and deploy code (zip deploy)')) {
    $staging = Join-Path ([System.IO.Path]::GetTempPath()) "hle-api-$suffix"
    if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
    New-Item -ItemType Directory -Path $staging | Out-Null
    Write-Step 'Building deployment package'
    foreach ($item in @('host.json', 'package.json', 'package-lock.json', 'src')) {
        $source = Join-Path $ScriptRoot $item
        if (Test-Path $source) { Copy-Item -Path $source -Destination $staging -Recurse }
    }
    Push-Location $staging
    try {
        if (Test-Path 'package-lock.json') { & npm ci --omit=dev --no-audit --no-fund } else { & npm install --omit=dev --no-audit --no-fund }
        if ($LASTEXITCODE -ne 0) { throw 'npm install failed while building the deployment package.' }
    }
    finally { Pop-Location }
    $zipPath = "$staging.zip"
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    Compress-Archive -Path (Join-Path $staging '*') -DestinationPath $zipPath
    Write-Step 'Deploying package (this can take a few minutes)'
    Invoke-Az -Arguments @('functionapp', 'deployment', 'source', 'config-zip', '--name', $functionAppName,
        '--resource-group', $ResourceGroup, '--src', $zipPath) | Out-Null
    Remove-Item $staging -Recurse -Force
    Remove-Item $zipPath -Force
}

# ------------------------------------------------------------------ summary
$fa = Test-Az -Arguments @('functionapp', 'show', '--name', $functionAppName, '--resource-group', $ResourceGroup)
$hostName = if ($null -ne $fa) { $fa.defaultHostName } else { "$functionAppName.azurewebsites.net" }
$baseUrl = "https://$hostName/api"
Write-Host ''
Write-Host "Function App : $functionAppName"
Write-Host "Base URL     : $baseUrl   (use this as servers.url in the OpenAPI file)"
Write-Host "AUTH_MODE    : $AuthMode"
if ($generatedKey) {
    Write-Host "API_KEY      : $generatedKey   (shown once; also stored as the API_KEY app setting)" -ForegroundColor Yellow
}
Write-Host "Smoke test   : curl `"$baseUrl/outage-status?outageId=OUT-2026-0412`""
Write-Host "Remove later : ./deploy-azure.ps1 -ResourceGroup $ResourceGroup -Location $Location -Prefix $Prefix -Cleanup"
