# Lab 11 solution files

Finished artifacts for [Lab 11: ALM and governance](../../labs/lab-11-alm-governance/README.md). No exported solution zip is committed: the zip is produced from your own `HLE-Dev` environment, because connection reference names and connector IDs differ in every tenant.

| File | What it is | How to use it |
|---|---|---|
| [`Invoke-HleSolutionDeployment.ps1`](Invoke-HleSolutionDeployment.ps1) | Fallback deployment (README Part D2). Exports `HLEHarbourlineOps` from `HLE-Dev` as unmanaged and managed zips with `pac solution export`, creates a deployment settings file with `pac solution create-settings`, refuses to import while values are empty or still placeholders (`-AllowIncompleteSettings` lets the first import into a target proceed with empty connection IDs only), then imports the managed zip with `pac solution import --settings-file --skip-lower-version`. Idempotent. `-Cleanup` deletes the solution from the target (never the source) and the local files; `-RemoveAuthProfiles` also deletes the `pac` auth profiles. | `./Invoke-HleSolutionDeployment.ps1 -SourceEnvironmentUrl <HLE-Dev URL> -TargetEnvironmentUrl <HLE-Test URL> -Stage Test` (run twice: the first run creates the settings file for you to fill). Supports `-WhatIf`. |
| [`deployment-settings.sample.json`](deployment-settings.sample.json) | The shape of a deployment settings file: `EnvironmentVariables` (`SchemaName`, `Value`) and `ConnectionReferences` (`LogicalName`, `ConnectionId`, `ConnectorId`). Placeholders in angle brackets. | Reference only. Generate the real file from your export (the script does this) and copy values across. Keep one file per stage. |
| [`Search-HleAgentAudit.ps1`](Search-HleAgentAudit.ps1) | Purview audit search (README Part G). Connects with ExchangeOnlineManagement, checks `UnifiedAuditLogIngestionEnabled`, pages through `Search-UnifiedAuditLog -RecordType CopilotInteraction -SessionCommand ReturnLargeSet`, parses `AuditData` and writes `AppIdentity`, `AgentId` and agent name to CSV. Read-only; `-Cleanup` deletes the CSV. | `./Search-HleAgentAudit.ps1 -AdminUpn admin@<domain> -UserIds hle-tech@<domain>` |
| [`Get-HleAgentInventory.ps1`](Get-HleAgentInventory.ps1) | Agent inventory and pending requests through `GET /beta/copilot/admin/catalog/packages` (PREVIEW, ADM-05), with `-PendingOnly` adding `$filter=requestStatus eq 'pending'`. Read-only. | `./Get-HleAgentInventory.ps1 -PendingOnly` (needs `CopilotPackages.Read.All`) |

All scripts are PowerShell 7, use `[CmdletBinding()]`, `Set-StrictMode -Version Latest`, `$ErrorActionPreference = 'Stop'`, take `-TenantUrl` and `-Prefix` (default `HLE`), and have comment-based help (`Get-Help ./Search-HleAgentAudit.ps1 -Full`). They were syntax-checked with the PowerShell parser; they were not run against a live tenant, and the `pac` script was exercised only against a stub `pac`.

## Things to confirm on Microsoft Learn

| Item | Why | Where |
|---|---|---|
| `Search-UnifiedAuditLog` record type `CopilotInteraction`, and the `AppIdentity` / `AgentId` field names inside `AuditData` | AUD-01 is SNIP. The script tries several paths (`AppIdentity`, `CopilotEventData.AppIdentity`, and so on); edit `$FieldPaths` if needed. | https://learn.microsoft.com/en-us/purview/audit-copilot and the `Search-UnifiedAuditLog` cmdlet reference |
| Paging (`SessionId`, `SessionCommand ReturnLargeSet`, `ResultSize` 5000) and the maximum search window | Standard cmdlet behavior, not re-checked for this course | `Search-UnifiedAuditLog` cmdlet reference |
| Package management API version (`beta` or `v1.0`) and preview status | The API reference shows both pivots; the admin center page calls it preview (ADM-05) | https://learn.microsoft.com/en-us/microsoft-365/admin/manage/agent-registry |
| `pac` output format of `pac solution list` | The script reads the version from the line that contains the solution unique name | `pac solution list --help` |
| Environment variable syntax in a custom connector | README step 11 | https://learn.microsoft.com/en-us/connectors/custom-connectors/environment-variables |

## Deploying through the pipeline instead

Pipelines (README Part D1) need no files from this folder: they export, store and deploy the artifact themselves and ask for connections and environment variable values on the deployment screen. The CLI equivalent is `pac pipeline list` and `pac pipeline deploy` (see the README).
