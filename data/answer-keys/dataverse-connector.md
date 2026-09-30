# Answer key: Dataverse seed (`data/dataverse/`) and Copilot connector source (`data/connector/`)

For eval authors. All data is fictional (Harbourline Energy Co.). Both generators are deterministic (fixed seed 20260930) and were checked for identical output across runs:

- `python3 tools/generate-data/build_dataverse.py` writes `Assets.csv`, `Crews.csv`, `WorkOrders.csv`, `_facts.json`.
- `python3 tools/generate-data/build_tickets.py` (run after the Dataverse generator; it reads `Assets.csv`) writes `tickets-seed.sql`, `tickets.csv`, `_facts.json`.

"As of" date for both data sets: 2026-09-30. "Open" work order = Status New, Scheduled, In Progress or On Hold. "Open" ticket = Status New, Assigned, In Progress or Pending. The `_facts.json` files hold the computed aggregates; if a generator changes, re-check every number below against them.

## Files

| Path | Summary |
|---|---|
| `data/dataverse/schema.md` | Tables `hle_Asset`, `hle_Crew`, `hle_WorkOrder`; columns; choice values; relationships; Lab 4 synonyms and glossary. |
| `data/dataverse/Assets.csv` | 1,200 assets in 18 depots and stations (Ontario 600, New York 330, Ohio 270). |
| `data/dataverse/Crews.csv` | 60 crews (Ontario 24, New York 18, Ohio 18). 18 of them identical to the mock API crews. |
| `data/dataverse/WorkOrders.csv` | 3,000 work orders opened 2024-10-01 to 2026-09-30. |
| `data/dataverse/import-dataverse.ps1` | Creates publisher, solution, tables, columns, choices, relationships via Dataverse Web API; upserts rows in `$batch`; `-Cleanup`. |
| `data/dataverse/_facts.json` | Generator aggregates (not loaded anywhere). |
| `data/connector/tickets-seed.sql` | SQL Server database `HarbourlineTickets`: Region (3), Site (21), Asset (1,200), Ticket (5,000), TicketAcl (5,002), view `dbo.vTicketIndex`. |
| `data/connector/tickets.csv` | Same 5,000 tickets flattened, with `AclJson`. |
| `data/connector/schema-design.md` | 16-property connector schema with rationale (GC-01 to GC-07). |
| `data/connector/ingest-tickets.ps1` | Creates connection `hleTickets`, registers schema, pushes items with ACLs; `-AddRefinableLater`; `-Cleanup`. |
| `data/connector/app-registration.md` | App permissions and setup. |
| `data/connector/_facts.json` | Generator aggregates. |

## 1. Dataverse: fixed reference values

| Fact | Value | Where |
|---|---|---|
| Priority choice values | Emergency 714800000, High 714800001, Routine 714800002, Deferred 714800003 | schema.md 4.1 |
| Status choice values | New 714800100, Scheduled 714800101, In Progress 714800102, On Hold 714800103, Completed 714800104, Cancelled 714800105 | schema.md 4.2 |
| Asset type values | Pole 714800200, Transformer 714800201, Switch 714800202, Breaker 714800203, Recloser 714800204, Voltage Regulator 714800205 | schema.md 4.3 |
| Region values | Ontario 714800300, New York 714800301, Ohio 714800302 | schema.md 4.4 |
| Due date rule | Emergency +1 day, High +7, Routine +30, Deferred +120 (planted rows can differ) | schema.md 3.4 |
| Poor condition threshold | Condition Score below 30 | schema.md 3.1, glossary |
| Relationships | `hle_Asset_WorkOrder`, `hle_Crew_WorkOrder`, delete behaviour Remove link | schema.md 5 |
| Currency | CAD for Ontario assets, USD for New York and Ohio | WorkOrders.csv `Currency` |
| Solution | `HLEHarbourlineOps`, publisher prefix `hle`, option value prefix 71480 | schema.md 1 |

## 2. Dataverse: aggregates

| Fact | Value |
|---|---|
| Assets by region | Ontario 600, New York 330, Ohio 270 |
| Assets by type | Pole 484, Transformer 317, Switch 134, Recloser 98, Breaker 95, Voltage Regulator 72 |
| Assets by status | In Service 1,121, Out of Service 47, Retired 32 |
| Assets with Condition Score below 30 | 86 (Ontario 43, New York 24, Ohio 19) |
| Lowest condition scores | 5: POLE-NY-24554 and POLE-ON-12302; then TX-ON-12548 (7), TX-NY-22896 (8), BRK-ON-11028 (9) |
| Oldest install year | 1958, POLE-NY-20017 only (next oldest year is 1962) |
| Ontario assets by site | Brockville Depot 96, Oshawa Service Centre 89, Barrie Depot 88, Peterborough Depot 87, Cataraqui Transformer Station 85, Kingston Service Centre 82, Belleville Depot 73 |
| Transformers at Kingston Service Centre | 23 |
| Crews by region | Ontario 24, New York 18, Ohio 18 |
| Crews by specialty | Overhead lines 15, Underground cable 12, Substation 10, Vegetation management 9, Storm response 8, Protection and control 6 |
| Crews based at Kingston Service Centre | CREW-ON-01, 02, 03, 09, 11, 15, 21 (7 crews) |
| Storm response crews | CREW-ON-11, CREW-ON-14, CREW-ON-20, CREW-NY-07, CREW-NY-13, CREW-OH-07, CREW-OH-12, CREW-OH-18 |
| Work orders by priority | Routine 1,677, High 732, Deferred 416, Emergency 175 |
| Work orders by status | Completed 2,433, Cancelled 190, On Hold 132, Scheduled 102, In Progress 87, New 56 |
| Work orders by region | Ontario 1,509, New York 851, Ohio 640 |
| Emergency work orders by region | Ontario 84, New York 51, Ohio 40 |
| Open work orders | 377 (Ontario 183, New York 112, Ohio 82) |
| Open and overdue on 2026-09-30 (Due Date before 2026-09-30) | 263 |
| Highest work order sequence per year | WO-2024-00398, WO-2025-01500, WO-2026-01102 |
| Work orders assigned to CREW-ON-03 | 88 |

### Open Emergency work orders (exactly 4)

| Work order | Asset | Status | Crew | Opened | Due |
|---|---|---|---|---|---|
| WO-2026-01043 | SW-OH-30110 | Scheduled | CREW-OH-07 | 2026-09-18 | 2026-09-19 |
| WO-2026-01083 | POLE-ON-12998 ("Pole down, wires on road") | In Progress | CREW-ON-20 | 2026-09-26 | 2026-09-27 |
| WO-2026-01097 | SW-ON-11936 ("SW flashover, feeder out") | In Progress | CREW-ON-14 | 2026-09-28 | 2026-09-29 |
| WO-2026-01099 | POLE-NY-21057 ("Broken pole after ice storm") | In Progress | CREW-NY-07 | 2026-09-29 | 2026-09-30 |

All four are overdue except WO-2026-01099, which is due on the as-of date.

### Top estimated costs

| Rank | Work order | Cost |
|---|---|---|
| 1 | WO-2026-00392, TX-OH-31902 replacement | USD 1,850,000.00 |
| 2 | WO-2025-01483, "Replace BRK at end of life: BRK-ON-11921", Deferred, Completed | CAD 69,030.00 |
| 3 | WO-2026-00607, "Replace BRK at end of life: BRK-ON-11418" | CAD 68,567.50 |

## 3. Dataverse: planted rows

| Tag | Rows | Facts to test |
|---|---|---|
| P-DV-01 | Asset TX-ON-10423; WO-2025-01280, WO-2026-00953 | Transformer, 25 kVA pole-mount, Kingston Service Centre (KNGSC), Kingston, Ontario. Manufacturer Northfield Transformer Co. Installed 1987. Condition Score 38. In Service. Last inspection 2026-08-28. WO-2025-01280: routine visual inspection opened 2025-11-03, completed 2025-11-20 by CREW-ON-03, "no oil staining", pole P-30912, Bath Road near Collins Bay Road. WO-2026-00953: High, infrared scan opened 2026-08-28, completed 2026-09-02 by CREW-ON-03, "light oil film noted at the tank lid gasket, monitor". No open work order for this asset. Matches Lab 9 field report FR-EON-2026-1187 (2026-10-01, oil weeping from tank lid gasket). |
| P-DV-02 | Asset POLE-NY-20017; WO-2026-00750 | Oldest asset (installed 1958), Watertown Depot, Condition 41. WO-2026-00750 inspection completed 2026-07-10 by CREW-NY-01: 71 percent remaining strength, next test due 2031. The asset has 3 work orders in total. |
| P-DV-03 | Asset TX-OH-20871; WO-2025-01181 | Transformer, 50 kVA pole-mount, Ashtabula Depot, Ashtabula, Ohio. Installed 1992, Condition 44, In Service. WO-2025-01181 inspection opened 2025-10-09, completed 2025-10-14 by CREW-OH-06: minor surface tracking on the primary bushing, pole P-51260, Lake Avenue at West 5th Street. Matches Lab 9 field report FR-OHN-2026-0918 (2026-10-03). Only 1 work order. Note: the number 20871 is in the range most New York assets use; the region code OH is what counts. |
| P-DV-04 | Asset SW-OH-30110; 9 work orders | Asset with the most work orders (9; no other asset has more than 7). Switch, 27.6 kV 600 A motorized, Lima Depot, Condition 34. Eight High "SW fails to operate" corrective repairs (WO-2024-00197, WO-2025-00087, WO-2025-00291, WO-2025-00639, WO-2025-00936, WO-2025-01250, WO-2026-00053, WO-2026-00490), all Completed, crews CREW-OH-03 and CREW-OH-01. Ninth: WO-2026-01043, Emergency, "SW stuck open during restoration", Scheduled, CREW-OH-07, opened 2026-09-18, due 2026-09-19 (overdue). |
| P-DV-05 | WO-2025-01423 | The only work order where the crew region differs from the asset region: Ontario crew CREW-ON-11 on New York asset POLE-NY-26615 (Rochester Depot), ice storm Ulla, opened 2025-12-11, completed 2025-12-12, Emergency, 14.5 actual hours, USD 6,180. Cross-border mutual assistance. |
| P-DV-06 | Asset POLE-ON-11250; WO-2025-00209, WO-2026-01057 | Data defect: asset status Retired (Oshawa Service Centre, Condition 12, installed 1971) but WO-2026-01057 "Replace cracked crossarm" is In Progress (opened 2026-09-21, CREW-ON-06). It is the only retired asset with an open work order. WO-2025-00209 (completed 2025-03-04) recommended replacement at 58 percent strength. |
| P-DV-07 | Asset BRK-NY-24480; WO-2025-00814, WO-2026-00603 | 69 kV SF6 breaker at Mohawk Valley Substation (Utica). WO-2026-00603: Deferred, On Hold, mechanism service, awaiting outage window 2027-01-12 to 2027-01-15, due 2027-01-15, crew CREW-NY-03 (Sal Okonkwo). WO-2025-00814: SF6 pressure 0.58 MPa, alarm 0.55 MPa. |
| P-DV-08 | WO-2026-01076 | Glossary trap: "RCL lockout on OH line: RCL-ON-13307". OH means overhead. The asset is in Ontario (Barrie Depot, feeder 44M7). High, Scheduled, CREW-ON-19, due 2026-10-01. An answer that calls it an Ohio issue is wrong. |
| P-DV-09 | Crews CREW-ON-09 and CREW-ON-17 | Both led by Dana Kowalski (only lead with two crews). CREW-ON-09 Kingston Overhead Lines Crew C; CREW-ON-17 Peterborough Substation Crew A. |
| P-DV-10 | Asset TX-OH-31902; WO-2026-00392 | Highest estimated cost: USD 1,850,000 (next highest is CAD 69,030). 20 MVA station transformer at Maumee Bay Substation, Toledo, Out of Service, Condition 24, installed 1976. Replacement Scheduled, opened 2026-04-07, due 2026-12-15, CREW-OH-01, capital project CP-2026-117, delivery expected 2026-11. |
| P-DV-11 | Crew CREW-OH-07 | Only crew certified "Live-Line Barehand 69 kV". Toledo Storm Response Crew A, lead Tessa Whitaker, 5 people. |

### Crews shared with the mock API

CREW-ON-01 to 08, CREW-NY-01 to 05 and CREW-OH-01 to 05 have the same crewLead, crewSize, baseDepot and specialty as `data/api/src/data/crews.json` (the generator asserts this). Examples: CREW-ON-03 Devon Achebe, 5, Kingston Service Centre, Overhead lines; CREW-OH-01 Dale Rutherford, 6, Toledo Operations Center, Substation. Crew status (Assigned, Available, Off Shift) exists only in the API. The API outage OUT-2026-0427 (substation transformer failure at Maumee Bay substation, 2026-09-29) has no Dataverse work order; TX-OH-31902 at the same station was already out of service since April 2026. Treat that as a cross-source gap, not a contradiction.

### Glossary behaviour (Lab 4)

| Question | Without glossary | With glossary (after up to 15 minutes, CS-K11) |
|---|---|---|
| "What TX work orders are open in Ontario?" | May not map TX to Transformer | Filters Asset Type = Transformer |
| "Show Ohio issues with OH lines" | May include WO-2026-01076 as Ohio | WO-2026-01076 is Ontario; OH = overhead |
| "Show me my WO list" | Unclear | WO = work order |

## 4. Connector source: aggregates

| Fact | Value |
|---|---|
| Tickets | 5,000, IDs 100001 to 105000; item IDs HLT100001 to HLT105000 |
| URL pattern | `https://tickets.harbourline.example/t/<TicketId>` |
| Created range | 2025-01-02 to 2026-09-30 |
| By category | Field Operations 1,698; Outage 716; Asset Maintenance 606; IT Service Desk 567; Facilities 400; HR Case 304; Finance Request 275; Safety 227; Customer Complaint 207 |
| By region | Ontario 2,712; New York 1,282; Ohio 1,006 |
| Outage tickets by region | Ontario 357, New York 190, Ohio 169 |
| By status | Closed 3,742; Resolved 792; Pending 189; In Progress 154; Assigned 77; New 46 |
| By priority | Medium 2,353; High 1,147; Low 1,142; Critical 358 |
| Open tickets by region | Ontario 256, New York 132, Ohio 78 |
| Open Critical tickets | 29 |
| Sites | 21 (18 depots and stations from schema.md 3.3, plus Toronto Head Office, Albany Regional Office, Columbus Regional Office). Toronto Head Office has the most tickets (775). |
| Tickets mentioning planted assets | Exactly one each: TX-ON-10423 (100420), BRK-NY-24480 (101776), TX-OH-20871 (102777), SW-OH-30110 (104862) |

### ACL patterns (count of tickets)

| Pattern | Tickets |
|---|---|
| grant group Ops-Ontario | 1,608 |
| grant group Ops-US | 1,618 |
| grant group HR | 304 |
| grant group Finance | 274 |
| grant everyone | 400 |
| grant everyoneExceptGuests | 793 |
| grant Ops-Ontario and grant Ops-US | 1 (101999) |
| grant everyoneExceptGuests, deny Ops-Ontario | 1 (104321) |
| grant user Sofia Brennan only | 1 (104700) |
| Total ACL rows | 5,002 |

## 5. Connector source: planted tickets

| Ticket | Tag | ACL | Facts |
|---|---|---|---|
| 100420 | P-TK-01 | grant Ops-Ontario | "Stain on pole P-30912 below transformer TX-ON-10423, Bath Road, Kingston". Asset Maintenance, Medium, Resolved. Created 2026-08-27, last modified 2026-09-02. Links WO-2026-00953, crew CREW-ON-03. Scan found light oil film at the tank lid gasket. |
| 101776 | P-TK-02 | grant Ops-US | "Trip counter above limit on BRK-NY-24480, Mohawk Valley Substation". 2,140 operations vs 2,000 limit. Pending, High. Service deferred to 2027-01-12 to 2027-01-15. |
| 101999 | P-TK-09 | grant Ops-Ontario and Ops-US | Cross-border mutual assistance roster 2026-11-15 to 2027-03-31. Ontario storm crews CREW-ON-11, 14, 20; US storm crews CREW-NY-07, NY-13, OH-07, OH-12, OH-18. Paperwork owner US Field Dispatch (New York). |
| 102050 | P-TK-03 | grant HR | "HR case: Return-to-work plan and accommodation (case HR-2026-0381)". Modified duties 6 weeks from 2026-10-05: no climbing, lifting limit 10 kg. Case owner Priya Nandakumar. Next review 2026-11-16. |
| 102600 | P-TK-04 | grant everyone | Toronto Head Office parking level P2 closed 2026-10-13 to 2026-10-24; use surface lot on Harbour Street; accessible spaces move to P1. |
| 102777 | P-TK-11 | grant Ops-US | "Bushing tracking noted on TX-OH-20871, Lake Avenue, Ashtabula". Closed, Low, 2025-10-09 to 2025-10-14. WO-2025-01181, crew CREW-OH-06. |
| 103115 | P-TK-05 | grant everyoneExceptGuests | VPN client version 6.2 rollout on 2026-10-06 from 18:00 Eastern; field tablets 2026-10-08; IT Service Desk extension 4357. |
| 103900 | P-TK-08 | grant Finance | Q3 accrual for CP-2026-117 (Maumee Bay Substation transformer replacement, TX-OH-31902) booked at USD 185,000 instead of USD 1,850,000; correcting journal JE-2026-09-4471 before the 2026-10-07 close. |
| 104321 | P-TK-06 | grant everyoneExceptGuests, deny Ops-Ontario | Safety investigation SI-2026-014, contact with energized conductor on 2026-09-08, Oshawa Service Centre area; minor burn; returned to work 2026-09-10; interim control second-person verification of test-before-touch. |
| 104700 | P-TK-07 | grant user `{{USER_FIN}}` (Sofia Brennan) only | Duplicate hotel charge CAD 412.60 (Ottawa, 2026-09-03); dispute filed 2026-09-16, reference CD-88213. |
| 104862 | P-TK-10 | grant Ops-US | "Repeat failure: SW-OH-30110 stuck open during restoration". New, Critical, Outage, Lima Depot. Ninth failure since November 2024. Links WO-2026-01043, crew CREW-OH-07. |

## 6. Expected visibility per persona (Lab 7)

Deny overrides grant (GC-07). Counts are items the ACL allows; they assume full ingestion and indexing.

| Persona (groups) | Can see planted | Cannot see planted | Items allowed by ACL |
|---|---|---|---|
| Priya Nandakumar, HR Manager (`<Prefix>-HR`, AllStaff) | 102050, 102600, 103115, 104321 | 100420, 101776, 101999, 102777, 103900, 104700, 104862 | 1,498 (HR 304 + everyone 400 + everyoneExceptGuests 793 + 104321) |
| Marcus Delaney, Field Technician (`<Prefix>-Ops-Ontario`, AllStaff) | 100420, 101999, 102600, 103115 | 104321 (denied), 101776, 102777, 104862, 102050, 103900, 104700 | 2,802 (Ops-Ontario 1,608 + 101999 + 400 + 793) |
| Sofia Brennan, Finance Analyst (`<Prefix>-Finance`, AllStaff) | 103900, 104700, 102600, 103115, 104321 | 100420, 101776, 101999, 102050, 102777, 104862 | 1,469 (Finance 274 + 104700 + 400 + 793 + 104321) |
| Tom Whitfield, Operations Clerk, unlicensed (`<Prefix>-Ops-US`, AllStaff) | ACL allows 101776, 101999, 102777, 104862, 102600, 103115, 104321 | 100420, 102050, 103900, 104700 | 2,813 by ACL. He has no Copilot license, so Copilot and agents are not the test surface; do not assert what he sees in Copilot. |
| Guest contractor (Operations Microsoft 365 group only) | At most 102600 (`everyone`). Not asserted: GC-10 is UNVERIFIED. | 103115 and 104321 (everyoneExceptGuests excludes guests), all group-granted tickets, 104700 | 0 to 400; observe, do not assert |
| Learner (all course groups) | Everything except the two below | 104321 (denied through Ops-Ontario membership), 104700 (user-only) | 4,998 |

Good eval prompts: "What is the status of ticket 104321?" as Marcus (expected: no result / no access) versus Priya (expected: In Progress, SI-2026-014). "Who owns HR case HR-2026-0381?" as Sofia (expected: no access) versus Priya (expected: Priya Nandakumar). The learner not seeing 104321 is a deliberate surprise that shows deny beats grant.

## 7. Schema and break-it facts (Lab 7)

| Fact | Value | Where |
|---|---|---|
| Properties in schema | 16 (limit 128, GC-01) | schema-design.md 2 |
| Refinable properties | status, priority, category, region, assetType, tags, createdDateTime, lastModified | schema-design.md 2 |
| Searchable properties | title, siteName, createdBy, assignedTo | same |
| Exact match | ticketId, assetTag, tags | same |
| Semantic labels | title, url, iconUrl, createdBy, createdDateTime, lastModifiedDateTime (on property `lastModified`) | schema-design.md 3.4 |
| Break-it step | `ingest-tickets.ps1 -AddRefinableLater` adds refinable `costCentre` to the registered schema; expected to fail because refinable cannot be added in an update (GC-04) | ingest-tickets.ps1, schema-design.md 3.1 |
| Fix | Add `costCentre` without refinable, or delete the connection and re-register | same |
| Schema registration time | 5 to 15 minutes (Graph schema PATCH reference) | app-registration.md 4 |
