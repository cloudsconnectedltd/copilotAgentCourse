<#
.SYNOPSIS
    Shared helpers for the Harbourline Energy course setup scripts.

.DESCRIPTION
    Imported by setup/00 to setup/04 and setup/99. Provides:
      - Write-Step               consistent console logging
      - Assert-Module            checks and imports required modules
      - Connect-CoursePnP        PnP.PowerShell interactive sign-in with your own Entra app (-ClientId)
      - Connect-CourseGraph      Microsoft Graph PowerShell sign-in with scopes
      - Set-CourseGraphTransport / Invoke-CourseGraph
                                 one Graph REST helper that works through either
                                 Invoke-MgGraphRequest or Invoke-PnPGraphMethod
      - Get-CourseNames          derives site URLs, group names, persona UPNs from -TenantUrl and -Prefix
      - Resolve-CourseDomain     default verified domain when -Domain is not given
      - Invoke-CourseAction      ShouldProcess wrapper (WhatIf / Confirm aware)
      - Get-CourseProp           StrictMode-safe property read
      - New-CoursePassword, Save-CourseSecret, Write-CourseSummary, Get-CourseRepoRoot

    PnP.PowerShell no longer ships a shared multi-tenant Entra app. You must register your own
    app and pass its client ID with -ClientId. See setup/README.md, section "Entra app registration".
#>

Set-StrictMode -Version Latest

$script:PnPConnections = @{}
$script:GraphTransport = 'Mg'
$script:GraphPnPConnection = $null

# ---------------------------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------------------------
function Write-Step {
    <#
    .SYNOPSIS
        Writes a timestamped, levelled log line to the host.
    .EXAMPLE
        Write-Step 'Creating group HLE-HR' -Level Action
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][string]$Message,
        [ValidateSet('Info', 'Ok', 'Action', 'Skip', 'Warn', 'Error', 'Header')][string]$Level = 'Info'
    )
    $ts = (Get-Date).ToString('HH:mm:ss')
    switch ($Level) {
        'Header' { Write-Host ''; Write-Host "==== $Message ====" -ForegroundColor Cyan }
        'Ok'     { Write-Host "[$ts] [ OK ] $Message" -ForegroundColor Green }
        'Action' { Write-Host "[$ts] [ DO ] $Message" -ForegroundColor White }
        'Skip'   { Write-Host "[$ts] [SKIP] $Message" -ForegroundColor DarkGray }
        'Warn'   { Write-Host "[$ts] [WARN] $Message" -ForegroundColor Yellow }
        'Error'  { Write-Host "[$ts] [FAIL] $Message" -ForegroundColor Red }
        default  { Write-Host "[$ts] [INFO] $Message" }
    }
}

# ---------------------------------------------------------------------------------------------
# Modules
# ---------------------------------------------------------------------------------------------
function Assert-Module {
    <#
    .SYNOPSIS
        Verifies that modules are installed, then imports them. Throws with an install hint if missing.
    .EXAMPLE
        Assert-Module -Name 'PnP.PowerShell' -MinimumVersion '2.12.0'
    .EXAMPLE
        Assert-Module -Name 'Microsoft.Graph.Authentication', 'Microsoft.Graph.Users'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$Name,
        [string]$MinimumVersion
    )
    foreach ($n in $Name) {
        $available = @(Get-Module -ListAvailable -Name $n | Sort-Object Version -Descending)
        if ($available.Count -eq 0) {
            throw "Module '$n' is not installed. Install it with: Install-Module $n -Scope CurrentUser"
        }
        if ($MinimumVersion -and ($available[0].Version -lt [version]$MinimumVersion)) {
            throw "Module '$n' version $($available[0].Version) is older than $MinimumVersion. Run: Update-Module $n"
        }
        if (-not (Get-Module -Name $n)) {
            Import-Module $n -ErrorAction Stop -Verbose:$false | Out-Null
        }
        Write-Step "Module $n $($available[0].Version) available" -Level Ok
    }
}

function Test-CourseModule {
    <#
    .SYNOPSIS
        Returns $true if a module is installed (no import, no throw).
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory)][string]$Name)
    return [bool](Get-Module -ListAvailable -Name $Name)
}

# ---------------------------------------------------------------------------------------------
# Naming
# ---------------------------------------------------------------------------------------------
function Get-CourseNames {
    <#
    .SYNOPSIS
        Derives every tenant object name used by the course from -TenantUrl, -Prefix and -Domain.
    .DESCRIPTION
        Returns one object with site URLs, library names, group names, persona definitions and the
        tag used to mark objects created by the setup scripts (used by -Cleanup to avoid touching
        anything the course did not create). Persona UPNs are only filled in when -Domain is given.
    .EXAMPLE
        $n = Get-CourseNames -TenantUrl https://contoso.sharepoint.com -Prefix HLE -Domain contoso.com
        $n.HubUrl        # https://contoso.sharepoint.com/sites/HLE-Harbourline-Hub
        $n.Personas.hr   # Priya Nandakumar, hle-hr@contoso.com
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$TenantUrl,
        [string]$Prefix = 'HLE',
        [string]$Domain
    )
    $uri = [uri]($TenantUrl.Trim().TrimEnd('/'))
    if ($uri.Scheme -ne 'https' -or $uri.Host -notlike '*.sharepoint.com') {
        throw "TenantUrl must look like https://<tenant>.sharepoint.com (got '$TenantUrl')."
    }
    $tenantName = $uri.Host.Split('.')[0]
    if ($tenantName.EndsWith('-admin')) { $tenantName = $tenantName.Substring(0, $tenantName.Length - 6) }
    $root = "https://$tenantName.sharepoint.com"
    $lp = $Prefix.ToLowerInvariant()
    $tag = "$Prefix-CourseSetup"

    $groups = [ordered]@{
        AllStaff    = "$Prefix-AllStaff"
        HR          = "$Prefix-HR"
        Finance     = "$Prefix-Finance"
        OpsOntario  = "$Prefix-Ops-Ontario"
        OpsUS       = "$Prefix-Ops-US"
        CourseMakers = "$Prefix-CourseMakers"
    }

    $personaDefs = @(
        @{ Key = 'hr';    GivenName = 'Priya'; Surname = 'Nandakumar'; JobTitle = 'HR Manager';        Department = 'Human Resources'; Copilot = $true;  Groups = @($groups.HR, $groups.AllStaff) }
        @{ Key = 'tech';  GivenName = 'Marcus'; Surname = 'Delaney';   JobTitle = 'Field Technician';  Department = 'Operations';      Copilot = $true;  Groups = @($groups.OpsOntario, $groups.AllStaff) }
        @{ Key = 'fin';   GivenName = 'Sofia'; Surname = 'Brennan';    JobTitle = 'Finance Analyst';   Department = 'Finance';         Copilot = $true;  Groups = @($groups.Finance, $groups.AllStaff) }
        @{ Key = 'nolic'; GivenName = 'Tom';   Surname = 'Whitfield';  JobTitle = 'Operations Clerk';  Department = 'Operations';      Copilot = $false; Groups = @($groups.OpsUS, $groups.AllStaff) }
    )
    $personas = [ordered]@{}
    foreach ($p in $personaDefs) {
        $upnPrefix = "$lp-$($p.Key)"
        $personas[$p.Key] = [pscustomobject]@{
            Key          = $p.Key
            DisplayName  = "$($p.GivenName) $($p.Surname)"
            GivenName    = $p.GivenName
            Surname      = $p.Surname
            JobTitle     = $p.JobTitle
            Department   = $p.Department
            MailNickname = $upnPrefix
            Upn          = $(if ($Domain) { "$upnPrefix@$Domain" } else { $null })
            Copilot      = $p.Copilot
            Groups       = $p.Groups
        }
    }

    [pscustomobject]@{
        Prefix         = $Prefix
        Tag            = $tag
        TenantName     = $tenantName
        TenantDomain   = "$tenantName.onmicrosoft.com"
        Domain         = $Domain
        RootUrl        = $root
        AdminUrl       = "https://$tenantName-admin.sharepoint.com"
        HubAlias       = "$Prefix-Harbourline-Hub"
        HubTitle       = 'Harbourline Hub'
        HubUrl         = "$root/sites/$Prefix-Harbourline-Hub"
        OpsAlias       = "$Prefix-Harbourline-Operations"
        OpsTitle       = 'Harbourline Operations'
        OpsUrl         = "$root/sites/$Prefix-Harbourline-Operations"
        HubLibraries   = @('Getting-Started', 'HR-Policies', 'Finance')
        OpsLibraries   = @('Procedures', 'Archive-Bulk')
        VendorsList    = 'Vendors'
        RestrictedPath = 'HR-Policies/Restricted'
        IncomingPath   = 'Procedures/Incoming'
        Groups         = [pscustomobject]$groups
        Personas       = [pscustomobject]$personas
        GuestDisplayName = 'Harbourline Contractor (Guest)'
        LabelName      = "$Prefix-HR-Confidential"
        LabelDisplayName = "$Prefix HR Confidential"
        LabelPolicyName  = "$Prefix-HR-Label-Policy"
    }
}

function Get-CourseRepoRoot {
    <#
    .SYNOPSIS
        Returns the course repository root (the parent of setup/).
    #>
    [CmdletBinding()]
    param()
    return (Split-Path -Parent $PSScriptRoot)
}

# ---------------------------------------------------------------------------------------------
# StrictMode-safe property access
# ---------------------------------------------------------------------------------------------
function Get-CourseProp {
    <#
    .SYNOPSIS
        Reads a property or dictionary key without throwing under Set-StrictMode -Version Latest.
    .EXAMPLE
        Get-CourseProp -InputObject $resp -Name '@odata.nextLink'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)][AllowNull()]$InputObject,
        [Parameter(Mandatory, Position = 1)][string]$Name
    )
    if ($null -eq $InputObject) { return $null }
    if ($InputObject -is [System.Collections.IDictionary]) {
        if ($InputObject.Contains($Name)) { return $InputObject[$Name] }
        return $null
    }
    try {
        $p = $InputObject.PSObject.Properties[$Name]
        if ($null -ne $p) { return $p.Value }
    }
    catch {
        return $null
    }
    return $null
}

# ---------------------------------------------------------------------------------------------
# Connections
# ---------------------------------------------------------------------------------------------
function Test-CourseDeviceCode {
    <#
    .SYNOPSIS
        True when $env:HLE_DEVICE_CODE is 1, which switches Graph and PnP sign-in to the device code flow.
    .EXAMPLE
        $env:HLE_DEVICE_CODE = '1'   # then run any setup script
    #>
    return ($env:HLE_DEVICE_CODE -eq '1')
}

function Connect-CoursePnP {
    <#
    .SYNOPSIS
        Interactive PnP.PowerShell sign-in to one site, using your own Entra app registration.
    .DESCRIPTION
        PnP.PowerShell removed its shared "PnP Management Shell" multi-tenant app, so interactive
        sign-in needs an app registration in your tenant (public client, redirect URI http://localhost).
        Create one with Register-PnPEntraIDAppForInteractiveLogin or in the Entra admin center, then
        pass its Application (client) ID here. Connections are cached per URL for this session and
        returned so callers can pass -Connection explicitly.
    .EXAMPLE
        $admin = Connect-CoursePnP -Url https://contoso-admin.sharepoint.com -ClientId 00000000-0000-0000-0000-000000000000 -Tenant contoso.onmicrosoft.com
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$ClientId,
        [string]$Tenant
    )
    $key = $Url.TrimEnd('/').ToLowerInvariant()
    if ($script:PnPConnections.ContainsKey($key)) { return $script:PnPConnections[$key] }
    Write-Step "Connecting PnP to $Url (interactive, client ID $ClientId)" -Level Action
    $params = @{ Url = $Url; ClientId = $ClientId; ReturnConnection = $true }
    if ($Tenant) { $params['Tenant'] = $Tenant }
    if (Test-CourseDeviceCode) {
        # Device code sign-in: avoids the local browser redirect, which fails on some machines.
        $params['DeviceLogin'] = $true
    }
    else {
        $params['Interactive'] = $true
    }
    $conn = Connect-PnPOnline @params
    $script:PnPConnections[$key] = $conn
    return $conn
}

function Connect-CourseGraph {
    <#
    .SYNOPSIS
        Connects Microsoft Graph PowerShell with the given delegated scopes (reuses an existing
        session if it already has them).
    .EXAMPLE
        Connect-CourseGraph -Scopes 'User.ReadWrite.All','Group.ReadWrite.All' -TenantId contoso.onmicrosoft.com
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$Scopes,
        [string]$TenantId,
        [string]$ClientId
    )
    $ctx = Get-MgContext
    if ($ctx) {
        $have = @($ctx.Scopes)
        $missing = @($Scopes | Where-Object { $have -notcontains $_ })
        if ($missing.Count -eq 0) {
            Write-Step "Graph already connected as $($ctx.Account)" -Level Ok
            Set-CourseGraphTransport -Mg
            return $ctx
        }
        Write-Step "Graph session lacks scopes: $($missing -join ', '). Reconnecting." -Level Warn
    }
    $params = @{ Scopes = $Scopes; NoWelcome = $true }
    if ($TenantId) { $params['TenantId'] = $TenantId }
    if ($ClientId) { $params['ClientId'] = $ClientId }
    if (Test-CourseDeviceCode) { $params['UseDeviceCode'] = $true }
    Write-Step "Connecting Microsoft Graph (scopes: $($Scopes -join ', '))" -Level Action
    Connect-MgGraph @params | Out-Null
    Set-CourseGraphTransport -Mg
    $ctx = Get-MgContext
    Write-Step "Graph connected as $($ctx.Account)" -Level Ok
    return $ctx
}

function Set-CourseGraphTransport {
    <#
    .SYNOPSIS
        Chooses how Invoke-CourseGraph sends requests: Microsoft Graph SDK (-Mg) or PnP (-PnPConnection).
    .DESCRIPTION
        Scripts that already use PnP send Graph calls through Invoke-PnPGraphMethod so they do not need to
        load Microsoft.Graph in the same session. The PnP app registration then needs the Graph
        delegated permissions listed in setup/README.md.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Mg')]
    param(
        [Parameter(ParameterSetName = 'Mg')][switch]$Mg,
        [Parameter(ParameterSetName = 'PnP', Mandatory)]$PnPConnection
    )
    if ($PSCmdlet.ParameterSetName -eq 'PnP') {
        $script:GraphTransport = 'PnP'
        $script:GraphPnPConnection = $PnPConnection
    }
    else {
        $script:GraphTransport = 'Mg'
        $script:GraphPnPConnection = $null
    }
}

function Invoke-CourseGraphRaw {
    [CmdletBinding()]
    param(
        [string]$Method = 'GET',
        [Parameter(Mandatory)][string]$Uri,
        $Body,
        [hashtable]$Headers
    )
    if ($script:GraphTransport -eq 'PnP') {
        $p = @{ Url = $Uri; Method = $Method; Connection = $script:GraphPnPConnection }
        if ($null -ne $Body) { $p['Content'] = $Body }
        if ($Headers -and $Headers.ContainsKey('ConsistencyLevel')) { $p['ConsistencyLevelEventual'] = $true }
        return Invoke-PnPGraphMethod @p
    }
    $full = if ($Uri -match '^https://') { $Uri } else { "https://graph.microsoft.com/$($Uri.TrimStart('/'))" }
    $p = @{ Method = $Method; Uri = $full; OutputType = 'PSObject' }
    if ($null -ne $Body) { $p['Body'] = ($Body | ConvertTo-Json -Depth 10); $p['ContentType'] = 'application/json' }
    if ($Headers) { $p['Headers'] = $Headers }
    return Invoke-MgGraphRequest @p
}

function Invoke-CourseGraph {
    <#
    .SYNOPSIS
        Calls a Microsoft Graph REST path through the current transport. With -All, follows
        @odata.nextLink and returns every item in 'value'.
    .EXAMPLE
        $groups = @(Invoke-CourseGraph -Uri ('v1.0/groups?$filter=' + (ConvertTo-CourseFilter "displayName eq 'HLE-HR'")) -All)
    .EXAMPLE
        Invoke-CourseGraph -Method POST -Uri "v1.0/groups/$gid/members/`$ref" -Body @{ '@odata.id' = "https://graph.microsoft.com/v1.0/directoryObjects/$uid" }
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('GET', 'POST', 'PATCH', 'PUT', 'DELETE')][string]$Method = 'GET',
        [Parameter(Mandatory)][string]$Uri,
        $Body,
        [hashtable]$Headers,
        [switch]$All
    )
    if (-not $All) {
        return Invoke-CourseGraphRaw -Method $Method -Uri $Uri -Body $Body -Headers $Headers
    }
    $items = New-Object System.Collections.Generic.List[object]
    $next = $Uri
    while ($next) {
        $resp = Invoke-CourseGraphRaw -Method $Method -Uri $next -Body $Body -Headers $Headers
        foreach ($v in @(Get-CourseProp $resp 'value')) { if ($null -ne $v) { $items.Add($v) } }
        $next = Get-CourseProp $resp '@odata.nextLink'
    }
    return $items.ToArray()
}

function ConvertTo-CourseFilter {
    <#
    .SYNOPSIS
        URL-encodes an OData $filter expression.
    .EXAMPLE
        'v1.0/users?$filter=' + (ConvertTo-CourseFilter "mail eq 'a@b.com'")
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory, Position = 0)][string]$Filter)
    return [uri]::EscapeDataString($Filter)
}

function Resolve-CourseDomain {
    <#
    .SYNOPSIS
        Returns -Domain if given, otherwise the tenant's default verified domain (via Invoke-CourseGraph).
    #>
    [CmdletBinding()]
    param([string]$Domain)
    if ($Domain) { return $Domain }
    $org = Invoke-CourseGraph -Uri 'v1.0/organization?$select=verifiedDomains'
    foreach ($o in @(Get-CourseProp $org 'value')) {
        foreach ($d in @(Get-CourseProp $o 'verifiedDomains')) {
            if ((Get-CourseProp $d 'isDefault') -eq $true) {
                $name = Get-CourseProp $d 'name'
                Write-Step "Using default verified domain $name (override with -Domain)" -Level Info
                return $name
            }
        }
    }
    throw 'Could not determine the default verified domain. Pass -Domain.'
}

function Get-CourseEntraGroup {
    <#
    .SYNOPSIS
        Finds an Entra group by display name via Invoke-CourseGraph. Returns $null if not found.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$DisplayName)
    $f = ConvertTo-CourseFilter ("displayName eq '{0}'" -f $DisplayName.Replace("'", "''"))
    $r = @(Invoke-CourseGraph -Uri ('v1.0/groups?$select=id,displayName,description,mail,mailEnabled,securityEnabled,mailNickname&$filter=' + $f) -All)
    if ($r.Count -gt 1) { Write-Step "More than one group named '$DisplayName'. Using the first." -Level Warn }
    if ($r.Count -eq 0) { return $null }
    return $r[0]
}

function Get-CourseEntraUser {
    <#
    .SYNOPSIS
        Finds an Entra user by UPN (or, with -Mail, a guest by mail) via Invoke-CourseGraph. Returns $null if not found.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Upn')]
    param(
        [Parameter(ParameterSetName = 'Upn', Mandatory)][string]$UserPrincipalName,
        [Parameter(ParameterSetName = 'Mail', Mandatory)][string]$Mail
    )
    $sel = 'id,displayName,userPrincipalName,mail,userType,onPremisesExtensionAttributes'
    if ($PSCmdlet.ParameterSetName -eq 'Upn') {
        try {
            return Invoke-CourseGraph -Uri ("v1.0/users/{0}?`$select={1}" -f [uri]::EscapeDataString($UserPrincipalName), $sel)
        }
        catch {
            return $null
        }
    }
    $f = ConvertTo-CourseFilter ("mail eq '{0}'" -f $Mail.Replace("'", "''"))
    $r = @(Invoke-CourseGraph -Uri ("v1.0/users?`$select=$sel&`$filter=$f") -All)
    if ($r.Count -eq 0) { return $null }
    return $r[0]
}

# ---------------------------------------------------------------------------------------------
# Idempotency and ShouldProcess
# ---------------------------------------------------------------------------------------------
function Invoke-CourseAction {
    <#
    .SYNOPSIS
        Runs a change only if the calling script's ShouldProcess approves it (honours -WhatIf and -Confirm).
    .DESCRIPTION
        Pass the calling script's $PSCmdlet. Returns whatever the script block returns, or $null when
        skipped. Always pair with a "does it already exist" check before calling, so reruns are no-ops.
    .EXAMPLE
        if (-not $group) {
            $group = Invoke-CourseAction -Cmdlet $PSCmdlet -Target 'HLE-HR' -Action 'Create security group' -ScriptBlock { New-MgGroup @p }
        }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][System.Management.Automation.PSCmdlet]$Cmdlet,
        [Parameter(Mandatory)][string]$Target,
        [Parameter(Mandatory)][string]$Action,
        [Parameter(Mandatory)][scriptblock]$ScriptBlock
    )
    if ($Cmdlet.ShouldProcess($Target, $Action)) {
        Write-Step "$Action : $Target" -Level Action
        return (& $ScriptBlock)
    }
    Write-Step "Not run (WhatIf or declined): $Action : $Target" -Level Skip
    return $null
}

function Test-CourseTagged {
    <#
    .SYNOPSIS
        True if a Graph user object carries the course tag in onPremisesExtensionAttributes.extensionAttribute15.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param([AllowNull()]$User, [Parameter(Mandatory)][string]$Tag)
    if ($null -eq $User) { return $false }
    $ext = Get-CourseProp $User 'onPremisesExtensionAttributes'
    if ($null -eq $ext) { $ext = Get-CourseProp $User 'OnPremisesExtensionAttributes' }
    $v = Get-CourseProp $ext 'extensionAttribute15'
    if ($null -eq $v) { $v = Get-CourseProp $ext 'ExtensionAttribute15' }
    return ($v -eq $Tag)
}

function Wait-CourseCondition {
    <#
    .SYNOPSIS
        Polls a script block until it returns a truthy value or the timeout elapses. Returns the last value.
    .EXAMPLE
        Wait-CourseCondition -Description 'site provisioning' -TimeoutSeconds 900 -Condition { (Get-PnPTenantSite -Identity $u -Connection $a).Status -eq 'Active' }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][scriptblock]$Condition,
        [string]$Description = 'condition',
        [int]$TimeoutSeconds = 600,
        [int]$IntervalSeconds = 15
    )
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $r = $null
        try { $r = & $Condition } catch { $r = $null }
        if ($r) { return $r }
        Write-Step "Waiting for $Description ..." -Level Info
        Start-Sleep -Seconds $IntervalSeconds
    } while ((Get-Date) -lt $deadline)
    Write-Step "Timed out after $TimeoutSeconds s waiting for $Description" -Level Warn
    return $null
}

# ---------------------------------------------------------------------------------------------
# SharePoint helpers
# ---------------------------------------------------------------------------------------------
function Get-CourseTenantSite {
    <#
    .SYNOPSIS
        Returns the tenant site object for a URL, or $null if it does not exist.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Url, [Parameter(Mandatory)]$Connection)
    try {
        return Get-PnPTenantSite -Identity $Url -Connection $Connection -ErrorAction Stop
    }
    catch {
        return $null
    }
}

function Confirm-CourseFolder {
    <#
    .SYNOPSIS
        Ensures a site-relative folder path exists (for example 'HR-Policies/Restricted'), creating
        each missing level with Add-PnPFolder. Caches results per connection.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$SiteRelativePath,
        [Parameter(Mandatory)]$Connection,
        [hashtable]$Cache
    )
    $parts = $SiteRelativePath.Trim('/').Split('/')
    $current = $parts[0]
    for ($i = 1; $i -lt $parts.Length; $i++) {
        $parent = $current
        $current = "$parent/$($parts[$i])"
        if ($Cache -and $Cache.ContainsKey($current)) { continue }
        $exists = $false
        try {
            $null = Get-PnPFolder -Url $current -Connection $Connection -ErrorAction Stop
            $exists = $true
        }
        catch { $exists = $false }
        if (-not $exists) {
            if ($PSCmdlet.ShouldProcess($current, 'Create folder')) {
                Write-Step "Create folder : $current" -Level Action
                $null = Add-PnPFolder -Name $parts[$i] -Folder $parent -Connection $Connection
            }
        }
        if ($Cache) { $Cache[$current] = $true }
    }
}

function Get-CourseGroupClaim {
    <#
    .SYNOPSIS
        Returns the SharePoint claims login name for an Entra security group object ID.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$GroupId)
    return "c:0t.c|tenant|$GroupId"
}

# ---------------------------------------------------------------------------------------------
# Secrets and output
# ---------------------------------------------------------------------------------------------
function New-CoursePassword {
    <#
    .SYNOPSIS
        Generates a random password with upper, lower, digit and symbol characters.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([ValidateRange(14, 64)][int]$Length = 20)
    $sets = @('ABCDEFGHJKLMNPQRSTUVWXYZ', 'abcdefghijkmnopqrstuvwxyz', '23456789', '!#$%*+-=?@')
    $all = -join $sets
    $chars = New-Object System.Collections.Generic.List[char]
    foreach ($s in $sets) { $chars.Add($s[[System.Security.Cryptography.RandomNumberGenerator]::GetInt32($s.Length)]) }
    while ($chars.Count -lt $Length) { $chars.Add($all[[System.Security.Cryptography.RandomNumberGenerator]::GetInt32($all.Length)]) }
    # Fisher-Yates shuffle
    for ($i = $chars.Count - 1; $i -gt 0; $i--) {
        $j = [System.Security.Cryptography.RandomNumberGenerator]::GetInt32($i + 1)
        $tmp = $chars[$i]; $chars[$i] = $chars[$j]; $chars[$j] = $tmp
    }
    return -join $chars
}

function Save-CourseSecret {
    <#
    .SYNOPSIS
        Appends lines to a local file readable only by the current user (chmod 600 or a Windows ACL).
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string[]]$Lines
    )
    if (-not $PSCmdlet.ShouldProcess($Path, 'Write initial passwords')) { return }
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $isNew = -not (Test-Path -LiteralPath $Path)
    if ($isNew) {
        New-Item -ItemType File -Path $Path -Force | Out-Null
        if ($IsWindows) {
            & icacls.exe $Path /inheritance:r /grant:r "$($env:USERNAME):(R,W)" | Out-Null
        }
        else {
            & chmod 600 $Path
        }
    }
    Add-Content -LiteralPath $Path -Value $Lines -Encoding utf8
    Write-Step "Initial passwords written to $Path (only you can read it). Delete it after the course." -Level Ok
}

function Write-CourseSummary {
    <#
    .SYNOPSIS
        Prints a result table (objects with Area, Check, Status, Detail) and a status count.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Rows, [string]$Title = 'Summary')
    Write-Step $Title -Level Header
    $Rows | Format-Table -Property Area, Check, Status, Detail -AutoSize -Wrap | Out-String -Width 200 | Write-Host
    $counts = $Rows | Group-Object Status | ForEach-Object { "$($_.Name)=$($_.Count)" }
    Write-Host ("Totals: " + ($counts -join ', '))
}

Export-ModuleMember -Function Write-Step, Test-CourseDeviceCode, Assert-Module, Test-CourseModule, Get-CourseNames, Get-CourseRepoRoot, `
    Get-CourseProp, Connect-CoursePnP, Connect-CourseGraph, Set-CourseGraphTransport, Invoke-CourseGraph, `
    ConvertTo-CourseFilter, Resolve-CourseDomain, Get-CourseEntraGroup, Get-CourseEntraUser, Invoke-CourseAction, `
    Test-CourseTagged, Wait-CourseCondition, Get-CourseTenantSite, Confirm-CourseFolder, Get-CourseGroupClaim, `
    New-CoursePassword, Save-CourseSecret, Write-CourseSummary
