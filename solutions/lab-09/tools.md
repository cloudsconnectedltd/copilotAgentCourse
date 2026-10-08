# HLE Field Report Triage: tool definitions

Add each tool in Copilot Studio (agent > Tools > Add a tool; UI labels may differ). With generative orchestration the agent chooses tools from their **name** and **description**, so paste both exactly. Inputs marked "agent fills" are left for the orchestrator to fill from the conversation (the trigger payload and earlier tool outputs); inputs with a fixed value are set in the tool's input settings.

Choice values come from `data/dataverse/schema.md` section 4. Table and column logical names assume the default prefix `hle`. If you used another prefix, replace `hle_` throughout.

## 1. HLE Read Field Report (agent flow)

| Item | Value |
|---|---|
| Type | Agent flow, see `flow-hle-read-field-report.md` |
| Description | `Reads a Harbourline field report Word file from SharePoint and returns its fields. Call this first for every triggered file, with the file identifier from the trigger.` |
| Input | `FileIdentifier` (text, agent fills) |
| Outputs | `ReportId`, `ReportDate` (yyyy-MM-dd), `Region`, `CrewId`, `CrewLeader`, `AssetId`, `AssetDescription`, `Issue`, `Severity`, `RecommendedAction`, `CrewNotes`, `ReadStatus` (OK or an error message) |

## 2. Find asset by number

| Item | Value |
|---|---|
| Type | Microsoft Dataverse connector, **List rows** (environment: current) |
| Description | `Looks up one Harbourline asset in Dataverse by its asset number, for example TX-ON-10423. Returns site, region, condition score, install year and operational status.` |
| Table name | Assets (`hle_asset`) |
| Filter rows | `hle_assetnumber eq '{AssetId}'` (AssetId: agent fills) |
| Select columns | `hle_assetid,hle_assetnumber,hle_assettype,hle_region,hle_sitename,hle_city,hle_conditionscore,hle_installyear,hle_operationalstatus,hle_lastinspectiondate` |
| Row count | 1 |

## 3. Find crew by code

| Item | Value |
|---|---|
| Type | Dataverse, **List rows** |
| Description | `Looks up one Harbourline crew by crew code, for example CREW-ON-03. Returns the crew row id, name, lead and base depot.` |
| Table name | Crews (`hle_crew`) |
| Filter rows | `hle_crewcode eq '{CrewId}'` |
| Select columns | `hle_crewid,hle_crewcode,hle_crewname,hle_crewlead,hle_basedepot` |
| Row count | 1 |

## 4. Find work order by number

| Item | Value |
|---|---|
| Type | Dataverse, **List rows** |
| Description | `Checks whether a work order with a given work order number already exists. Used as the idempotency check before creating a work order.` |
| Table name | Work Orders (`hle_workorder`) |
| Filter rows | `hle_workordernumber eq '{WorkOrderNumber}'` |
| Select columns | `hle_workorderid,hle_workordernumber,hle_status` |
| Row count | 1 |

To also report "open work order already existed for this asset" in the summary, you can add a second List rows tool `Find open work orders for asset` with filter `_hle_asset_value eq {AssetRowId} and (hle_status eq 714800100 or hle_status eq 714800101 or hle_status eq 714800102 or hle_status eq 714800103)`. Optional; it adds one agent action per run (C-09-c).

## 5. Create work order

| Item | Value |
|---|---|
| Type | Dataverse, **Add a new row** |
| Description | `Creates one Harbourline work order in Dataverse from a triaged field report. Call only after the asset lookup succeeded and no work order with the same number exists.` |
| Table name | Work Orders (`hle_workorder`) |

| Column | Value | Notes |
|---|---|---|
| Work Order Number (`hle_workordernumber`) | agent fills: `WO-<ReportId>` | Idempotency key |
| Title (`hle_title`) | agent fills | Max 200 characters (schema.md 3.4) |
| Description (`hle_description`) | agent fills | Max 4,000 characters |
| Work Type (`hle_worktype`) | agent fills, one of 714800500 to 714800505 | Emergency Restoration 714800504, Replacement 714800503, Corrective Repair 714800502, Vegetation Clearance 714800505 |
| Priority (`hle_priority`) | agent fills | Emergency 714800000, High 714800001, Routine 714800002 |
| Status (`hle_status`) | fixed: 714800100 (New) | |
| Region (`hle_region`) | agent fills from the asset row | Ontario 714800300, New York 714800301, Ohio 714800302 |
| Asset (lookup) | agent fills: `hle_assets(<hle_assetid from tool 2>)` | Entity set name is normally `hle_assets`; check it in the table's properties (schema.md 2) |
| Assigned Crew (lookup) | agent fills: `hle_crews(<hle_crewid from tool 3>)`, or empty | |
| Opened On (`hle_openedon`) | agent fills: ReportDate | Date only |
| Due Date (`hle_duedate`) | agent fills | Emergency +1, High +7, Routine +30 days |
| Currency (`hle_currency`) | agent fills | CAD for Ontario, USD for New York and Ohio |

If the orchestrator struggles to fill choice numbers, wrap this action in a small agent flow that takes text labels ("High", "Ohio") and maps them with a Switch. That is more reliable and easier to test.

## 6. Post escalation card

| Item | Value |
|---|---|
| Type | Microsoft Teams connector, **Post card in a chat or channel** |
| Description | `Posts a Critical field report escalation card to the duty operator in Teams. Use only for Critical reports.` |
| Post as | Flow bot (fixed) |
| Post in | Chat with Flow bot (fixed) |
| Recipient | the learner's UPN (fixed) |
| Adaptive Card | `escalation-card.json`, with the `${...}` placeholders filled by the agent |

Because the trigger runs as the maker (CS-A08), the card arrives from the Flow bot on behalf of the maker's connection, whoever dropped the file.

## 7. Send email

| Item | Value |
|---|---|
| Type | Office 365 Outlook connector, **Send an email (V2)** |
| Description | `Sends an email about a field report: either a Critical escalation, or a request to the records team to confirm a missing asset ID.` |
| To | learner UPN (fixed) |
| CC | `<prefix>-nolic@<domain>` (Tom Whitfield, Operations Clerk, Ops-US) (fixed) |
| Subject | agent fills |
| Body | agent fills, following `escalation-email.txt` |
| Importance | agent fills: High for Critical, Normal otherwise |

## 8. Write triage summary

| Item | Value |
|---|---|
| Type | SharePoint connector, **Create file** |
| Description | `Writes the triage summary text file for one field report into Procedures/Triaged. Call once at the end of every run that passed the file filter.` |
| Site Address | `https://<tenant>.sharepoint.com/sites/<Prefix>-Harbourline-Operations` (fixed) |
| Folder Path | `/Procedures/Triaged` (fixed; never `/Procedures/Incoming`, see C-09-d) |
| File Name | agent fills: `Triage-<ReportId>.txt` |
| File Content | agent fills |

Fixing the folder path as a constant, rather than letting the agent fill it, is part of the C-09-d fix: the model cannot be talked into writing to `Incoming`.
