# Site map

Harbourline Energy Co. uses exactly two SharePoint sites. Each local folder under `data/sharepoint/` maps to one library. `setup/02-provision-sites.ps1` creates the sites and libraries, and `setup/03-upload-content.ps1` uploads the files.

Site URLs use the prefix parameter (default `HLE`): `https://<tenant>.sharepoint.com/sites/<Prefix>-Harbourline-Hub` and `.../sites/<Prefix>-Harbourline-Operations`.

## Harbourline-Hub (communication site, owner: learner)

| Library or list | Local folder | Contents | Permissions | Labs |
|---|---|---|---|---|
| Getting-Started | `data/sharepoint/Harbourline-Hub/Getting-Started/` | 5 clean Word documents: Welcome guide, Vacation policy, IT help desk FAQ, Office locations, Benefits at a glance. Also `data/sharepoint/getting-started.zip` for direct upload. | Inherited. All employees read. | 1 |
| HR-Policies | `data/sharepoint/Harbourline-Hub/HR-Policies/` | 18 policy documents (docx and pdf). Includes two conflicting leave policy versions, one image-only scanned PDF, one oversized file (generated at setup), one encrypted-label file. | Inherited. All employees read. | 2, 3 |
| HR-Policies/Restricted | `data/sharepoint/Harbourline-Hub/HR-Policies/Restricted/` | 3 confidential HR documents. | Broken inheritance. `<Prefix>-HR` group only, plus site owner. | 3 |
| Finance | `data/sharepoint/Harbourline-Hub/Finance/` | Expense policy, approval matrix (docx table and xlsx), corporate card guidelines, capital project approval. | `<Prefix>-Finance` edit. All employees read. | 2, 3, 4 |
| Vendors (list) | `data/sharepoint/Harbourline-Hub/Vendors.csv` | 2,600 vendor records. Exceeds the 2,048-row query window documented for Copilot Studio list knowledge. | All employees read. | 3, 4 |

## Harbourline-Operations (team site with Microsoft 365 group, guest access enabled)

| Library | Local folder | Contents | Permissions | Labs |
|---|---|---|---|---|
| Procedures | `data/sharepoint/Harbourline-Operations/Procedures/` | Outage response, storm restoration, lockout/tagout safety manual, substation switching, vegetation management, crew briefing deck (key values only in images), transformer equipment specs (multi-sheet xlsx with merged cells). | Group members, including the guest persona. | 3, 9 |
| Procedures/Incoming | created by setup, empty | Drop target for Lab 9 event trigger. Sample drops in `data/sharepoint/lab-09-drops/`. | Group members. | 9 |
| Archive-Bulk | generated at setup by `tools/generate-data/generate_archive_bulk.py` | 1,200 small files in 12 year/month folders. | Group members. | 2, 3 |

## Personas and groups

| Persona | Account | Copilot license | Groups | Sites |
|---|---|---|---|---|
| Learner | existing admin account | Yes | all | Owner of both |
| Priya Nandakumar, HR Manager | `<prefix>-hr@<domain>` | Yes | `<Prefix>-HR`, `<Prefix>-AllStaff` | Hub member |
| Marcus Delaney, Field Technician | `<prefix>-tech@<domain>` | Yes | `<Prefix>-Ops-Ontario`, `<Prefix>-AllStaff` | Hub visitor, Operations member |
| Sofia Brennan, Finance Analyst | `<prefix>-fin@<domain>` | Yes | `<Prefix>-Finance`, `<Prefix>-AllStaff` | Hub member |
| Tom Whitfield, Operations Clerk | `<prefix>-nolic@<domain>` | No | `<Prefix>-Ops-US`, `<Prefix>-AllStaff` | Hub visitor, Operations member |
| Guest contractor | external address (parameter `-GuestEmail`) | No | Operations Microsoft 365 group member only | Operations only |
