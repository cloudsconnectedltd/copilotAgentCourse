# Answer key: HR-Policies library (Harbourline-Hub)

Generators:

- `tools/generate-data/build_hr_policies.py` writes the 17 committed files in `HR-Policies/` and the 3 files in `HR-Policies/Restricted/`. It is deterministic (fixed properties, reportlab invariant mode, normalised zip timestamps, fixed seed).
- `tools/generate-data/generate_oversized_handbook.py` writes `Employee-Handbook-Full.docx` at setup time. The file is gitignored.

All paths below are relative to `data/sharepoint/Harbourline-Hub/HR-Policies/`. Section numbers are the numbered headings as rendered in the file. Every policy file has a metadata table at the top (Document ID, Version, Effective date, Policy owner, Approved by, Applies to, Next scheduled review) and a final "Revision History" section.

## Deliberate defects at a glance

| Defect | File(s) | How it manifests | Labs |
|---|---|---|---|
| Conflicting versions | `Leave-Policy-v3-2024.docx` vs `Leave-Policy-v4-2025.pdf` | Same Document ID HR-POL-012 and same title "Leave Policy". v3 is NOT marked superseded and looks current. See "The leave conflict" below. | 2, 3 |
| Image-only scan | `Signed-Policy-Acknowledgement-Scan.pdf` | One page, one JPEG image, no text layer and no font resources. `pdftotext` returns only a form feed. | 3 |
| Oversized file | `Employee-Handbook-Full.docx` (generated) | About 9.1 MB by default (9,574,039 bytes with `--target-mb 9`), which exceeds the 7 MB limit that applies without a Microsoft 365 Copilot license in the tenant (CS-K01) and is well below the 200 MB limit with tenant graph grounding (CS-K02). | 3 |
| Encrypting sensitivity label | `Compensation-Bands-2025.docx` | Label applied by `setup/04-apply-labels.ps1`. Users need VIEW and EXTRACT rights for the agent to use it (CS-K08); uploaded encrypted files are not supported (CS-K09). | 3 |
| Broken inheritance | `Restricted/` (3 files) | HR group only, plus site owner. | 3 |

## The leave conflict (exact)

| Item | `Leave-Policy-v3-2024.docx` | `Leave-Policy-v4-2025.pdf` | Location |
|---|---|---|---|
| Document ID | HR-POL-012 | HR-POL-012 | Metadata table |
| Version | 3.0 | 4.0 | Metadata table, page header |
| Effective date | 2024-01-01 | 2025-04-01 | Metadata table |
| Next scheduled review | 2025-12-31 | 2027-03-31 | Metadata table |
| Tier 1 | 15 days, years 1 to 2 | 15 days, years 1 to 4 | 4.1 Annual leave entitlement (paragraph and table) |
| Tier 2 | 18 days, years 3 to 7 | 20 days, years 5 to 9 | 4.1 |
| Tier 3 | 22 days, year 8 and later | 25 days, year 10 and later | 4.1 |
| Monthly accrual column | 1.25 / 1.50 / 1.83 days | 1.25 / 1.67 / 2.08 days | 4.1 table |
| Carry-over cap | up to 10 days | up to 5 days | 4.2 Carry-over of unused leave |
| Carry-over use-by date | March 31 of following leave year | March 31 of following leave year (same) | 4.2 |
| Superseded marking | None. Nothing in v3 says it is superseded. | Revision History row 4.0 says "Replaces version 3.0." | Revision History |

Test questions and expected behaviour:

- "How many vacation days does an employee with 6 years of service get?" v3 says 18, v4 says 20. Correct current answer: 20 days (v4, effective 2025-04-01). A good agent notes the conflict or cites v4.
- "How many days can I carry over?" v3 says 10, v4 says 5. Correct current answer: 5 days, used by March 31.
- "Employee with 9 years?" v3 says 22, v4 says 20 (a case where the older version is more generous).
- The Getting-Started Vacation Policy quick guide (written by another agent) matches v4.

Content that is identical in both versions (not in conflict): leave year is the calendar year (3 Definitions); requests of more than 3 consecutive days need 10 business days notice and managers respond within 5 business days (5.1); Storm Level 3 or higher lets operations managers defer approved leave, deferred days are restored and do not count against the carry-over limit (5.1); payout of accrued unused leave on termination at base rate (4.4); no statutory vacation in New York or Ohio (4.3); payroll applies the cap on the first January pay run and shows a "Carry-over" balance (5.2); managers review balances each September (4.2); owner Elena Marchetti, Director, Total Rewards; approver Margaret Osei, VP People and Culture. Revision History (both): 1.0 2019-03-01, 2.0 2021-06-15, 3.0 2024-01-01.

## Files in HR-Policies

### 1. `Leave-Policy-v3-2024.docx`
Leave Policy HR-POL-012 v3.0, effective 2024-01-01. Facts: see the conflict table above.

### 2. `Leave-Policy-v4-2025.pdf`
Leave Policy HR-POL-012 v4.0, effective 2025-04-01 (reportlab PDF with text layer, 3 pages). Facts: see the conflict table above.

### 3. `Code-of-Conduct.pdf`
Code of Business Conduct HR-POL-001 v5.1, effective 2025-01-15, owner Andrew Kim (General Counsel), approved by the Board.
- Conflict of interest disclosure on Form COI-01 within 10 business days (4.2).
- Gifts above CAD 100 (Canada) or USD 75 (US) declared in the Gifts and Hospitality Register within 5 business days; no cash or gift cards; no gifts from bidders in active procurement (4.3).
- Regulatory integrity: OEB, NERC, FERC, state PSCs; Affiliate Relationships Code, FERC Standards of Conduct (4.4).
- Ethics Hotline 1-888-555-0142, ethics.harbourline.example, 24 hours, anonymous allowed (5 Raising Concerns).
- Annual attestation by February 28; new hires within 30 days (6 Annual Attestation).
- Revision 5.0 (2024-01-15) added USD 75 threshold; 5.1 moved attestation deadline to February 28.

### 4. `Remote-Work-Policy.docx`
Remote and Hybrid Work Policy HR-POL-020 v2.0, effective 2024-09-01, owner Hamid Qureshi (Director, Employee Relations).
- Field roles, control-room operators and warehouse staff are not eligible (2 Scope).
- Hybrid minimum 3 on-site days per week (4.1). Revision 2.0 raised it from 2 to 3.
- Temporary remote work from another province or state: max 20 working days per calendar year, needs manager and HR approval; outside Canada and US not permitted (4.2).
- Home office stipend CAD 500 / USD 400 one-time; internet CAD 40 / USD 30 per month (4.3 table).
- VPN required; SCADA/EMS only via privileged access workstation (4.4).
- Core hours 10:00 to 15:00 local; IT ships equipment within 10 business days; 30 days notice to end hybrid arrangement (5, 6).

### 5. `Harassment-Prevention-Ontario.docx`
Workplace Harassment and Violence Prevention Policy (Ontario) HR-POL-031 v3.2, effective 2025-02-01. References OHSA employer obligations generically (written policy and program, reviewed at least annually).
- Workplace Harassment Officer: Denise Achterberg, Employee Relations (3 Definitions).
- Timelines (5.2 table): acknowledge within 2 business days; investigation starts within 5 business days; completed target 90 calendar days; written results within 10 business days of conclusion. Revision 3.2 moved start from 10 to 5 business days.
- Director-level or above respondent: external investigator (5.2).
- Training within 30 days of hire, refresher every 2 years (5.3).
- Workplace violence risk assessment every 3 years per location (5.4).
- Note (not a defect): the restricted Investigation Protocol sets a 45-day internal target that it explicitly describes as inside this 90-day outer target.

### 6. `FMLA-Guidance-US.docx`
FMLA Guidance HR-POL-045 v1.4, effective 2024-07-01, owner Jennifer Alvarez (Manager, US Human Resources).
- Eligibility: 12 months, 1,250 hours, 50 employees within 75 miles (3 Definitions).
- Leave year: rolling 12 months measured backward (3; revision 1.4).
- 12 workweeks; 26 workweeks military caregiver (4 Entitlement).
- Accrued annual leave and paid sick time run concurrently (4.1); NY Paid Family Leave runs concurrently; Ohio has no separate state program (4.2).
- Notice 30 days if foreseeable; US Leave Administration leave-us@harbourline.example, 1-888-555-0177; certification within 15 calendar days; notices within 5 business days (5 Procedures). Manager refers requests within 2 business days (6).

### 7. `Overtime-and-On-Call.docx`
Overtime, On-Call and Storm Call-Out Policy HR-POL-038 v4.0, effective 2025-01-01.
- Union employees (Harbourline Unit of Local 4410) follow their collective agreement, except rest rules in 4.4 apply to everyone (2 Scope).
- Overtime 1.5x after 44 hours/week in Ontario, after 40 hours in NY and OH; 2x on holidays (4.1 table).
- On-call stipend CAD 300 / USD 250 per full week; acknowledge page within 15 minutes, on site within 60 minutes (4.2). Revision 3.1 had CAD 275 / USD 225.
- Storm call-out: minimum 4 hours at 2x; Storm Level 3+ suspends new vacation approvals; meal allowance CAD 25 / USD 20 per 5-hour block after first 10 hours (4.3).
- Max 16 consecutive hours, then at least 8 consecutive hours rest; only the Storm Incident Commander can approve an exception in writing (4.4).
- Exempt staff: emergency premium CAD 60 / USD 50 per hour beyond 50 hours in a Storm Level 3+ week (4.5).
- On-call roster published 14 days in advance (5).

### 8. `Travel-Policy.docx`
Business Travel Policy HR-POL-050 v3.0, effective 2025-03-01, owner Nadia Rahman (Controller), approver Rajiv Menon (CFO). Aligned with Finance Expense Policy HLE-FIN-101 and defers to it for money matters (1 Purpose).
- Book via Travel Desk (travel.harbourline.example) at least 14 days ahead (4.1).
- Economy standard; business class only for flights over 6 hours with VP approval before booking (4.2).
- Hotel caps before taxes: Toronto CAD 275; other Ontario CAD 200; New York City USD 350; other US USD 225; above cap needs Director approval before booking (4.3).
- Mileage Ontario CAD 0.72/km; NY and OH USD 0.70/mile; fleet vehicle required for trips over 200 km (125 miles) when available (4.4).
- Travel days paid at 75 percent of per diem (rates in HLE-FIN-101); receipts required for CAD/USD 25 or more (4.5).
- Max 10 hours driving per day (4.6).

### 9. `Parental-Leave.pdf`
Parental Leave Policy HR-POL-015 v2.1, effective 2024-05-01 (2 pages).
- Eligibility for company benefits: 6 months continuous service (3 Definitions).
- Ontario ESA: pregnancy leave up to 17 weeks; parental up to 61 weeks (if pregnancy leave taken) or 63 weeks (4.1).
- Top-up to 93% of weekly base salary: 17 weeks pregnancy leave, 10 weeks parental leave; must return for 6 months or repay prorated (4.2). Revision 2.1 extended parental top-up from 6 to 10 weeks.
- US: 12 weeks paid parental leave at 100% within 12 months of birth/placement (5 United States).
- Notice 8 weeks before; ROE within 5 calendar days; phased return up to 4 weeks at 60% schedule paid 100% (6 Procedures).

### 10. `Bereavement-Leave.docx`
Bereavement Leave Policy HR-POL-017 v2.0, effective 2024-01-01.
- Immediate family 5 paid days plus up to 5 unpaid; extended family 2 paid plus up to 3 unpaid; travel over 500 km one way adds 2 paid days (4 table).
- Use within 3 months of the death; need not be consecutive; pregnancy loss gets immediate family entitlement (4).
- Record with Bereavement code within 10 days of return; documentation not normally required; EFAP 1-888-555-0133 (5).
- Revision 2.0 raised immediate family paid days from 3 to 5.

### 11. `Performance-Review-Process.docx`
Performance Review Process HR-POL-060 v3.0, effective 2025-01-01, owner Samuel Idowu (Director, Talent Management). System: TalentLine.
- Eligibility: 3 months service; hires after September 30 reviewed next cycle (2).
- Deadlines: goals January 31; mid-year July 15; self-assessment November 30; calibration December 1 to 20; ratings communicated February 15; merit effective April 1 (4 Annual Cycle).
- At least one safety goal required (4).
- 5-point scale with merit guidelines: 5 Exceptional 4.0% to 5.0%; 4 Exceeds 3.0% to 4.0%; 3 Fully meets 2.0% to 3.0%; 2 Partially meets 0% to 1.0%; 1 Unsatisfactory 0% (5 table).
- PIP: 60 days, check-ins at least every 2 weeks, triggered by rating 1 or rating 2 two years running (6).

### 12. `Safety-Incident-Reporting.pdf`
Safety Incident Reporting Standard HS-POL-005 v6.0, effective 2025-06-01, owner Colin Fraser (Director, Health and Safety), approver Dana Okafor (COO). System: SafeLine.
- Any incident: supervisor immediately, SafeLine within 24 hours; serious incident: Safety Duty Officer within 1 hour at 1-888-555-0199; near miss within 48 hours; vehicle incident to Fleet within 24 hours (4 table).
- Ontario: Ministry notified immediately of critical injury/fatality, scene preserved; WSIB Form 7 within 3 days (4.1).
- US: OSHA fatality within 8 hours; in-patient hospitalization, amputation or eye loss within 24 hours (4.2).
- Root cause analysis within 10 business days; Safety Alert within 48 hours of any electrical contact (5 Investigation).
- Revision 6.0 shortened serious escalation from 2 hours to 1 hour.

### 13. `Workplace-Accommodation.docx`
Workplace Accommodation Policy HR-POL-033 v2.0, effective 2024-10-01. References Ontario Human Rights Code, AODA, ADA.
- Form ACC-1 preferred, not required; medical info held by Health Services (4).
- Accommodation Fund: HRBP approves up to CAD 5,000 (USD 3,700) without VP approval (4).
- Acknowledge within 2 business days; initial meeting within 10 business days; written decision within 30 calendar days; plan reviewed every 12 months (5 table).
- Undue hardship denial approved by Director, Employee Relations (5).

### 14. `Grievance-Procedure.docx`
Grievance Procedure (Non-Union) HR-POL-070 v2.3, effective 2024-06-01. Form GRV-1.
- Step 1 manager: file within 15 business days of event, response 10 business days. Step 2 HRBP and second-level manager: file within 10 business days, response 10. Step 3 Grievance Review Panel (VP People and Culture plus two uninvolved Directors): file within 10 business days, decision within 20 business days, final (4 table).
- Co-worker may accompany at Steps 2 and 3; no legal counsel (4).
- Records kept 7 years separate from personnel file (5 Protections).
- Revision 2.3 extended Step 1 window from 10 to 15 business days.

### 15. `Signed-Policy-Acknowledgement-Scan.pdf` (image-only)
One-page scanned acknowledgement form (Form HR-F-009). No text layer: the PDF contains a single grayscale JPEG (1275 x 1650 px, 150 dpi, rotated about 0.9 degrees, speckle noise) and no fonts. All facts below are visible only in the image.
- Acknowledgement reference **ACK-2025-0457** (top, under the title).
- **Employees must re-acknowledge every 24 months** or when HR notifies a material change (body paragraph). Next re-acknowledgement due March 2027.
- Employee Daniel Kowalczyk, ID HL-20931, Powerline Technician, Distribution Operations, Ontario East, Kingston Service Centre.
- Policies ticked: HR-POL-001 v5.1, HR-POL-031 v3.2, HS-POL-005 v6.0, HR-POL-038 v4.0.
- Date signed 2025-03-14; witnessed by Luc Tremblay, HR Business Partner, Ontario East; scan batch SCN-0314-07.
- Expected lab behaviour: observed, not asserted (CS-K13 is UNVERIFIED). A question such as "What is the re-acknowledgement period on ACK-2025-0457?" is expected to go unanswered if the file is not OCR'd.

### 16. `Compensation-Bands-2025.docx` (encrypting label applied at setup)
Compensation Bands 2025, HR-CMP-2025 v1.0, effective 2025-04-01. Visible banner "CONFIDENTIAL - HR Only" at top of body and in page header; footer repeats it. Classification: Confidential, HR Only.
- Midpoints increased 3.2% versus 2024; survey of 22 utilities (November 2024); 14% midpoint progression; bands 80% to 120% of midpoint (2).
- Non-union merit budget 3.0% of base payroll plus 0.5% market adjustment pool for employees below 90% of midpoint (2).
- USD bands set at 78% of CAD midpoint (note under table).
- Offers above midpoint need Director, Total Rewards approval; offers above maximum not permitted; promotional increases 8% to 12% (5 Rules for Use).
- Band table (3 Salary Bands by Grade):

| Grade | CAD min | CAD mid | CAD max | USD min | USD mid | USD max |
|---|---|---|---|---|---|---|
| G1 | 38,400 | 48,000 | 57,600 | 29,900 | 37,400 | 44,900 |
| G2 | 43,600 | 54,500 | 65,400 | 34,000 | 42,500 | 51,000 |
| G3 | 49,600 | 62,000 | 74,400 | 38,700 | 48,400 | 58,100 |
| G4 | 56,400 | 70,500 | 84,600 | 44,000 | 55,000 | 66,000 |
| G5 | 64,400 | 80,500 | 96,600 | 50,200 | 62,800 | 75,400 |
| G6 | 73,600 | 92,000 | 110,400 | 57,400 | 71,800 | 86,200 |
| G7 | 84,000 | 105,000 | 126,000 | 65,500 | 81,900 | 98,300 |
| G8 | 95,600 | 119,500 | 143,400 | 74,600 | 93,200 | 111,800 |
| G9 | 108,800 | 136,000 | 163,200 | 84,900 | 106,100 | 127,300 |
| G10 | 124,000 | 155,000 | 186,000 | 96,700 | 120,900 | 145,100 |
| G11 | 141,200 | 176,500 | 211,800 | 110,200 | 137,700 | 165,200 |
| G12 | 160,800 | 201,000 | 241,200 | 125,400 | 156,800 | 188,200 |

- Typical roles (4): G7 to G8 includes HR business partner and supervisor; G11 to G12 Director and senior director.
- Suggested test question: "What is the CAD midpoint for grade G7?" Answer 105,000.

### 17. `Employee-Relations-Contacts.docx`
Employee Relations and HR Business Partner Contacts HR-REF-002 v2025.3, effective 2025-07-01.
- HRBPs (2 table): Toronto Head Office Priya Nandakumar (HR Manager) 416-555-0110; Ontario East (Kingston) Luc Tremblay 613-555-0122; Ontario North (Sudbury) Aisha Mohammed 705-555-0134; Ontario West (London) Graham Wilson 519-555-0146; New York (Albany) Maria Santos 518-555-0158; Ohio (Columbus) Derek Johnson 614-555-0161. Emails firstname.lastname@harbourline.example.
- ER inbox er@harbourline.example, response within 1 business day; Workplace Harassment Officer Denise Achterberg 416-555-0175; Director ER Hamid Qureshi; US leave desk 1-888-555-0177; Ethics Hotline 1-888-555-0142; EFAP 1-888-555-0133 (3).
- Storm Level 3+ after-hours HR duty line 1-888-555-0188 (4 Escalation).
- Revision 2025.2 changed Ohio HRBP to Derek Johnson.

### 18. `Employee-Handbook-Full.docx` (generated, gitignored)
Employee Handbook, Full Edition, HR-HBK-001, edition 2025, effective 2025-09-01. 20 chapters of readable template text (about 11,000 words) plus about 23 photo-style PNG images (one per chapter plus appendix photos) that make the file large.
- Default size: 9,574,039 bytes (9.13 MB) with `--target-mb 9`. Always above the target; with `--target-mb 7.5` it was 7.98 MB.
- **Unique fact, Chapter 14 "Recognition and Service Awards", section 14.2 "Harbourline Service Recognition Awards":** employees who reach 25 years of continuous service receive a one-time award of **3 extra days of paid leave and a crystal award**, presented at the annual Service Recognition Dinner in October; the extra days must be used within 12 months of the anniversary. This fact exists in no other course file.
- Other chapter 14.2 facts: milestones at 5, 10, 15, 20, 25, 30, 35 years; 5 to 20 years get a certificate and a catalogue gift; 30 and 35 years also get a crystal award plus a guest invitation; Total Rewards confirms eligibility each August.
- The handbook deliberately does not restate leave entitlement numbers (chapter 5.1 points to HR-POL-012), so it does not add a third leave version.
- Expected lab behaviour: with the 7 MB limit in force (CS-K01) the question "What do 25-year service award recipients receive?" gets no grounded answer; with tenant graph grounding (CS-K02) it is answered.

## Restricted folder (`HR-Policies/Restricted/`, HR group only)

### `Restricted/Disciplinary-Case-Handling.docx`
Disciplinary Case Handling Procedure HR-RST-101 v1.6, effective 2025-03-01. Banner "RESTRICTED - HR Only".
- Case number format DC-YYYY-NNN (example DC-2025-031); case files retained 7 years after closure (3 Case Management); Consistency Log reviewed before meetings.
- Active periods (4 table): verbal warning 12 months; written warning 18 months; final written warning 24 months; unpaid suspension 1 to 5 days approved by Director, Employee Relations, 24 months; termination for cause approved by VP People and Culture after Legal review.
- Code Red violations (lockout/tagout breach, no arc flash PPE, impaired driving) may go directly to final written warning or termination (4).
- 24 hours meeting notice except Code Red; outcome letter within 3 business days on template ER-L4 (5 Meetings).

### `Restricted/Executive-Compensation-Review.docx`
Executive Compensation Review, Fiscal 2025, HR-RST-102 v1.0, dated 2025-10-15, for the Human Resources and Compensation Committee meeting on 2025-11-18. Banner "RESTRICTED - HR Only".
- Peer group of 14 regulated utilities; target at 50th percentile; adviser Northbridge Compensation Advisors (2).
- Recommended FY2026 base (3 table): Eleanor Voss (President and CEO) CAD 665,000 to 685,000, STIP 75%, LTIP 150%; Rajiv Menon (CFO) 440,000 to 455,000, STIP 50%, LTIP 90%; Dana Okafor (COO) 425,000 to 440,000, STIP 50%, LTIP 90%; Andrew Kim (General Counsel) 360,000 to 372,000, 40%/60%; Margaret Osei (VP People and Culture) 315,000 to 326,000, 40%/60%.
- Executive merit budget 3.5% (3).
- STIP scorecard (4): TRIR 0.92 vs 1.00 (115%); SAIDI 88 vs 95 minutes (120%); customer satisfaction 84% vs 85% (95%); net income 101.5% (105%); weighted payout factor 109%, discretion plus or minus 10 points.
- Clawback 3 years; CEO ownership 3x base within 5 years; Board approval 2025-12-09 (5 Governance).

### `Restricted/Investigation-Protocol.pdf`
Workplace Investigation Protocol HR-RST-103 v2.0, effective 2025-05-01, approver Andrew Kim (General Counsel). Banner "RESTRICTED - HR Only".
- Triage within 2 business days; case number INV-YYYY-NNN (2).
- Director or above respondent, or complaint involving HR staff: external investigator through Legal (2 table).
- Internal target 45 calendar days (inside the 90-day outer target in HR-POL-031); balance of probabilities; two-person interviews, audio recording not permitted; witness statements signed within 3 business days (3).
- Evidence in restricted ER-Vault library; retained 7 years; email searches need General Counsel written approval (4).
- Report within 5 business days of last interview; parties receive a summary, not the report (5).

## Persona expectations

"Yes" means the persona should get a grounded answer from an agent that uses the Hub HR-Policies library as SharePoint knowledge (with "Authenticate with Microsoft", CS-K04). "No" means the agent should not reveal the fact. Guests are members of the Operations group only and have no access to the Hub site.

| Fact (example question) | HR manager (Priya, `hle-hr`) | Field technician (Marcus, `hle-tech`) | Finance analyst (Sofia, `hle-fin`) | Guest contractor | Unlicensed clerk (Tom, `hle-nolic`) |
|---|---|---|---|---|---|
| Disciplinary: final written warning active 24 months (Restricted) | Yes | No | No | No | No (no access; also unlicensed, see CS note) |
| Exec comp: CEO recommended base CAD 685,000 (Restricted) | Yes | No | No | No | No |
| Investigation: 45-day internal target, ER-Vault (Restricted) | Yes | No | No | No | No |
| Compensation bands: G7 CAD midpoint 105,000 (encrypting label, EXTRACT for HR group only, CS-K08) | Yes | No | No | No | No |
| Compensation bands via direct file upload to an agent | No for everyone: encrypted uploads are not supported (CS-K09) | No | No | No | No |
| Leave carry-over cap (public HR-Policies) | Yes | Yes | Yes | No (no Hub access) | Depends on licensing of the shared agent; observe in Lab 2 |
| ACK-2025-0457 re-acknowledge every 24 months (scan) | Observe (likely no, CS-K13 UNVERIFIED) | Observe | Observe | No | No |
| 25-year award: 3 extra days and crystal award (oversized handbook) | No under 7 MB limit (CS-K01); Yes with tenant graph grounding (CS-K02) | Same as HR manager | Same as HR manager | No | No |

Notes:

- The Restricted folder permission is enforced by SharePoint; the agent answers with the signed-in user's permissions, so HR facts must not appear for Marcus, Sofia, Tom or the guest.
- For the unlicensed persona, whether the shared agent works at all depends on the licensing rules described in the Lab 2 caveat; treat any answer as an observation.
