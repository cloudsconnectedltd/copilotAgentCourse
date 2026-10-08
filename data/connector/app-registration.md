# App registration for the Harbourline tickets connector

| Item | Value |
|---|---|
| App name | `HLE-Tickets-Connector` (use your prefix) |
| Used by | `data/connector/ingest-tickets.ps1` (Lab 7) |
| Authentication | App-only, certificate credential |
| Who does it | Global Administrator, or an AI Administrator with delegated consent rights (section 5) |
| Effective | 2026-09-30 |

## 1. Permissions

All permissions are Microsoft Graph **application** permissions and all need admin consent.

| Permission | Application permission ID | Required | Why |
|---|---|---|---|
| `ExternalConnection.ReadWrite.OwnedBy` | f431331c-49a6-499f-be1c-62af19c34a9d | Yes | Create the connection, register and read the schema, poll schema operations, delete the connection. The app can only manage connections it created or is authorized for. |
| `ExternalItem.ReadWrite.OwnedBy` | 8116ae0f-55c2-452d-9944-d18420f5b2c8 | Yes | Create and replace items (PUT) in connections the app is authorized for. |
| `Group.Read.All` | 5b567255-7703-4780-807c-7be8301ae99b | Optional | Only for the default ACL resolution, which looks up `<Prefix>-Ops-Ontario`, `<Prefix>-Ops-US`, `<Prefix>-HR` and `<Prefix>-Finance` by display name. |
| `User.Read.All` | df021288-bdef-4463-88db-98f22de89214 | Optional | Only for the default ACL resolution of `{{USER_FIN}}` (UPN starting `<prefix>-fin@`). |

If you do not want to grant the two optional permissions, look up the object IDs yourself and pass them:

```powershell
$map = @{
  '{{GROUP_OPS_ONTARIO}}' = '<object id of HLE-Ops-Ontario>'
  '{{GROUP_OPS_US}}'      = '<object id of HLE-Ops-US>'
  '{{GROUP_HR}}'          = '<object id of HLE-HR>'
  '{{GROUP_FINANCE}}'     = '<object id of HLE-Finance>'
  '{{USER_FIN}}'          = '<object id of hle-fin user>'
}
./ingest-tickets.ps1 -TenantId <tenant> -ClientId <app id> -CertificateThumbprint <thumbprint> -GroupMap $map
```

To look up the connection ID later (for example for a declarative agent manifest in Lab 6 or 7), an admin uses the separate delegated scope `ExternalConnection.Read.All` in Graph Explorer with `GET https://graph.microsoft.com/v1.0/external/connections?$select=id,name`. The connection ID for this course is `hleTickets`.

## 2. Create a certificate

The script signs in with `Connect-MgGraph -ClientId -TenantId -CertificateThumbprint`, so the certificate with its private key must be in the current user's certificate store on the machine that runs the script.

Windows (PowerShell 7):

```powershell
$cert = New-SelfSignedCertificate -Subject 'CN=HLE-Tickets-Connector' -CertStoreLocation 'Cert:\CurrentUser\My' `
    -KeyExportPolicy Exportable -KeySpec Signature -KeyLength 2048 -NotAfter (Get-Date).AddMonths(6)
Export-Certificate -Cert $cert -FilePath ./HLE-Tickets-Connector.cer
$cert.Thumbprint
```

macOS or Linux (PowerShell 7 and OpenSSL):

```powershell
openssl req -x509 -newkey rsa:2048 -nodes -keyout conn.key -out conn.cer -days 180 -subj '/CN=HLE-Tickets-Connector'
openssl pkcs12 -export -inkey conn.key -in conn.cer -out conn.pfx -passout pass:
$pfx = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new((Resolve-Path ./conn.pfx), '',
    [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::PersistKeySet)
$store = [System.Security.Cryptography.X509Certificates.X509Store]::new('My', 'CurrentUser')
$store.Open('ReadWrite'); $store.Add($pfx); $store.Close()
$pfx.Thumbprint
```

Keep the private key out of the repository. Delete `conn.key` and `conn.pfx` after importing.

## 3. Register the app (Microsoft Entra admin center)

1. Go to **Entra ID > App registrations > New registration**.
2. Name: `HLE-Tickets-Connector`. Supported account types: **Accounts in this organizational directory only**. No redirect URI. Select **Register**.
3. Copy the **Application (client) ID** and **Directory (tenant) ID** from the Overview page.
4. **Certificates & secrets > Certificates > Upload certificate**: upload the `.cer` file from section 2.
5. **API permissions > Add a permission > Microsoft Graph > Application permissions**: add `ExternalConnection.ReadWrite.OwnedBy` and `ExternalItem.ReadWrite.OwnedBy` (plus `Group.Read.All` and `User.Read.All` if you use default ACL resolution).
6. Select **Grant admin consent for <tenant>** and confirm that every row shows "Granted".

## 4. Run the script

```powershell
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
cd data/connector
./ingest-tickets.ps1 -TenantId <tenant id> -ClientId <app id> -CertificateThumbprint <thumbprint> -MaxItems 50   # smoke test
./ingest-tickets.ps1 -TenantId <tenant id> -ClientId <app id> -CertificateThumbprint <thumbprint>                # all 5,000
```

Schema registration takes about 5 to 15 minutes on the first run (the Graph reference for the schema PATCH says so); the script polls the operation every 30 seconds. Later runs skip registration and re-send items. Use `-SqlConnectionString` to read from the SQL database instead of `tickets.csv`, `-AddRefinableLater` for the Lab 7 break-it step, and `-Cleanup` to delete the connection.

## 5. Without a Global Administrator

Connector administration sits with the AI Administrator role, with Search Administrator for data sources (ADM-09). A Global Administrator can delegate app registration and consent for `ExternalItem.*` and `ExternalConnection.*` permissions to AI Administrators with a custom consent policy and role. The optional `Group.Read.All` and `User.Read.All` permissions are outside that delegation, which is another reason to use `-GroupMap`.

## 6. Documentation used

Paths are in the public documentation source repositories (checked 2026-09-30):

| Topic | Source file |
|---|---|
| Permission IDs and descriptions | microsoft-graph-docs-contrib `concepts/permissions-reference.md` |
| Create connection | microsoft-graph-docs-contrib `api-reference/v1.0/api/externalconnectors-external-post-connections.md` |
| Register or update schema (202 + Location, 5 to 15 minutes) | `api-reference/v1.0/api/externalconnectors-externalconnection-patch-schema.md` |
| Poll schema operation | `api-reference/v1.0/api/externalconnectors-connectionoperation-get.md`, `resources/externalconnectors-connectionoperation.md` |
| Put item | `api-reference/v1.0/api/externalconnectors-externalconnection-put-items.md` |
| ACL types and values | `api-reference/v1.0/resources/externalconnectors-acl.md` |
| Property attributes and labels | `api-reference/v1.0/resources/externalconnectors-property.md`, `concepts/connecting-external-content-manage-schema.md` |
| Connection states (draft, ready) | `concepts/connecting-external-content-manage-connections.md` |
| Delete connection | `api-reference/v1.0/api/externalconnectors-externalconnection-delete.md` |
| JSON batching (20 requests per batch) | `concepts/json-batching.md` |
| Certificate sign-in with Connect-MgGraph | `concepts/security-ediscovery-appauthsetup.md` (example command) |
| Delegating consent to AI Administrators | m365copilot-docs `docs/connector-admin-delegation.md` |
| Finding the connection ID | m365copilot-docs `docs/declarative-agent-capabilities-ids.md` |

On Microsoft Learn these are under `https://learn.microsoft.com/en-us/graph/` (for example `/graph/api/externalconnectors-externalconnection-patch-schema`) and `https://learn.microsoft.com/en-us/microsoft-365/copilot/extensibility/`.
