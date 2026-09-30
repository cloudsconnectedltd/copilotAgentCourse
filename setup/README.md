# Tenant setup scripts

These PowerShell 7 scripts build the Harbourline Energy Co. course tenant described in `reference/site-map.md` and `PLAN.md` section 3. Every script:

- takes `-TenantUrl` (for example `https://contoso.sharepoint.com`) and `-Prefix` (default `HLE`)
- is idempotent: it checks before it creates, so you can re-run it after a failure
- supports `-WhatIf` and `-Confirm` (`[CmdletBinding(SupportsShouldProcess)]`)
- supports `-Cleanup`, which reverses only what that script created
- uses `Set-StrictMode -Version Latest` and `$ErrorActionPreference = 'Stop'`
- has comment-based help: `Get-Help ./setup/02-provision-sites.ps1 -Full`

Shared code lives in `common.psm1` (logging, module checks, sign-in helpers, name derivation, idempotency helpers).

## Run order

| Step | Script | What it does | Signs in with | Approximate runtime (estimate) |
|---|---|---|---|---|
| 0 | `00-prereqs-check.ps1` | Read-only checks: Copilot SKUs and free seats, your directory roles, SharePoint sharing and label settings, Restricted SharePoint Search, Teams custom app upload. Prints a PASS / WARN / MANUAL table and a manual checklist. | Graph, PnP, MicrosoftTeams (optional) | 2 to 5 min |
| 1 | `01-provision-users.ps1` | Security groups, four persona users, licenses, learner group membership, guest invitation. | Graph | 3 to 10 min |
| 2 | `02-provision-sites.ps1` | Hub communication site, Operations team site with Microsoft 365 group, libraries, Vendors list, folders, permissions, guest sharing, Operations group members. | PnP | 10 to 25 min (site provisioning) |
| 3 | `03-upload-content.ps1` | Runs the Python generators if needed, uploads all library content, imports 2,600 Vendors rows. | PnP | 20 to 60 min (about 1,200 Archive-Bulk files) |
| 4 | `04-apply-labels.ps1` | Encrypting sensitivity label, label policy, label applied to `Compensation-Bands-2025.docx`. | PnP, Security and Compliance PowerShell | 5 min, plus label propagation time |
| 99 | `99-teardown.ps1` | Runs 04, 03, 02, 01 with `-Cleanup` after one confirmation. Lists lab `cleanup.md` files. | all of the above | 10 to 30 min |

Runtimes are estimates for planning, not measured values. They depend on tenant load and network speed.

Lab 1 needs none of this. Labs 2 onward need steps 0 to 3; Lab 3 also needs step 4.

```powershell
$t   = 'https://contoso.sharepoint.com'
$app = '11111111-2222-3333-4444-555555555555'   # your PnP app registration (see below)

./setup/00-prereqs-check.ps1   -TenantUrl $t -ClientId $app
./setup/01-provision-users.ps1 -TenantUrl $t -BaseSkuPartNumber SPE_E5 -CopilotSkuPartNumber <from 00 output> -GuestEmail someone@outlook.com
./setup/02-provision-sites.ps1 -TenantUrl $t -ClientId $app -GuestEmail someone@outlook.com
./setup/03-upload-content.ps1  -TenantUrl $t -ClientId $app
./setup/04-apply-labels.ps1    -TenantUrl $t -ClientId $app

# Preview, then remove everything
./setup/99-teardown.ps1 -TenantUrl $t -ClientId $app -GuestEmail someone@outlook.com -WhatIf
./setup/99-teardown.ps1 -TenantUrl $t -ClientId $app -GuestEmail someone@outlook.com
```

Run each script in a fresh `pwsh` session if you see assembly or token errors after mixing modules (see Known uncertainties).

## Required modules

| Module | Used by | Install |
|---|---|---|
| PnP.PowerShell (check the PnP.PowerShell release notes for the minimum PowerShell 7 version) | 00, 02, 03, 04 | `Install-Module PnP.PowerShell -Scope CurrentUser` |
| Microsoft.Graph.Authentication, .Users, .Users.Actions, .Groups, .Identity.SignIns, .Identity.DirectoryManagement (2.x) | 00, 01 | `Install-Module Microsoft.Graph -Scope CurrentUser` |
| ExchangeOnlineManagement (3.x) | 04 | `Install-Module ExchangeOnlineManagement -Scope CurrentUser` |
| MicrosoftTeams (optional) | 00 | `Install-Module MicrosoftTeams -Scope CurrentUser` |
| Python 3 with python-docx, openpyxl, reportlab | 03 (generators) | see `tools/generate-data/` |

`Assert-Module` in `common.psm1` stops with an install hint if a module is missing.

## Parameters

| Parameter | Scripts | Default | Notes |
|---|---|---|---|
| `-TenantUrl` | all | required | Root SharePoint URL. The admin URL (`https://<tenant>-admin.sharepoint.com`) and `<tenant>.onmicrosoft.com` are derived from it. |
| `-Prefix` | all | `HLE` | 2 to 10 letters or digits, starting with a letter. Used in site URLs, group names, persona UPNs (lower case), label names and the cleanup tag `<Prefix>-CourseSetup`. |
| `-Cleanup` | all | off | Reverses that script. 00 treats it as a no-op. |
| `-ClientId` | 00, 02, 03, 04, 99 | `$env:ENTRAID_APP_ID` | Your PnP app registration. Required by 02, 03, 04, 99. Optional for 00 (SharePoint checks become MANUAL without it). |
| `-Domain` | 01, 02, 04, 99 | default verified domain | UPN suffix for personas. |
| `-GuestEmail` | 01, 02, 99 | none | External address for the guest contractor. Skipped with a warning when missing. |
| `-UsageLocation` | 01 | `CA` | Set on new users before licensing. |
| `-BaseSkuPartNumber` | 01 | none | Base plan for personas. Take it from the SKU table printed by 00. |
| `-CopilotSkuPartNumber` | 01 | auto if exactly one SKU contains "Copilot" (not "Studio") | Assigned to the hr, tech and fin personas and the learner. Not to nolic or the guest. |
| `-PasswordFile` | 01 | `~/.harbourline-course/<Prefix>-initial-passwords.csv` | New persona passwords are appended here with owner-only permissions. They are never printed. |
| `-GraphClientId` | 00, 01, 99 | Microsoft Graph Command Line Tools | Optional app for `Connect-MgGraph`. |
| `-PurgeDeleted` | 01, 99 | off | With cleanup, also hard-deletes users and groups from Entra deleted items. |
| `-Force` | 02, 99 | off | 02: purge deleted sites and the group without prompting. 99: skip the confirmation prompt and purge. |
| `-PythonPath`, `-SkipGenerators`, `-BatchSize` | 03 | `python3`, off, `100` | Generator and list import controls. |
| `-UserPrincipalName`, `-FileName`, `-SkipAssign` | 04 | none, `Compensation-Bands-2025.docx`, off | Compliance sign-in hint, file to label, create label without applying it. |
| `-RequiredCopilotSeats`, `-ReportPath` | 00 | `4`, none | Seat threshold for PASS; optional CSV export. |

## Entra app registration for PnP.PowerShell

PnP.PowerShell no longer provides a shared multi-tenant app for interactive sign-in, so you must register your own app and pass its client ID with `-ClientId` (or set `$env:ENTRAID_APP_ID`).

Option A, with PnP.PowerShell (needs rights to register apps and grant admin consent):

```powershell
Register-PnPEntraIDAppForInteractiveLogin -ApplicationName 'HLE Course Setup' -Tenant contoso.onmicrosoft.com -Interactive
```

Then add the permissions below in the Entra admin center and grant admin consent.

Option B, in the Entra admin center: App registrations > New registration > single tenant > Redirect URI type "Public client/native (mobile and desktop)" with `http://localhost`. Under Authentication, allow public client flows. Add the delegated permissions below and grant admin consent.

| API | Delegated permission | Why |
|---|---|---|
| SharePoint | `AllSites.FullControl` | Create sites, libraries, lists, permissions, upload files |
| Microsoft Graph | `User.Read.All` | Resolve personas and the guest |
| Microsoft Graph | `Group.ReadWrite.All` | Find course groups, add Operations group members, delete the group in cleanup |
| Microsoft Graph | `Directory.Read.All` | Default verified domain |
| Microsoft Graph | `Sites.Read.All` | Resolve the Hub site and HR-Policies drive (04) |
| Microsoft Graph | `Files.ReadWrite.All` | `assignSensitivityLabel` and `extractSensitivityLabels` (04) |

The permissions are delegated, so the signed-in admin's roles still apply. You also need these directory roles (or Global Administrator): SharePoint Administrator (00, 02, 03, 04), User Administrator and License Administrator (01), Compliance Administrator or Information Protection Administrator (04), Teams Administrator (00 Teams check). PLAN.md section 3 lists the roles used by later labs.

`01-provision-users.ps1` and the Graph part of `00` use `Connect-MgGraph` with these delegated scopes, consented at first sign-in: `User.ReadWrite.All`, `Group.ReadWrite.All`, `Directory.ReadWrite.All`, `User.Invite.All`, `Organization.Read.All` (01) and `Organization.Read.All`, `Directory.Read.All` (00).

`assignSensitivityLabel` is a metered (protected) Microsoft Graph API. To call it from your PnP app, the app must be set up for metered API billing against an Azure subscription (see "Metered APIs and services in Microsoft Graph" on Microsoft Learn). Without that, 04 prints manual steps to apply the label in the SharePoint UI, which works just as well for the lab.

## What -Cleanup removes, and how it avoids other objects

| Script | Removes | Safety check |
|---|---|---|
| 01 | Persona users, guest, the six `<Prefix>-*` groups | Users must carry `extensionAttribute15 = <Prefix>-CourseSetup`; groups must have a description starting with `[<Prefix>-CourseSetup]`. Untagged objects with the same names are left alone with a warning. The learner's licenses are not touched. |
| 02 | Hub site; Operations Microsoft 365 group (its site follows) | Exact URLs and alias derived from `-Prefix`. Purge from recycle bins only with `-Force` or after a prompt. |
| 03 | Files that match local file names, non-structural subfolders that came from local folders, Vendors items whose VendorId is in `Vendors.csv` | Matches local content only. Restricted and Incoming folders stay. |
| 04 | Label policy and label | Names derived from `-Prefix`. The label on the file is not removed by API; 03 cleanup deletes the file. |

## Content mapping (03)

| Local folder | Site / library |
|---|---|
| `data/sharepoint/Harbourline-Hub/Getting-Started/` | Hub / Getting-Started |
| `data/sharepoint/Harbourline-Hub/HR-Policies/` (including `Restricted/`) | Hub / HR-Policies |
| `data/sharepoint/Harbourline-Hub/Finance/` | Hub / Finance |
| `data/sharepoint/Harbourline-Hub/Vendors.csv` | Hub / Vendors list |
| `data/sharepoint/Harbourline-Operations/Procedures/` | Operations / Procedures |
| `data/sharepoint/Harbourline-Operations/Archive-Bulk/` (generated) | Operations / Archive-Bulk |
| `data/sharepoint/lab-09-drops/` | not uploaded (Lab 9 drops these into Procedures/Incoming) |
| `data/sharepoint/getting-started.zip` | not uploaded (Lab 1 direct upload) |

Subfolders are preserved. A file is skipped when a file with the same name and size already exists in the target folder. Hidden files (names starting with `.`) and a `README.md` at a library root are not uploaded.

## Known uncertainties

These scripts could not be run against a live tenant while they were written (no module installs were possible; each script was only parsed with the PowerShell 7.4 parser). Items below rely on cmdlet or API behavior that should be confirmed on the first real run.

1. **PnP app registration helper.** `Register-PnPEntraIDAppForInteractiveLogin` parameter names (for example `-Interactive`, and whether it adds Graph permissions for you) vary between PnP versions. Option B (portal) is the reliable path.
2. **Restricted SharePoint Search cmdlet.** 00 uses `Get-PnPTenantRestrictedSearchMode` only if `Get-Command` finds it, and interprets its output by text match on "Enabled". Otherwise it prints a MANUAL check with the SharePoint Online Management Shell cmdlet `Get-SPOTenantRestrictedSearchMode`.
3. **Copilot SKU detection.** SKUs are matched by `skuPartNumber` containing "Copilot", and those containing "Studio" are treated as Copilot Studio. No SKU GUIDs are hardcoded. Confirm the right part number in the 00 table and pass `-CopilotSkuPartNumber` explicitly if more than one matches.
4. **Role check.** 00 reads `me/transitiveMemberOf/microsoft.graph.directoryRole`, which shows active role assignments only. PIM-eligible roles that are not activated show as WARN.
5. **Tagging users with `onPremisesExtensionAttributes.extensionAttribute15`.** Setting it on cloud-only users at create time (and on invited guests afterwards) is expected to work through Graph. If your tenant syncs from on-premises AD, or the attribute is already used, cleanup will skip untagged users; remove them by hand. The guest search by tag in 01 cleanup uses an advanced query (`ConsistencyLevel: eventual`, `$count=true`); pass `-GuestEmail` if it fails.
6. **Invoke-PnPGraphMethod.** 02 and 04 send Graph calls through `Invoke-PnPGraphMethod` with relative `v1.0/...` URLs, and follow `@odata.nextLink` by passing the absolute URL back. Confirm both work in your PnP version. If not, connect Microsoft Graph and call `Set-CourseGraphTransport -Mg` before the Graph steps.
7. **Mixing modules in one session.** PnP.PowerShell, Microsoft.Graph and ExchangeOnlineManagement ship their own identity libraries. Loading more than one in the same session has caused assembly conflicts in some versions. 00 loads both Graph and PnP; 04 loads PnP and ExchangeOnlineManagement; 99 runs all scripts in one session. If you hit such an error, run each script in a fresh `pwsh` session.
8. **Group claims in SharePoint.** Entra security groups are added to SharePoint groups and item permissions using the claim `c:0t.c|tenant|<group object id>` with `Add-PnPGroupMember -LoginName` and `Set-PnPListItemPermission -User` / `Set-PnPListPermission -User`. This is the standard claim format, but it is not tested here.
9. **Permission level names.** `Full Control`, `Edit` and `Read` are the English names. On a site created in another language, change them in 02.
10. **Restricted folder reset.** 02 re-applies the Restricted folder permissions on every run with `Set-PnPListItemPermission -ClearExisting` (Owners Full Control, then HR Edit). Any manual permission you add to that folder is removed on re-run.
11. **Operations site deletion.** 02 cleanup deletes the Microsoft 365 group; SharePoint then deletes the group site asynchronously. Purging the site from the recycle bin (`Remove-PnPTenantDeletedSite`) may not succeed until that finishes. The script waits up to 10 minutes and then asks you to re-run.
12. **Site creation cmdlets.** `New-PnPSite -Type TeamSite -Alias` creates the group site at `/sites/<alias>`. If the alias is taken, SharePoint may pick another URL; 02 warns if the returned URL differs.
13. **File size comparison.** 03 compares local and remote sizes from `Get-PnPFolderItem`. If the size property is not loaded in your PnP version, a same-name file is treated as already uploaded.
14. **Generator command lines.** 03 runs `generate_oversized_handbook.py --out <path to Employee-Handbook-Full.docx>` and `generate_archive_bulk.py --out <Archive-Bulk folder>`. If a generator expects a folder (or a file) instead, adjust `Invoke-Generator` calls in 03. 03 warns if the handbook is missing afterwards.
15. **Vendors list types.** ContractValue is created as Number, RenewalDate as Date only, Category, Region, Status and RiskRating as Choice (values read from the CSV, fill-in allowed), all other columns as single line of text. Dates are parsed with the invariant culture (`yyyy-MM-dd` in the current CSV).
16. **Label encryption parameters.** 04 uses `New-Label` with `-EncryptionEnabled`, `-EncryptionProtectionType Template`, `-EncryptionRightsDefinitions`, `-EncryptionContentExpiredOnDateInDaysOrNever Never` and `-EncryptionOfflineAccessDays 7`. The co-author rights string is `VIEW,VIEWRIGHTSDATA,DOCEDIT,EDIT,PRINT,EXTRACT,REPLY,REPLYALL,FORWARD,OBJMODEL`. Confirm these against the current `New-Label` reference.
17. **Rights for a non-mail-enabled group.** Encryption rights need email addresses. The `<Prefix>-HR` group from 01 is a security group without email, so 04 grants rights to its current members by UPN and warns. Re-run 04 after changing HR membership, or replace the group with a mail-enabled security group.
18. **Label id for Graph.** 04 passes the label's `ImmutableId` (falling back to `Guid`) from `Get-Label` as `sensitivityLabelId`.
19. **Label propagation.** No propagation time is stated here because no Microsoft Learn source was checked for it. Check Microsoft Learn for current guidance, and re-run 04 if the assign step fails right after creating the label.
20. **extractSensitivityLabels.** 04 calls `POST /drives/{id}/items/{id}/extractSensitivityLabels` to skip files that are already labeled. If that call fails, the script simply tries to assign again.
21. **Removing the label from the file.** No API call is used to remove the label; 03 cleanup deletes the file instead, and 04 cleanup prints the manual UI step.
22. **Tenant setting for labels.** 00 and 04 read `EnableAIPIntegration` from `Get-PnPTenant` as the switch for sensitivity labels on Office files in SharePoint and OneDrive. The Purview portal location of the same switch is not stated precisely; check Microsoft Learn.
