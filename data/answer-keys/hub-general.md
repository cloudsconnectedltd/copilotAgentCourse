# Answer key: Harbourline-Hub general content (Getting-Started, Finance, Vendors)

Generator: `tools/generate-data/build_hub_general.py` (seed 20250915, deterministic; rerun with `python3 tools/generate-data/build_hub_general.py`). It prints the vendor aggregates quoted below.

All paths are relative to the repo root. Section references use the heading text in each document. Every docx starts with a metadata table (Document ID, Owner, Effective date, Version, Applies to) and ends with a "Revision history" table.

---

## 1. Getting-Started library (Lab 1, clean)

Location: `data/sharepoint/Harbourline-Hub/Getting-Started/`. Also packaged flat in `data/sharepoint/getting-started.zip` (same 5 files, no folders).

Design rule: every fact has exactly one home document. No contradictions between these 5 files. No sensitivity labels. The other docs only point to each other by title ("see Benefits at a Glance"); they never restate each other's facts.

Note for eval writers: HR-Policies (another area) contains leave policies. Leave-Policy-v4 is meant to use the same values as the Getting-Started vacation guide; Leave-Policy-v3 differs. Lab 1 should scope knowledge to Getting-Started only, so that answers come from this guide.

### 1.1 `Welcome-to-Harbourline.docx`
Summary: first-week onboarding guide (company overview, values, leadership, first-week checklist).
Document ID HLE-GS-001, owner People and Culture, Onboarding Team, effective 2025-09-01, version 2.0.

| Fact | Section |
|---|---|
| Founded in 1924 | 1. About Harbourline Energy Co. |
| About 1.2 million customers across Ontario, New York and Ohio | 1. About |
| About 2,000 employees | 1. About |
| Regulators: Ontario Energy Board (Ontario); New York and Ohio public service commissions; NERC and FERC for transmission | 1. About |
| Mission: "keep the lights on safely, reliably and affordably for every community we serve" | 2. Our mission and values |
| Four values, acronym SAFE: Safety first, Accountability, Fairness, Excellence | 2. Our mission and values |
| CEO: Eleanor Voss (President and Chief Executive Officer) | 3. Leadership team (table) |
| CFO: Rajiv Menon; COO: Dana Okafor; Chief People Officer: Colette Brisebois; CIO: Martin Szabo | 3. Leadership team |
| First-week steps: Day 1 badge, laptop, buddy, MFA; Day 2 Safety Orientation course; Day 3 benefits; Day 4 vacation guide and Workday balance; Day 5 New Employee Welcome Session | 4. Your first week |
| New Employee Welcome Session: first Friday of every month, 10:00 a.m. to 12:00 p.m. Eastern, in person at head office and on Teams | 4. Your first week |
| Onboarding buddy for the first 90 days, from a different team, introduced by manager on day 1 | 5. Your onboarding buddy |
| Pointer table to the other 4 docs | 6. Where to find things |

### 1.2 `Vacation-Policy.docx`
Title: "Vacation Policy: Quick Guide for New Employees". Document ID HLE-GS-002, owner People and Culture, Total Rewards, effective 2025-01-01, version 4.0.

| Fact | Section |
|---|---|
| "Full-time employees receive 15 vacation days in their first year." (quotable key fact) | 2. How many vacation days you receive |
| Years 1 to 4: 15 days; Years 5 to 9: 20 days; Year 10 and beyond: 25 days | 2 (table) |
| Entitlement increases on the anniversary of start date; part-time prorated by scheduled hours | 2 |
| Request through Workday at least 2 weeks before the first day off; manager approves in Workday | 3. Booking vacation |
| Carry-over: up to 5 unused days into the next calendar year | 4. Carrying over unused days |
| Carried-over days must be used by end of Q1 (March 31) or are forfeited | 4 |
| Questions: manager or Total Rewards via People and Culture service portal in Workday | 5. Questions |

### 1.3 `IT-Help-Desk-FAQ.docx`
Document ID HLE-GS-003, owner Information Technology, Service Desk, effective 2025-06-01, version 3.1.

| Fact | Section |
|---|---|
| Help desk phone: 1-800-555-0142 | 1. How do I contact the IT Help Desk? (table) |
| Portal: https://helpdesk.harbourline.example | 1 |
| Email: helpdesk@harbourline.example | 1 |
| Hours: Monday to Friday, 7:00 a.m. to 7:00 p.m. Eastern Time | 1 |
| After hours: 24/7 for outage-critical systems, press 1 | 1 |
| Priorities and first response: P1 Critical 15 minutes; P2 High 1 hour; P3 Normal 4 business hours; P4 Request 2 business days | 2. How quickly will my ticket be answered? |
| Password: at least 14 characters, expires every 90 days, cannot reuse last 10 | 3. How do I reset my password? |
| MFA: Microsoft Authenticator, required for all accounts | 4. How do I set up multi-factor authentication? |
| VPN: HarbourLink VPN, preinstalled; Outlook and Teams work without VPN | 5. How do I connect from home? |
| Office staff equipment: laptop, docking station, two monitors, headset; field staff: rugged tablet; requests are P4 | 6. What equipment will I receive? |
| Wi-Fi: HLE-Corp (company laptops, automatic); HLE-Guest (daily access code from reception) | 7. How do I connect to office Wi-Fi? |
| Phishing: Report Phishing button in Outlook, do not forward | 8. How do I report a suspicious email? |

### 1.4 `Office-Locations.docx`
Document ID HLE-GS-004, owner Corporate Real Estate and Facilities, effective 2025-07-01, version 2.2.

| Fact | Section |
|---|---|
| Head office: 1450 Harbourfront Drive, Toronto, ON M5J 2X9, Canada | 1. Head office |
| Reception: Monday to Friday 8:00 a.m. to 6:00 p.m. ET; phone 416-555-0100 | 1. Head office |
| Hamilton, Ontario System Control Centre: 88 Escarpment Road, Hamilton, ON L8N 3T4 | 2. All office locations (table) |
| Sudbury, Northern Ontario Service Centre: 310 Nickel Ridge Way, Sudbury, ON P3A 4R7 | 2 |
| Albany, New York Regional Office: 25 State Pier Street, Albany, NY 12207 | 2 |
| Syracuse, New York Operations Centre: 740 Onondaga Parkway, Syracuse, NY 13202 | 2 |
| Columbus, Ohio Regional Office: 1200 Scioto Commons Blvd, Columbus, OH 43215 | 2 |
| Akron, Ohio Operations Centre: 455 Cuyahoga Falls Road, Akron, OH 44308 | 2 |
| 7 offices total (3 Ontario, 2 New York, 2 Ohio) | 2 |
| Badge holders: 6:00 a.m. to 10:00 p.m., seven days a week; Hamilton and Syracuse staffed 24 hours and need control room access approval; visitors escorted | 3. Building access |
| Head office underground parking needs a permit from Facilities; all other offices free on-site parking | 4. Parking |
| Desk and room booking: Harbourline Spaces app in Teams | 5. Booking a desk or meeting room |
| Revision 2.2 added Akron | Revision history |

### 1.5 `Benefits-At-a-Glance.docx`
Document ID HLE-GS-005, owner People and Culture, Total Rewards, effective 2025-01-01, version 5.0.

| Fact | Section |
|---|---|
| Coverage starts on the first day of employment | 1. When your benefits start |
| Enrolment window: 31 days from start date | 1 and 5 |
| Annual open enrolment: November 1 to November 15 | 1 |
| Ontario provider: Maplecrest Benefits (https://maplecrest.example/harbourline) | 2. Benefits providers |
| New York and Ohio provider: Keystone Health Partners (https://keystonehealth.example/harbourline) | 2 |
| Health: Ontario 90 percent; US 85 percent after deductible | 3. Benefits summary |
| Dental: 80 percent basic and major (both) | 3 |
| Vision: CAD 400 / USD 300 every 24 months | 3 |
| Health spending account: CAD 750 per year (Ontario only) | 3 |
| Retirement: Group RRSP match up to 5 percent (Ontario); 401(k) match up to 6 percent (US) | 3 |
| Wellness allowance: CAD 500 / USD 400 per year | 3 |
| Life insurance: 2 times annual salary | 3 |
| EAP: ClearPath EAP, 24 hours, 1-800-555-0199 | 4. Employee Assistance Program |
| Enrol in Workday via Benefits task; if you do not enrol you get single coverage only | 5. How to enrol |

---

## 2. Finance library

Location: `data/sharepoint/Harbourline-Hub/Finance/`.

### 2.1 `Expense-Policy.docx`
Summary: travel and business expense reimbursement policy (about 3 to 4 pages). Document ID HLE-FIN-101, owner Finance, Office of the Controller, effective 2025-04-01, version 6.0.

| Fact | Section |
|---|---|
| Ontario reimbursed in CAD; New York and Ohio in USD | 1. Purpose and scope |
| Manager reviews claims within 5 business days; Controller owns policy and approves exceptions below VP level | 2. Roles and responsibilities |
| Per diem Ontario (CAD): breakfast 20, lunch 25, dinner 45, full day 90, incidentals 10 | 3. Meals and per diem rates |
| Per diem US (USD): breakfast 18, lunch 22, dinner 40, full day 80, incidentals 8 | 3 |
| Travel days (first and last): 75 percent of full day total; no receipts needed for per diem | 3 |
| Alcohol not reimbursable except client events pre-approved by a Director | 3 |
| Hotel caps before taxes: Toronto CAD 275; other Ontario CAD 200; New York City USD 350; other US USD 225; above cap needs Director approval before booking | 4. Accommodation |
| Economy class, book 14 days ahead via travel desk; business class only for flights over 6 hours with VP approval | 5.1 Air and rail |
| Mileage: Ontario CAD 0.72 per km; New York and Ohio USD 0.70 per mile; deduct normal commute | 5.2 Personal vehicle mileage |
| Fleet vehicle required for trips over 200 km (125 miles) when available | 5.3 Fleet vehicles |
| Receipt required for any expense of CAD 25 / USD 25 or more | 6. Receipts |
| Itemized receipt plus attendee names for any meal of CAD 75 / USD 75 or more | 6 |
| Missing receipt declaration: once per quarter, expense below CAD 100 / USD 100 | 6 |
| Submit in Workday within 30 days of expense date | 7. Submission deadlines |
| 31 to 90 days old: Director approval; older than 90 days: not reimbursed unless VP approves | 7 |
| December expenses must be submitted by January 10 | 7 |
| Reimbursement by direct deposit within 10 business days of final approval | 7 |
| VP claims approved by CFO; CFO claims approved by CEO; no self-approval | 9. Approval of expense claims |
| Revision 6.0 (2025-04-01) set mileage rates and 30-day deadline | Revision history |

### 2.2 `Approval-Matrix.docx`
Summary: delegation of financial authority as a Word table (6 categories x 6 levels) plus notes and worked examples. Document ID HLE-FIN-102, owner Finance, Office of the CFO, effective 2025-04-01, version 3.2.

Rule: commitment approved by the lowest level whose limit is equal to or greater than the value. Amounts in CAD for Ontario; same numbers in USD for US operations.

Table in section "2. Approval thresholds" (maximum per transaction):

| Spend category | Supervisor | Manager | Director | VP | CFO | Board |
|---|---|---|---|---|---|---|
| Operating expense | 5,000 | 25,000 | 100,000 | 500,000 | 2,000,000 | Above 2,000,000 |
| Capital project | Not authorized | 50,000 | 250,000 | 1,000,000 | 5,000,000 | Above 5,000,000 |
| Vendor contract | 10,000 | 50,000 | 250,000 | 1,000,000 | 3,000,000 | Above 3,000,000 |
| Emergency restoration procurement | 25,000 | 100,000 | 500,000 | 2,000,000 | 10,000,000 | Above 10,000,000 |
| Consulting services | Not authorized | 25,000 | **75,000** | 300,000 | 1,000,000 | Above 1,000,000 |
| IT software | 2,500 | 15,000 | 75,000 | 250,000 | 1,000,000 | Above 1,000,000 |

Notes (section "3. Notes"): Note 1 no splitting; Note 2 capital amounts include contingency; Note 3 vendor contract = full term value including renewal options; Note 4 emergency procurement only in a declared emergency, commitments above 500,000 ratified by CFO within 10 business days after emergency closes; Note 5 consulting includes management, legal advisory, regulatory advisory, while engineering design counts as Vendor contract; Note 6 IT software = total annual cost; Note 7 Supervisors cannot approve capital projects or consulting; Note 8 delegations must be recorded by Finance and cannot exceed the delegator's limit.

Worked examples (section "4. Worked examples"): CAD 80,000 operating expense = Director; USD 1,200,000 three-year vendor contract = CFO; CAD 6,500,000 capital project = Board; CAD 12,000 per year IT software = Manager.

Revision history: v3.2 (2025-04-01) "Consulting services Director limit reduced from 150,000 to 75,000."

### 2.3 `Approval-Matrix.xlsx` (DELIBERATE DIFFERENCE)
Summary: same matrix as a worksheet, plus a Delegations sheet.

- Sheet "Approval Matrix": title in A1, header row 3 (Spend category, Supervisor, Manager, Director, VP, CFO, Board), data rows 4 to 9, numbers stored as integers. Row 10 blank, A11 note "Source: Approval Matrix working copy maintained by Finance."
- **Deliberate difference: Consulting services, Director column (cell D8) = 150,000 in the xlsx; the docx says 75,000.** All other 35 cells match the docx. The docx revision history explains the xlsx is stale (limit was reduced from 150,000 to 75,000 in v3.2, 2025-04-01), so the docx is the current value.
- Test question: "Who must approve a CAD 120,000 consulting engagement?" docx: VP (above Director's 75,000). xlsx: Director (within 150,000). Correct current answer: VP.
- Sheet "Delegations": 15 rows (DEL-2025-001 to DEL-2025-015), columns Delegation ID, Delegator, Delegator title, Delegate, Delegate title, Spend category, Delegated limit, Start date, End date, Reason.

| ID | Delegator | Delegate | Category | Limit | Start | End | Reason |
|---|---|---|---|---|---|---|---|
| DEL-2025-001 | Rajiv Menon (CFO) | Helena Park (VP, Financial Planning) | Operating expense | 2,000,000 | 2025-07-14 | 2025-07-25 | Vacation |
| DEL-2025-002 | Dana Okafor (COO) | Grant Albrecht (VP, Ontario Operations) | Emergency restoration procurement | 10,000,000 | 2025-08-01 | 2025-08-15 | Business travel |
| DEL-2025-003 | Grant Albrecht | Simone Tremblay (Director, Distribution Operations) | Operating expense | 500,000 | 2025-06-02 | 2025-06-13 | Vacation |
| DEL-2025-004 | Priscilla Adeyemi (VP, US Operations) | Kevin Rourke (Director, New York Field Services) | Vendor contract | 1,000,000 | 2025-09-02 | 2025-09-12 | Medical leave |
| DEL-2025-005 | Martin Szabo (CIO) | Aisha Rahman (Director, IT Infrastructure) | IT software | 1,000,000 | 2025-05-19 | 2025-05-30 | Conference |
| DEL-2025-006 | Helena Park | Owen Gallagher (Director, Treasury) | Capital project | 1,000,000 | 2025-10-06 | 2025-10-17 | Vacation |
| DEL-2025-007 | Simone Tremblay | Lucas Ferreira (Manager, Line Operations) | Operating expense | 100,000 | 2025-07-28 | 2025-08-08 | Vacation |
| DEL-2025-008 | Kevin Rourke | Maya Lindqvist (Manager, Albany Crews) | Emergency restoration procurement | 500,000 | 2025-11-03 | 2025-11-14 | Training |
| DEL-2025-009 | Colette Brisebois (Chief People Officer) | Nathan Oduya (VP, Talent) | Consulting services | 300,000 | 2025-08-18 | 2025-08-29 | Vacation |
| DEL-2025-010 | Aisha Rahman | Deepak Sethi (Manager, Cloud Platforms) | IT software | 75,000 | 2025-06-16 | 2025-06-27 | Vacation |
| DEL-2025-011 | Owen Gallagher | Julia Mancuso (Manager, Cash Management) | Operating expense | 100,000 | 2025-12-22 | 2026-01-02 | Holiday coverage |
| DEL-2025-012 | Theresa Nakamura (VP, Regulatory Affairs) | Benoit Lavigne (Director, Rate Applications) | Consulting services | 300,000 | 2025-09-15 | 2025-09-26 | OEB hearing preparation |
| DEL-2025-013 | Marcus Oyelaran (Director, Ohio Field Services) | Carla Jennings (Manager, Akron Crews) | Vendor contract | 250,000 | 2025-10-20 | 2025-10-31 | Vacation |
| DEL-2025-014 | Eleanor Voss (President and CEO) | Rajiv Menon (CFO) | Capital project | 5,000,000 | 2025-11-17 | 2025-11-21 | Business travel |
| DEL-2025-015 | Ingrid Solberg (Director, Procurement) | Tobias Wren (Manager, Strategic Sourcing) | Vendor contract | 250,000 | 2025-08-04 | 2025-08-15 | Parental leave coverage |

Useful checks: DEL-2025-012 (Director-level delegate, consulting, 300,000) is consistent with Note 8 because the delegator is a VP. DEL-2025-014: CEO delegates capital authority of 5,000,000 (the CFO limit); the CEO is not a column in the matrix. Only one delegation spans a year boundary (DEL-2025-011).

### 2.4 `Corporate-Card-Guidelines.pdf`
Summary: corporate card rules, 2 pages, text-based PDF (reportlab). Document ID HLE-FIN-103, owner Finance, Office of the Controller, effective 2025-03-01, version 2.1.

| Fact | Section |
|---|---|
| Issuer: Northstar Commercial Card | 1. Purpose |
| Eligibility: travels at least four times a year or buys low-value goods for team; Director approval; request via Workday service catalogue | 2. Eligibility |
| Travel card: single transaction 5,000, monthly 15,000 (CAD or USD) | 3. Card types and limits |
| Purchasing card: single 2,500, monthly 10,000 | 3 |
| Storm response card: single 10,000, monthly 50,000; active only during a declared emergency | 3 |
| Temporary limit increase: Director approval, max 30 days | 3 |
| Prohibited: personal purchases, cash advances, gift cards, split purchases, vendors with an active contract (use PO), payments to individuals | 5. Prohibited use |
| Statement closes on the 25th; reconcile in Workday within 10 business days; manager approves within 5 business days | 6. Reconciliation |
| Lost or stolen: Northstar 1-800-555-0177 (24 hours); notify cards@harbourline.example within 24 hours | 7. Lost or stolen cards |
| Non-compliance: 1st written reminder; 2nd within 12 months 60-day suspension; 3rd cancellation and referral to People and Culture; fraud immediate cancellation | 8. Non-compliance |
| Unreconciled transactions older than 60 days: automatic suspension | 8 |
| Return card before last day or role change | 9 |

### 2.5 `Capital-Project-Approval.docx`
Summary: stage-gate capital approval procedure. Document ID HLE-FIN-104, owner Finance, Capital Planning and Investment, effective 2025-02-01, version 4.0.

| Fact | Section |
|---|---|
| Applies to projects with total cost CAD 50,000 or more (USD 50,000 US) | 1. Purpose and scope |
| Capital Investment Committee (CIC): chaired by CFO, plus COO, VP Regulatory Affairs, VP Asset Management, Director of Capital Planning; meets monthly on the second Tuesday | 2. Governance |
| Gates: G0 Idea (Director), G1 Concept (CIC, up to 5 percent for studies, Class 4 estimate), G2 Business case (CIC plus Approval Matrix approver, up to 20 percent for design and long-lead, Class 3), G3 Execution approval (Approval Matrix approver, full budget, Class 2), G4 Close-out (CIC) | 3. Stage gates |
| Re-approval trigger: overrun of more than 10 percent or more than CAD 500,000, whichever is lower | 3 |
| Contingency: 20 percent Class 4, 15 percent Class 3, 10 percent Class 2 | 4. Business case requirements |
| NPV at corporate discount rate 6.5 percent; at least three options including do-nothing; 5 by 5 risk matrix; SAIDI and SAIFI | 4 |
| OEB: prudent and used and useful; five-year Distribution System Plan; categories System Access, System Renewal, System Service, General Plant | 5. Ontario Energy Board rate-base considerations |
| Ontario projects above CAD 1,000,000 need a rate-application project summary | 5 |
| Incremental Capital Module request confirmed by Regulatory Affairs before G2 | 5 |
| Rate base only when in service; CWIP earns no return until then; records kept at least 7 years | 5 |
| US: NY/OH PSC rate cases; transmission follows FERC formula rates | 5 |
| Post-implementation review 12 months after in-service for projects above CAD 1,000,000 | 6. Post-implementation review |

Cross-document consistency: Capital project approval limits come from the Approval Matrix (Manager 50,000 up to CFO 5,000,000, Board above). Both Finance docs agree.

---

## 3. Vendors list (`data/sharepoint/Harbourline-Hub/Vendors.csv`)

Summary: 2,600 data rows plus header, UTF-8. Columns: Title, VendorId, Category, Region, ContractValue, Currency, Status, RenewalDate, PrimaryContact, ContactEmail, RiskRating. VendorId V-00001 to V-02600 in row order. Data row N = VendorId V-N = file line N+1. Currency is CAD for Ontario and USD for New York and Ohio. Titles are unique. Random rows have ContractValue at most 4,800,000.

Relevant limit: CS-K10 (reference/limits.md): SharePoint list knowledge queries use the first 2,048 rows. Rows 2,049 to 2,600 (552 rows) are outside that window.

### 3.1 Planted rows

| Data row | VendorId | Title | Category | Region | ContractValue | Currency | Status | RenewalDate | PrimaryContact | ContactEmail | Risk | Window |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 12 | V-00012 | Lakeshore Arborist Collective Inc. | Vegetation Management | Ontario | 2975000 | CAD | Suspended | 2026-05-31 | Genevieve Marchetti | genevieve.marchetti@lakeshore-arborist-collective.example | High | inside |
| 777 | V-00777 | Mohawk Valley Meter Works LLC | Metering | New York | 4850000 | USD | Active | 2026-11-30 | Desmond Achterberg | desmond.achterberg@mohawk-valley-meter-works.example | Low | inside |
| 1500 | V-01500 | Tri-County Fleet Upfitters Inc. | Fleet | Ohio | 1735500 | USD | Pending Review | 2026-02-15 | Rowena Castellanos | rowena.castellanos@tri-county-fleet-upfitters.example | Medium | inside |
| 2049 | V-02049 | Buckeye Substation Engineering Group LLC | Engineering Consulting | Ohio | 3310000 | USD | Active | 2027-01-31 | Ignatius Pemberton | ignatius.pemberton@buckeye-substation-engineering-group.example | High | outside (first row past the window) |
| 2501 | V-02501 | Northgate Pole & Crossarm Ltd. | Line Construction | Ontario | 7425000 | CAD | Active | 2027-03-31 | Renata Kowalczyk | renata.kowalczyk@northgate-pole-crossarm.example | High | outside |
| 2600 | V-02600 | Adirondack Transformer Rebuild Co. | Transformers | New York | 5960000 | USD | Expired | 2025-06-30 | Philippa Vandersloot | philippa.vandersloot@adirondack-transformer-rebuild.example | Medium | outside (last row) |

Planted names and contacts are unique across the file (no random row reuses these contact names; "Northgate" appears only in row 2,501).

### 3.2 Eval hooks
- "Who is the contact for Northgate Pole & Crossarm?" Correct: Renata Kowalczyk. An agent limited to the first 2,048 rows will not find it.
- Largest ContractValue in the full list: V-02501 Northgate, 7,425,000 CAD. Second: V-02600 Adirondack, 5,960,000 USD. Third: V-00777 Mohawk Valley, 4,850,000 USD. Within the first 2,048 rows the largest is V-00777 Mohawk Valley (4,850,000 USD). (Values are compared numerically, ignoring currency.) Next largest random rows: V-00937 Nipissing Power Equipment Ltd. 4,758,500 CAD; V-00223 Granite Oxford Substation Supply Limited 4,757,000 CAD.
- Lakeshore Arborist Collective (row 12) is Suspended and High risk: a good "should we use this vendor?" check.

### 3.3 Aggregates (printed by the generator)

| Measure | All 2,600 rows | First 2,048 rows | Rows 2,049 to 2,600 |
|---|---|---|---|
| Status Active / Expired / Suspended / Pending Review | 1820 / 378 / 130 / 272 | 1435 / 294 / 104 / 215 | 385 / 84 / 26 / 57 |
| Region Ontario / New York / Ohio | 1285 / 784 / 531 | 1021 / 604 / 423 | 264 / 180 / 108 |
| Risk Low / Medium / High | 1378 / 972 / 250 | 1079 / 770 / 199 | 299 / 202 / 51 |
| High risk AND Active | 176 | 144 | 32 |
| High risk AND Suspended | 17 | 14 | 3 |
| Line Construction in Ontario | 128 | 104 | 24 |
| Engineering Consulting in Ohio | 60 | 43 | 17 |
| Transformers in New York | 68 | 52 | 16 |

Category totals (all rows): Line Construction 284, Vegetation Management 271, IT Services 252, Metering 275, Fleet 255, Engineering Consulting 270, Safety Equipment 241, Transformers 232, Facilities 231, Professional Services 289.

---

## 4. Deliberate defects in this area (summary)

1. `Approval-Matrix.xlsx` cell D8 (Consulting services, Director) = 150,000; `Approval-Matrix.docx` says 75,000. The docx revision history (v3.2, 2025-04-01) explains the reduction, so the docx is current.
2. `Vendors.csv` has 2,600 rows; planted rows 2,049, 2,501 and 2,600 are outside the 2,048-row query window (CS-K10).
3. Getting-Started: no defects (clean by design).
