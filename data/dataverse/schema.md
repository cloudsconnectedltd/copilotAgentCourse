# Harbourline Dataverse schema: assets, work orders and crews

| Item | Value |
|---|---|
| Owner | Harbourline Operations Systems (course data) |
| Used in | Lab 4 (Dataverse knowledge, topics), Lab 5 (flows), Lab 10 (multi-agent), Lab 11 (ALM) |
| Seed files | `Assets.csv` (1,200 rows), `WorkOrders.csv` (3,000 rows), `Crews.csv` (60 rows) |
| Load script | `import-dataverse.ps1` (Dataverse Web API, idempotent, `-Cleanup` supported) |
| Generator | `tools/generate-data/build_dataverse.py` (fixed seed 20260930) |
| Data as of | 2026-09-30 |

## 1. Naming and prefix

All names below use the default course prefix `HLE`, which becomes the Dataverse customization prefix `hle`. If you run `import-dataverse.ps1 -Prefix ABC`, every schema name changes from `hle_` to `abc_` (for example `abc_WorkOrder`). The script creates, or reuses, a publisher with that customization prefix and an unmanaged solution named `<Prefix>HarbourlineOps` (default `HLEHarbourlineOps`), so Lab 11 can export the tables as a solution.

| Setting | Value |
|---|---|
| Publisher unique name | `<prefix>harbourline` (default `hleharbourline`) |
| Publisher display name | Harbourline Energy Co. (course) |
| Customization prefix | `hle` |
| Choice value prefix | `71480` (so option values start at 714800000) |
| Solution unique name | `HLEHarbourlineOps` |
| Solution version | 1.0.0.0 |

If a publisher with customization prefix `hle` already exists in the environment, the script reuses it and warns if its choice value prefix is not 71480. The option values in this document are always sent explicitly, so they stay the same either way.

## 2. Tables

| Schema name | Logical name | Entity set (Web API) | Display name | Plural | Ownership | Primary name column | Rows |
|---|---|---|---|---|---|---|---|
| `hle_Asset` | `hle_asset` | read from metadata (normally `hle_assets`) | Asset | Assets | User or team | `hle_AssetNumber` | 1,200 |
| `hle_Crew` | `hle_crew` | read from metadata (normally `hle_crews`) | Crew | Crews | User or team | `hle_CrewCode` | 60 |
| `hle_WorkOrder` | `hle_workorder` | read from metadata (normally `hle_workorders`) | Work Order | Work Orders | User or team | `hle_WorkOrderNumber` | 3,000 |

The primary name column of each table holds the business key (for example `TX-ON-10423`, `CRW-OH-07`, `WO-2026-01127`). That is the value Copilot Studio shows in citations and the value users type, so it is deliberately the key rather than a free-text name.

### 2.1 Row identity (how the import stays idempotent)

The import script does not use alternate keys. It derives each row's primary key GUID from the business key (an MD5 hash of `<logicalname>|<business key>`, formatted as a GUID) and writes every row with `PATCH <entityset>(<guid>)`. In the Dataverse Web API a `PATCH` to a row that does not exist creates it with that GUID, and a `PATCH` to an existing row updates it (upsert). Running the script twice leaves exactly the same rows. Lookups are bound to the same derived GUIDs, so work orders always point at the right asset and crew.

## 3. Columns

Types below are the Web API metadata types. "Choice" means a local choice column (`PicklistAttributeMetadata`). All date columns are date only (`DateTimeAttributeMetadata`, `Format: DateOnly`).

### 3.1 hle_Asset

| Schema name | Display name | Type | Size or range | CSV column | Notes |
|---|---|---|---|---|---|
| `hle_AssetNumber` | Asset Number | Text (primary name) | 20 | AssetNumber | Pattern `<TYPE>-<REGION>-<5 digits>`, for example `TX-ON-10423`, `POLE-NY-20017`, `SW-OH-30110`. Ontario numbers are 10001 to 19999, New York 20001 to 29999, Ohio 30001 to 39999. |
| `hle_AssetType` | Asset Type | Choice | see 4.3 | AssetType | Pole, Transformer, Switch, Breaker, Recloser, Voltage Regulator |
| `hle_Region` | Region | Choice | see 4.4 | Region | Ontario, New York, Ohio |
| `hle_SiteCode` | Site Code | Text | 10 | SiteCode | For example `BAYTS` |
| `hle_SiteName` | Site | Text | 100 | SiteName | For example Bayview Transformer Station |
| `hle_City` | City | Text | 60 | City | |
| `hle_Manufacturer` | Manufacturer | Text | 100 | Manufacturer | Fictional manufacturers |
| `hle_Rating` | Rating | Text | 60 | Rating | For example `10 MVA station`, `40 ft Class 3 wood` |
| `hle_InstallYear` | Install Year | Whole number | 1900 to 2100 | InstallYear | |
| `hle_ConditionScore` | Condition Score | Whole number | 0 to 100 | ConditionScore | 100 is as new. Below 30 is the Harbourline "poor condition" threshold used in the labs. |
| `hle_OperationalStatus` | Operational Status | Choice | see 4.5 | OperationalStatus | In Service, Out of Service, Retired |
| `hle_LastInspectionDate` | Last Inspection | Date only | | LastInspectionDate | |

### 3.2 hle_Crew

| Schema name | Display name | Type | Size or range | CSV column | Notes |
|---|---|---|---|---|---|
| `hle_CrewCode` | Crew Code | Text (primary name) | 20 | CrewCode | `CRW-<REGION>-<2 digits>`: 24 Ontario, 18 New York, 18 Ohio |
| `hle_CrewName` | Crew Name | Text | 100 | CrewName | For example Bayview Substation Maintenance Crew A |
| `hle_Region` | Region | Choice | see 4.4 | Region | |
| `hle_HomeBase` | Home Base | Text | 100 | HomeBase | Site name |
| `hle_Specialty` | Specialty | Text | 60 | Specialty | Overhead Lines, Underground Cable, Substation Maintenance, Protection and Control, Vegetation Management, Storm Response |
| `hle_CrewLead` | Crew Lead | Text | 100 | CrewLead | Fictional names |
| `hle_CrewSize` | Crew Size | Whole number | 1 to 20 | CrewSize | |
| `hle_Certifications` | Certifications | Multiple lines of text | 2,000 | Certifications | Semicolon separated list |

### 3.3 hle_WorkOrder

| Schema name | Display name | Type | Size or range | CSV column | Notes |
|---|---|---|---|---|---|
| `hle_WorkOrderNumber` | Work Order Number | Text (primary name) | 20 | WorkOrderNumber | `WO-<year opened>-<5 digit sequence>` |
| `hle_Title` | Title | Text | 200 | Title | Uses field abbreviations (TX, SW, OH, ROW). See section 6. |
| `hle_Description` | Description | Multiple lines of text | 4,000 | Description | |
| `hle_WorkType` | Work Type | Choice | see 4.6 | WorkType | |
| `hle_Priority` | Priority | Choice | see 4.1 | Priority | Emergency, High, Routine, Deferred |
| `hle_Status` | Status | Choice | see 4.2 | Status | New, Scheduled, In Progress, On Hold, Completed, Cancelled |
| `hle_Region` | Region | Choice | see 4.4 | Region | Region of the asset (not of the crew) |
| `hle_Asset` | Asset | Lookup to `hle_Asset` | | AssetNumber | Relationship `hle_Asset_WorkOrder` |
| `hle_Crew` | Assigned Crew | Lookup to `hle_Crew` | | CrewCode | Relationship `hle_Crew_WorkOrder` |
| `hle_OpenedOn` | Opened On | Date only | | OpenedOn | 2024-10-01 to 2026-09-30 |
| `hle_DueDate` | Due Date | Date only | | DueDate | Emergency +1 day, High +7, Routine +30, Deferred +120 (planted rows can differ) |
| `hle_CompletedOn` | Completed On | Date only | | CompletedOn | Empty unless Status is Completed |
| `hle_EstimatedHours` | Estimated Hours | Decimal | 0 to 10,000, 2 decimals | EstimatedHours | |
| `hle_ActualHours` | Actual Hours | Decimal | 0 to 10,000, 2 decimals | ActualHours | Empty unless Completed |
| `hle_EstimatedCost` | Estimated Cost | Decimal | 0 to 100,000,000, 2 decimals | EstimatedCost | In local currency, see `hle_Currency`. Decimal, not Currency type, so no exchange rate is applied. |
| `hle_Currency` | Currency | Text | 3 | Currency | `CAD` for Ontario assets, `USD` for New York and Ohio assets |

## 4. Choice columns and option values

The option values are fixed. Flows in Lab 5 and topics in Lab 4 compare against these numbers.

### 4.1 hle_Priority (work order)

| Label | Value | Meaning at Harbourline |
|---|---|---|
| Emergency | 714800000 | Public safety or customers out now. Crew dispatched immediately. Due next day. |
| High | 714800001 | Risk of failure or regulatory exposure. Due within 7 days. |
| Routine | 714800002 | Planned or cyclic work. Due within 30 days. |
| Deferred | 714800003 | Approved to wait, usually for an outage window or budget. Due within 120 days. |

### 4.2 hle_Status (work order)

| Label | Value | Open or closed |
|---|---|---|
| New | 714800100 | Open |
| Scheduled | 714800101 | Open |
| In Progress | 714800102 | Open |
| On Hold | 714800103 | Open |
| Completed | 714800104 | Closed |
| Cancelled | 714800105 | Closed |

### 4.3 hle_AssetType (asset)

| Label | Value | ID prefix |
|---|---|---|
| Pole | 714800200 | POLE |
| Transformer | 714800201 | TX |
| Switch | 714800202 | SW |
| Breaker | 714800203 | BRK |
| Recloser | 714800204 | RCL |
| Voltage Regulator | 714800205 | REG |

### 4.4 hle_Region (asset, crew and work order)

Each table has its own local `hle_Region` choice with the same labels and values.

| Label | Value | ID code |
|---|---|---|
| Ontario | 714800300 | ON |
| New York | 714800301 | NY |
| Ohio | 714800302 | OH |

### 4.5 hle_OperationalStatus (asset)

| Label | Value |
|---|---|
| In Service | 714800400 |
| Out of Service | 714800401 |
| Retired | 714800402 |

### 4.6 hle_WorkType (work order)

| Label | Value |
|---|---|
| Inspection | 714800500 |
| Preventive Maintenance | 714800501 |
| Corrective Repair | 714800502 |
| Replacement | 714800503 |
| Emergency Restoration | 714800504 |
| Vegetation Clearance | 714800505 |

## 5. Relationships

| Relationship schema name | Type | Referenced (one) | Referencing (many) | Lookup column | Cascade |
|---|---|---|---|---|---|
| `hle_Asset_WorkOrder` | One-to-many (WorkOrder N:1 Asset) | `hle_asset` (`hle_assetid`) | `hle_workorder` | `hle_Asset` | Delete: Remove link. Assign, Share, Unshare, Reparent: No cascade. Merge: Cascade. |
| `hle_Crew_WorkOrder` | One-to-many (WorkOrder N:1 Crew) | `hle_crew` (`hle_crewid`) | `hle_workorder` | `hle_Crew` | Same as above |

"Remove link" on delete means deleting an asset or crew clears the lookup on its work orders instead of deleting them. `-Cleanup` deletes work orders first anyway.

## 6. Dataverse knowledge: synonyms and glossary (Lab 4)

Copilot Studio Dataverse knowledge lets you add synonyms to columns and a glossary of business terms. A knowledge source holds up to 15 tables, and glossary and synonym changes can take up to 15 minutes to apply (CS-K11). Lab 4 deliberately tests the glossary immediately after saving it and again after waiting.

### 6.1 Recommended column synonyms

| Table | Column | Synonyms to add |
|---|---|---|
| Work Order | Work Order Number | WO, WO number, job number, ticket number |
| Work Order | Assigned Crew | crew, team, gang |
| Work Order | Priority | urgency, severity |
| Work Order | Opened On | raised, created, logged |
| Work Order | Due Date | deadline, target date |
| Work Order | Estimated Cost | cost, budget, estimate |
| Asset | Asset Number | asset ID, equipment ID, tag |
| Asset | Condition Score | health score, condition, health index |
| Asset | Install Year | installed, in-service year, age (derived) |
| Asset | Site | station, substation, location |
| Crew | Crew Lead | foreman, supervisor, crew chief |
| Crew | Certifications | tickets, qualifications, training |

Note the collision: "ticket" is a synonym for a work order number here, but Lab 7 introduces a separate ticket system through the Copilot connector. The lab uses this to show why synonyms must be scoped carefully.

### 6.2 Recommended glossary entries

| Term | Definition to enter |
|---|---|
| TX | Transformer. Asset IDs that start with TX are transformers. |
| WO | Work order, a row in the Work Order table. |
| SW | Switch. |
| BRK | Circuit breaker. |
| RCL | Recloser, an automatic breaker on a distribution line. |
| REG | Voltage regulator. |
| OH | Overhead (as in "OH line"). Only in an asset ID (for example `SW-OH-30110`) does OH mean the Ohio region. |
| ON, NY | Region codes in asset and crew IDs: Ontario, New York. |
| ROW | Right of way, the cleared corridor around a power line. |
| LOTO | Lockout/tagout, the isolation procedure required before work. |
| DGA | Dissolved gas analysis, an oil test that detects transformer faults. |
| Open work order | A work order with Status New, Scheduled, In Progress or On Hold. |
| Overdue | An open work order whose Due Date is before today. |
| Poor condition | An asset with Condition Score below 30. |
| Mutual assistance | A crew from one region working on another region's assets, usually after a storm. |

Planted row WO-2026-01106 ("RCL lockout on OH line: RCL-ON-13307") is an Ontario asset whose title says "OH line". Without the glossary entry for OH, an agent may describe it as an Ohio issue. See `data/answer-keys/dataverse-connector.md`.

## 7. Loading the data

Fast path (recommended): run `import-dataverse.ps1` in PowerShell 7.

```powershell
./import-dataverse.ps1 -EnvironmentUrl https://yourorg.crm.dynamics.com -Prefix HLE
```

Manual path (for learners who want to build the tables in the maker portal): create the three tables with the columns and choice values in sections 3 and 4, create the two lookups, then use **Import > Import data from Excel** or Power Query dataflows with the CSV files. Map `AssetNumber` and `CrewCode` in `WorkOrders.csv` to the lookup columns.

To remove everything: `./import-dataverse.ps1 -EnvironmentUrl https://yourorg.crm.dynamics.com -Prefix HLE -Cleanup`.

Environment notes: a Developer environment is owner-only and cannot be shared with security groups (ENV-02). If personas must query this data in Lab 4, use a Sandbox or Production environment. The Developer Plan includes Dataverse with a 2 GB database (ENV-03), which is far more than this seed needs.

## Revision history

| Version | Date | Change |
|---|---|---|
| 1.0 | 2026-09-30 | First release for the course build. |
