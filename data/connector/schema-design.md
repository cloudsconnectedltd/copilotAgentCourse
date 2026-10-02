# Harbourline tickets connector: schema design

| Item | Value |
|---|---|
| Connection ID | `hleTickets` (default; `<prefix>Tickets` with another `-Prefix`) |
| Connection name | HLE Tickets |
| Source | SQL Server database `HarbourlineTickets` (`tickets-seed.sql`) or the flat export `tickets.csv` |
| Items | 5,000 tickets, IDs 100001 to 105000, item IDs `HLT100001` to `HLT105000` |
| Loader | `ingest-tickets.ps1` (Microsoft Graph PowerShell, app-only) |
| Used in | Lab 7, then Labs 2, 3 and 6 re-tested with the connector attached |
| Owner | Harbourline IT Integration (course data) |
| Effective | 2026-09-30 |

This document is the design decision record for the connector schema. Read it before running `ingest-tickets.ps1`, because some decisions cannot be undone without deleting the connection.

## 1. Source model

The ticket system is a three-level hierarchy with a separate ACL table:

```
Region (ON, NY, OH)
  Site (18 depots and stations, plus 3 offices)
    Asset (1,200 assets, same IDs as the Dataverse Asset table, for example TX-ON-10423)
Ticket (5,000)  -> Site (required), Asset (optional)
TicketAcl       -> Ticket, one or more rows per ticket
```

The view `dbo.vTicketIndex` flattens the hierarchy into one row per ticket and adds an `AclJson` column built with `FOR JSON PATH`. `tickets.csv` has exactly the same columns as the view, so the ingest script treats both sources the same way.

## 2. Property plan

A schema can hold up to 128 properties (GC-01). This plan uses 16, which leaves room to add properties later. Ticket text (title plus description plus location) goes into the item `content`, which is full-text indexed and used by Copilot for summarization; it is not a schema property.

Legend: S = searchable, Q = queryable, R = retrievable, F = refinable, X = exact match required (`isExactMatchRequired`).

| Property | Type | S | Q | R | F | X | Semantic label | Aliases | Source column |
|---|---|---|---|---|---|---|---|---|---|
| `ticketId` | String | | Yes | Yes | | Yes | | `id`, `ticketNumber` | TicketId |
| `title` | String | Yes | Yes | Yes | | | `title` | `subject` | Title |
| `status` | String | | Yes | Yes | Yes | | | `state` | Status |
| `priority` | String | | Yes | Yes | Yes | | | `urgency` | Priority |
| `category` | String | | Yes | Yes | Yes | | | `ticketType` | Category |
| `region` | String | | Yes | Yes | Yes | | | `area` | Region |
| `siteName` | String | Yes | Yes | Yes | | | | `site`, `depot` | SiteName |
| `assetTag` | String | | Yes | Yes | | Yes | | `asset`, `assetId` | AssetTag |
| `assetType` | String | | Yes | Yes | Yes | | | `equipmentType` | AssetType |
| `createdBy` | String | Yes | Yes | Yes | | | `createdBy` | `reporter`, `author` | CreatedBy |
| `assignedTo` | String | Yes | Yes | Yes | | | | `queue`, `owner` | AssignedTo |
| `tags` | StringCollection | | Yes | Yes | Yes | Yes | | `labels` | Tags (semicolon separated) |
| `createdDateTime` | DateTime | | Yes | Yes | Yes | | `createdDateTime` | `opened`, `created` | CreatedDateTime |
| `lastModified` | DateTime | | Yes | Yes | Yes | | `lastModifiedDateTime` | `modified`, `updated` | LastModified |
| `url` | String | | | Yes | | | `url` | | Url (`https://tickets.harbourline.example/t/<id>`) |
| `iconUrl` | String | | | Yes | | | `iconUrl` | | IconUrl (one icon per category) |

Property names and aliases are alphanumeric and at most 32 characters, as the property resource requires.

## 3. Rationale

### 3.1 Refinable is decided now, not later

Schema updates are constrained rather than impossible: you can add properties (reingest recommended), add or remove search attributes (reingest required) and change aliases and semantic labels, but you cannot add `refinable` to a property in a schema update (GC-04). If a filter might ever be needed in a search vertical or as a Copilot filter, it has to be refinable in the first registration. That is why `status`, `priority`, `category`, `region`, `assetType`, `tags` and both dates are refinable from day one, even though Lab 7 only uses some of them.

Lab 7 includes a "break it" step: `ingest-tickets.ps1 -AddRefinableLater` tries to add a new refinable property `costCentre` to the registered schema. The request is rejected (either immediately or as a failed schema operation). The fix is to add `costCentre` without `isRefinable`, or to delete the connection and register a new schema.

### 3.2 Searchable and refinable are exclusive

A property cannot be both searchable and refinable (GC-05). The plan splits properties into two groups:

- Free text that users type words from: `title`, `siteName`, `createdBy`, `assignedTo`. Searchable, not refinable.
- Controlled values used as filters: `status`, `priority`, `category`, `region`, `assetType`, `tags`, dates. Refinable and queryable, not searchable. Users can still query them with KQL, for example `priority:Critical` or `region:Ohio`.

`siteName` is the only borderline case. It is searchable so that "tickets at Kingston" matches, and therefore it cannot be a refiner. `region` is the refiner for location.

### 3.3 Queryable and exact match for identifiers

`ticketId` and `assetTag` are queryable with exact match required, so `assetTag:TX-ON-10423` returns only that asset and `assetTag:TX` returns nothing. Exact match can only be set on properties that are not searchable. `tags` also uses exact match so `tags:storm` does not match `storm-response`.

Note: `isExactMatchRequired` is described in the Graph "manage schema" concept page but is not listed on the v1.0 property resource page in the documentation snapshot used for this course. If registration rejects it, remove the three `isExactMatchRequired` lines in `ingest-tickets.ps1` and re-run.

### 3.4 Retrievable and semantic labels

A property must be retrievable to take a semantic label (GC-05), so every labelled property is retrievable. The labels used come from the documented label list (GC-06):

| Label | Property | Why |
|---|---|---|
| `title` | `title` | Most important label. Enables the result cluster experience and gives Copilot the citation text. |
| `url` | `url` | Citations link back to `https://tickets.harbourline.example/t/<id>`. |
| `iconUrl` | `iconUrl` | Category icon on search results. |
| `createdBy` | `createdBy` | "Tickets I raised" style questions. |
| `createdDateTime` | `createdDateTime` | Age and date-range questions. |
| `lastModifiedDateTime` | `lastModified` | Freshness ranking; second most important label for relevance. |

Each label maps to exactly one property. `status`, `priority` and `assignedTo` are left unlabelled in this design because the course limits table (GC-06) lists only the labels above. The current property resource page in the Graph docs also lists labels such as `assignedTo`, `priority` and `state`; confirm them on Microsoft Learn before adding them in a later schema update (labels can be changed after registration, GC-04).

### 3.5 Content

`content.value` is built as: title, a blank line, the description, then `Site: <site> (<region>)` and `Asset: <asset tag> (<asset type>)` when present. `content.type` is `text`. Item size is limited to 30 MB of parsed text (GC-02); the largest ticket here is under 1 KB.

## 4. Access control lists

Each item carries its own ACL. ACL types are `user`, `group`, `everyone`, `everyoneExceptGuests` and `externalGroup`, and deny overrides grant (GC-07). The source stores placeholder tokens that the script replaces with real object IDs:

| Token | Replaced with (default) | ACL type |
|---|---|---|
| `{{GROUP_OPS_ONTARIO}}` | Object ID of Entra group `<Prefix>-Ops-Ontario` | group |
| `{{GROUP_OPS_US}}` | Object ID of `<Prefix>-Ops-US` | group |
| `{{GROUP_HR}}` | Object ID of `<Prefix>-HR` | group |
| `{{GROUP_FINANCE}}` | Object ID of `<Prefix>-Finance` | group |
| `{{USER_FIN}}` | Object ID of the user whose UPN starts with `<prefix>-fin@` (Sofia Brennan) | user |
| `{{TENANT_ID}}` | Tenant ID | everyone, everyoneExceptGuests |

For `everyone` and `everyoneExceptGuests`, the ACL `value` is the tenant ID, as the ACL resource page specifies.

Rules used by the generator:

| Category | ACL | Tickets |
|---|---|---|
| Field Operations, Outage, Asset Maintenance, Customer Complaint | grant `{{GROUP_OPS_ONTARIO}}` for Ontario, grant `{{GROUP_OPS_US}}` for New York and Ohio | 3,226 plus 1 dual-group ticket |
| Safety, IT Service Desk | grant `everyoneExceptGuests` | 793 plus 1 deny-case ticket |
| Facilities | grant `everyone` | 400 |
| HR Case | grant `{{GROUP_HR}}` | 304 |
| Finance Request | grant `{{GROUP_FINANCE}}` | 274 plus 1 user-only ticket |

Planted ACL cases (full list with expected results per persona in `data/answer-keys/dataverse-connector.md`):

| Ticket | Pattern |
|---|---|
| 100420 | Ontario operations only |
| 101776, 102777, 104862 | US operations only |
| 101999 | Ontario and US operations (two group grants) |
| 102050 | HR only |
| 103900 | Finance only |
| 104700 | One user only (Sofia Brennan) |
| 102600 | everyone |
| 103115 | everyoneExceptGuests |
| 104321 | everyoneExceptGuests granted, `{{GROUP_OPS_ONTARIO}}` denied |

Whether guests see items with an `everyone` ACL is not confirmed by Microsoft documentation (GC-10, UNVERIFIED). Lab 7 observes the guest result for ticket 102600 rather than asserting it.

## 5. Change log for the schema

| Version | Date | Change |
|---|---|---|
| 1.0 | 2026-09-30 | Initial 16-property schema registered by `ingest-tickets.ps1`. |
