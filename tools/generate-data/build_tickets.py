#!/usr/bin/env python3
"""Generate the Harbourline service ticket source for the Lab 7 Copilot connector.

Reads:   data/dataverse/Assets.csv   (run build_dataverse.py first; asset tags are shared)
Writes:  data/connector/tickets-seed.sql   T-SQL seed for database HarbourlineTickets
         data/connector/tickets.csv        flat export with an AclJson column
         data/connector/_facts.json        computed aggregates used to write the answer key

Deterministic (fixed seed). Re-run: python3 tools/generate-data/build_tickets.py

ACL principal values are placeholder tokens that ingest-tickets.ps1 substitutes at run time:
  {{GROUP_OPS_ONTARIO}} {{GROUP_OPS_US}} {{GROUP_HR}} {{GROUP_FINANCE}} {{USER_FIN}} {{TENANT_ID}}
"""
import csv
import json
import os
import random
import sys
from collections import Counter
from datetime import datetime, timedelta

SEED = 20260930
NOW = datetime(2026, 9, 30, 17, 0, 0)
START = datetime(2025, 1, 2, 7, 0, 0)
TICKET_COUNT = 5000
FIRST_ID = 100001
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "data", "connector")
ASSETS_CSV = os.path.join(ROOT, "data", "dataverse", "Assets.csv")
BASE_URL = "https://tickets.harbourline.example"

rng = random.Random(SEED)

REGIONS = [
    (1, "ON", "Ontario", "Canada"),
    (2, "NY", "New York", "United States"),
    (3, "OH", "Ohio", "United States"),
]
REGION_ID = {r[2]: r[0] for r in REGIONS}
REGION_CODE = {r[2]: r[1] for r in REGIONS}

# Operational sites come from build_dataverse.py (same codes as Assets.csv). Offices added for corporate tickets.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_dataverse import SITES as DV_SITES  # noqa: E402

SITES = []
for _reg_code, _reg_name in (("ON", "Ontario"), ("NY", "New York"), ("OH", "Ohio")):
    for _code, _name, _city, _kind in DV_SITES[_reg_code]:
        SITES.append((_code, _name, _city, _reg_name, "Depot" if _kind == "depot" else "Station"))
SITES += [
    ("TORHO", "Toronto Head Office", "Toronto", "Ontario", "Office"),
    ("ALBRO", "Albany Regional Office", "Albany", "New York", "Office"),
    ("COLRO", "Columbus Regional Office", "Columbus", "Ohio", "Office"),
]
SITE_ID = {s[0]: i + 1 for i, s in enumerate(SITES)}
SITE_BY_CODE = {s[0]: s for s in SITES}
OFFICE = {"Ontario": "TORHO", "New York": "ALBRO", "Ohio": "COLRO"}

OPS_CATEGORIES = ["Field Operations", "Outage", "Asset Maintenance", "Customer Complaint"]
CATEGORY_WEIGHTS = [
    ("Field Operations", 34), ("Outage", 14), ("Asset Maintenance", 12), ("Customer Complaint", 4),
    ("Safety", 5), ("IT Service Desk", 12), ("Facilities", 8), ("HR Case", 6), ("Finance Request", 5),
]
PRIORITY_WEIGHTS = [("Critical", 4), ("High", 18), ("Medium", 50), ("Low", 28)]

QUEUES = {
    ("Ontario", "ops"): "Ontario Field Dispatch",
    ("New York", "ops"): "US Field Dispatch (New York)",
    ("Ohio", "ops"): "US Field Dispatch (Ohio)",
    "Safety": "Safety and Environment",
    "IT Service Desk": "IT Service Desk",
    "Facilities": "Facilities Management",
    "HR Case": "HR Case Management",
    "Finance Request": "Finance Operations",
}

FIRST = ["alex", "jordan", "sam", "taylor", "morgan", "casey", "riley", "jamie", "devon", "quinn", "avery",
         "rowan", "harper", "emerson", "kai", "reese", "logan", "skyler", "parker", "drew"]
LAST = ["okafor", "lindgren", "chowdhury", "beaulieu", "marchetti", "hwang", "delgado", "fitzgerald",
        "abernathy", "nakashima", "osei", "vandermeer", "kaur", "santoro", "whitlock", "zielinski", "moreau",
        "achebe", "halvorsen", "costa"]

TEMPLATES = {
    "Field Operations": [
        ("Crew callout: {atype_l} {asset} at {site}",
         "Dispatch requested for {asset} ({atype_l}, {rating}) at {site}. Field report: {symptom}. Crew to "
         "confirm isolation with system control and complete lockout/tagout before starting."),
        ("Switching order support for {asset}",
         "System control requests field support for planned switching at {site} involving {asset}. Switching "
         "window {window}. Confirm crew availability and hold-off tags."),
        ("Locate request near {asset}",
         "Contractor excavation planned within 3 m of underground plant fed from {asset} at {site}. Mark "
         "cables and attend during excavation."),
    ],
    "Outage": [
        ("Outage: {n} customers off near {site}",
         "{n} customers reported out in {city}. Suspected cause: {cause}. First responder assigned; "
         "estimated restoration time to be confirmed after patrol. Affected device: {asset}."),
        ("Momentary outages reported, {asset}",
         "Customers fed from {asset} at {site} report repeated momentary outages over the last 48 hours. "
         "Review event log and patrol the line section."),
    ],
    "Asset Maintenance": [
        ("Inspection finding on {asset}: {finding}",
         "During routine inspection at {site}, the inspector recorded: {finding}. Asset {asset} ({atype_l}, "
         "installed {year}). Create a work order if repair is required within 30 days."),
        ("Planned maintenance: {asset}",
         "Planned maintenance for {asset} at {site}. Scope: {scope}. Coordinate outage window with system "
         "control and notify affected customers 48 hours ahead."),
    ],
    "Customer Complaint": [
        ("Customer complaint: {complaint} ({city})",
         "Customer in {city} reports {complaint}. Service is fed from {asset}. Call the customer back within "
         "2 business days and record the outcome."),
    ],
    "Safety": [
        ("Safety observation at {site}: {obs}",
         "Safety observation logged at {site}: {obs}. Supervisor to review with the crew at the next tailboard "
         "and confirm corrective action."),
        ("Near miss report, {site}",
         "Near miss at {site}: {nearmiss}. No injuries. Investigation lead assigned; findings due in 10 "
         "business days."),
    ],
    "IT Service Desk": [
        ("{it_issue}",
         "User at {site} reports: {it_issue_l}. Device asset tag {laptop}. Service desk to triage and update "
         "within 4 business hours."),
    ],
    "Facilities": [
        ("{fac_issue}, {site}",
         "Facilities request at {site}: {fac_issue_l}. Facilities team to schedule a visit and post a notice "
         "if access is affected."),
    ],
    "HR Case": [
        ("HR case: {hr_topic}",
         "Confidential HR case opened for an employee at {site}. Topic: {hr_topic_l}. Case handled by HR Case "
         "Management; do not share details outside HR."),
    ],
    "Finance Request": [
        ("Finance request: {fin_topic}",
         "Finance request from {site}: {fin_topic_l}. Reference {ref}. Finance Operations to review against "
         "the approval matrix and respond within 5 business days."),
    ],
}

SYMPTOMS = ["audible arcing at the connection", "oil staining at the base", "crossarm split near the insulator",
            "tree limb resting on the primary", "door on enclosure found unlocked", "hot spot seen on infrared",
            "failed to operate on SCADA command", "leaning after vehicle contact"]
CAUSES = ["tree contact", "vehicle contact", "animal contact", "equipment failure", "lightning",
          "high winds", "unknown, patrol in progress"]
FINDINGS = ["woodpecker damage at 6 m", "cracked insulator", "low oil level", "corroded ground connection",
            "missing danger sign", "rust on tank", "counter reading above threshold", "vegetation within 1 m"]
SCOPES = ["contact resistance test and lubrication", "oil sample and dissolved gas analysis",
          "replace control battery", "infrared scan and tighten connections", "replace crossarm and insulators"]
COMPLAINTS = ["flickering lights", "voltage too low in the evenings", "noise from the transformer",
              "damaged lawn after crew visit", "long outage without updates", "tree trimming concerns"]
OBSERVATIONS = ["ladder not tied off", "spotter not assigned during backing", "cones missing at work zone",
                "expired fire extinguisher in truck", "good practice: test-before-touch verified",
                "PPE arc rating label unreadable"]
NEARMISSES = ["bucket came within approach distance of the neutral", "unsecured load shifted on trailer",
              "worker stepped into open vault edge", "grounding set left on after work"]
IT_ISSUES = ["Laptop will not connect to VPN", "Outlook keeps asking for password", "Request for second monitor",
             "Field tablet screen cracked", "Cannot print to floor printer", "Teams audio drops on calls",
             "Password reset for mobile device", "Access request for GIS viewer"]
FAC_ISSUES = ["Heating not working in meeting room", "Parking lot light out", "Water leak in washroom",
              "Badge reader not working at side door", "Request for ergonomic chair", "Kitchen fridge not cooling"]
HR_TOPICS = ["Leave of absence request", "Accommodation request", "Workplace conflict concern",
             "Benefits enrolment correction", "Performance improvement plan follow-up", "Pay discrepancy query"]
FIN_TOPICS = ["Purchase order amendment", "Vendor invoice on hold", "Expense report exception",
              "Capital project budget transfer", "Corporate card limit increase", "Month-end accrual query"]
TAGS = {
    "Field Operations": ["dispatch", "switching", "locate", "night-work"],
    "Outage": ["storm", "mutual-aid", "restoration", "customer-impact"],
    "Asset Maintenance": ["inspection", "planned-outage", "infrared", "oil-sample"],
    "Customer Complaint": ["callback", "power-quality", "claims"],
    "Safety": ["near-miss", "ppe", "tailboard"],
    "IT Service Desk": ["vpn", "hardware", "access", "m365"],
    "Facilities": ["hvac", "security", "maintenance"],
    "HR Case": ["confidential"],
    "Finance Request": ["approval", "month-end", "vendor"],
}


def weighted(pairs):
    return rng.choices([p[0] for p in pairs], weights=[p[1] for p in pairs], k=1)[0]


def person():
    return f"{rng.choice(FIRST)}.{rng.choice(LAST)}@harbourline.example"


def load_assets():
    with open(ASSETS_CSV, encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    rows.sort(key=lambda r: r["AssetNumber"])
    return rows


def acl_for(category, region):
    if category in OPS_CATEGORIES:
        grp = "{{GROUP_OPS_ONTARIO}}" if region == "Ontario" else "{{GROUP_OPS_US}}"
        return [("group", grp, "grant")]
    if category in ("Safety", "IT Service Desk"):
        return [("everyoneExceptGuests", "{{TENANT_ID}}", "grant")]
    if category == "Facilities":
        return [("everyone", "{{TENANT_ID}}", "grant")]
    if category == "HR Case":
        return [("group", "{{GROUP_HR}}", "grant")]
    if category == "Finance Request":
        return [("group", "{{GROUP_FINANCE}}", "grant")]
    raise ValueError(category)


def status_for(created):
    age = (NOW - created).days
    if age > 45:
        return weighted([("Closed", 80), ("Resolved", 16), ("Pending", 3), ("In Progress", 1)])
    return weighted([("New", 15), ("Assigned", 20), ("In Progress", 25), ("Pending", 12), ("Resolved", 18),
                     ("Closed", 10)])


def build():
    assets = load_assets()
    # random tickets never use the planted Dataverse assets, so only the planted tickets mention them
    from build_dataverse import PLANTED_ASSETS
    assets_by_region = {}
    for a in assets:
        if a["AssetNumber"] not in PLANTED_ASSETS:
            assets_by_region.setdefault(a["Region"], []).append(a)
    asset_id = {a["AssetNumber"]: i + 1 for i, a in enumerate(assets)}
    asset_by_tag = {a["AssetNumber"]: a for a in assets}

    span = int((NOW - START).total_seconds())
    created = sorted(START + timedelta(seconds=rng.randint(0, span)) for _ in range(TICKET_COUNT))
    tickets = []
    for i, c in enumerate(created):
        tid = FIRST_ID + i
        category = weighted(CATEGORY_WEIGHTS)
        if category in OPS_CATEGORIES:
            region = weighted([("Ontario", 50), ("New York", 28), ("Ohio", 22)])
            a = rng.choice(assets_by_region[region])
            site_code = a["SiteCode"]
        else:
            region = weighted([("Ontario", 60), ("New York", 22), ("Ohio", 18)])
            a = None
            site_code = OFFICE[region] if rng.random() < 0.7 else rng.choice(
                [s[0] for s in SITES if s[3] == region and s[4] != "Office"])
        site = SITE_BY_CODE[site_code]
        title_t, desc_t = rng.choice(TEMPLATES[category])
        it = rng.choice(IT_ISSUES)
        fac = rng.choice(FAC_ISSUES)
        hr = rng.choice(HR_TOPICS)
        fin = rng.choice(FIN_TOPICS)
        start_h = rng.choice([6, 8, 22])
        ctx = {
            "asset": a["AssetNumber"] if a else "",
            "atype_l": a["AssetType"].lower() if a else "",
            "rating": a["Rating"] if a else "",
            "year": a["InstallYear"] if a else "",
            "site": site[1], "city": site[2],
            "symptom": rng.choice(SYMPTOMS), "cause": rng.choice(CAUSES), "finding": rng.choice(FINDINGS),
            "scope": rng.choice(SCOPES), "complaint": rng.choice(COMPLAINTS), "obs": rng.choice(OBSERVATIONS),
            "nearmiss": rng.choice(NEARMISSES), "n": rng.choice([12, 38, 85, 140, 260, 610, 1150]),
            "window": f"{start_h:02d}:00 to {(start_h + 4) % 24:02d}:00",
            "it_issue": it, "it_issue_l": it[0].lower() + it[1:],
            "fac_issue": fac, "fac_issue_l": fac[0].lower() + fac[1:],
            "hr_topic": hr, "hr_topic_l": hr[0].lower() + hr[1:],
            "fin_topic": fin, "fin_topic_l": fin[0].lower() + fin[1:],
            "laptop": f"HL-LT-{rng.randint(1000, 9999)}", "ref": f"FIN-{c.year}-{rng.randint(1000, 9999)}",
        }
        title = title_t.format(**ctx)
        desc = desc_t.format(**ctx)
        if category == "HR Case":
            title = f"{title} (case HR-{c.year}-{rng.randint(100, 999):04d})"
        status = status_for(c)
        last_mod = min(NOW, c + timedelta(hours=rng.randint(1, 24 * (30 if status in ("Closed", "Resolved") else 10))))
        if category in OPS_CATEGORIES:
            queue = QUEUES[(region, "ops")]
        else:
            queue = QUEUES[category]
        tags = sorted(rng.sample(TAGS[category], k=rng.randint(0, min(2, len(TAGS[category])))))
        tickets.append({
            "TicketId": tid,
            "Title": title,
            "Description": desc,
            "Status": status,
            "Priority": weighted(PRIORITY_WEIGHTS) if category != "Outage" else weighted(
                [("Critical", 25), ("High", 55), ("Medium", 20)]),
            "Category": category,
            "Region": region,
            "SiteCode": site_code,
            "AssetTag": a["AssetNumber"] if a else "",
            "CreatedBy": person(),
            "AssignedTo": queue,
            "Tags": tags,
            "CreatedDateTime": c,
            "LastModified": last_mod,
            "Acl": acl_for(category, region),
            "_planted": None,
        })

    by_id = {t["TicketId"]: t for t in tickets}

    def plant(tid, tag, **kw):
        t = by_id[tid]
        t.update(kw)
        t["_planted"] = tag
        if "Acl" not in kw:
            t["Acl"] = acl_for(t["Category"], t["Region"])
        return t

    dt = datetime.fromisoformat
    plant(100420, "P-TK-01 Ontario-only",
          Title="Stain on pole P-30912 below transformer TX-ON-10423, Bath Road, Kingston",
          Description="Customer on Bath Road near Collins Bay Road, Kingston, reported a dark stain on pole P-30912 "
                      "below transformer TX-ON-10423 (25 kVA pole-mount). Infrared scan booked as work order "
                      "WO-2026-00953 with crew CREW-ON-03. Scan on 2026-09-02 found normal connections and a light "
                      "oil film at the tank lid gasket. Monitor at next patrol. Customer called back 2026-09-02.",
          Status="Resolved", Priority="Medium", Category="Asset Maintenance", Region="Ontario",
          SiteCode="KNGSC", AssetTag="TX-ON-10423", AssignedTo="Ontario Field Dispatch",
          CreatedBy="alex.okafor@harbourline.example", Tags=["infrared", "oil-sample"],
          CreatedDateTime=dt("2026-08-27T09:12:00"), LastModified=dt("2026-09-02T16:20:00"))
    plant(101776, "P-TK-02 US-only",
          Title="Trip counter above limit on BRK-NY-24480, Mohawk Valley Substation",
          Description="Operations counter on 69 kV breaker BRK-NY-24480 reached 2,140 operations, above the "
                      "2,000 operation maintenance limit. Mechanism service deferred to the January 2027 "
                      "outage window (2027-01-12 to 2027-01-15). US Field Dispatch (New York) to monitor weekly.",
          Status="Pending", Priority="High", Category="Asset Maintenance", Region="New York",
          SiteCode="MOHSS", AssetTag="BRK-NY-24480", AssignedTo="US Field Dispatch (New York)",
          CreatedBy="jordan.lindgren@harbourline.example", Tags=["inspection", "planned-outage"],
          CreatedDateTime=dt("2026-06-01T10:15:00"), LastModified=dt("2026-09-12T09:30:00"))
    plant(102050, "P-TK-03 HR-only",
          Title="HR case: Return-to-work plan and accommodation (case HR-2026-0381)",
          Description="Confidential. Return-to-work plan for a field employee after a shoulder injury. Modified "
                      "duties approved for 6 weeks starting 2026-10-05: no climbing, lifting limit 10 kg. "
                      "Case owner: Priya Nandakumar, HR Manager. Next review 2026-11-16.",
          Status="In Progress", Priority="High", Category="HR Case", Region="Ontario", SiteCode="TORHO",
          AssetTag="", AssignedTo="HR Case Management", CreatedBy="priya.nandakumar@harbourline.example",
          Tags=["confidential"], CreatedDateTime=dt("2026-09-14T13:20:00"), LastModified=dt("2026-09-28T11:05:00"))
    plant(102600, "P-TK-04 everyone",
          Title="Parking garage level P2 closed for resurfacing, Toronto Head Office",
          Description="Level P2 of the Toronto Head Office parking garage is closed from 2026-10-13 to "
                      "2026-10-24 for resurfacing. Visitors and contractors should use the surface lot on "
                      "Harbour Street. Accessible spaces move to level P1.",
          Status="Assigned", Priority="Low", Category="Facilities", Region="Ontario", SiteCode="TORHO",
          AssetTag="", AssignedTo="Facilities Management", CreatedBy="casey.moreau@harbourline.example",
          Tags=["maintenance"], CreatedDateTime=dt("2026-09-22T08:00:00"), LastModified=dt("2026-09-25T16:45:00"))
    plant(103115, "P-TK-05 everyoneExceptGuests",
          Title="Company-wide VPN client upgrade to version 6.2 on 2026-10-06",
          Description="All Harbourline laptops will receive VPN client version 6.2 on 2026-10-06 starting at "
                      "18:00 Eastern. Restart when prompted. Field tablets are upgraded on 2026-10-08. Contact "
                      "the IT Service Desk at extension 4357 with issues.",
          Status="Assigned", Priority="Medium", Category="IT Service Desk", Region="Ontario", SiteCode="TORHO",
          AssetTag="", AssignedTo="IT Service Desk", CreatedBy="riley.hwang@harbourline.example",
          Tags=["m365", "vpn"], CreatedDateTime=dt("2026-09-23T09:30:00"), LastModified=dt("2026-09-29T10:00:00"))
    plant(104321, "P-TK-06 deny",
          Title="Safety investigation SI-2026-014: contact with energized conductor, Oshawa Service Centre",
          Description="Investigation into a contact event on 2026-09-08 in the Oshawa Service Centre area. "
                      "Worker received a minor burn; hospital check completed, returned to work 2026-09-10. "
                      "Root cause review in progress; interim control: second-person verification of "
                      "test-before-touch. Visible to all staff except the Ontario operations group while "
                      "witness interviews are open.",
          Status="In Progress", Priority="High", Category="Safety", Region="Ontario", SiteCode="OSHSC",
          AssetTag="", AssignedTo="Safety and Environment", CreatedBy="morgan.abernathy@harbourline.example",
          Tags=["near-miss"], CreatedDateTime=dt("2026-09-09T07:55:00"), LastModified=dt("2026-09-26T14:20:00"),
          Acl=[("everyoneExceptGuests", "{{TENANT_ID}}", "grant"), ("group", "{{GROUP_OPS_ONTARIO}}", "deny")])
    plant(104700, "P-TK-07 user-only",
          Title="Corporate card dispute: duplicate hotel charge, Sofia Brennan",
          Description="Duplicate charge of CAD 412.60 from a hotel in Ottawa on 2026-09-03 on the corporate card "
                      "of Sofia Brennan (Finance). Dispute filed with the card issuer on 2026-09-16, reference "
                      "CD-88213. Visible only to the cardholder.",
          Status="Pending", Priority="Low", Category="Finance Request", Region="Ontario", SiteCode="TORHO",
          AssetTag="", AssignedTo="Finance Operations", CreatedBy="sofia.brennan@harbourline.example",
          Tags=["vendor"], CreatedDateTime=dt("2026-09-16T12:10:00"), LastModified=dt("2026-09-24T09:40:00"),
          Acl=[("user", "{{USER_FIN}}", "grant")])
    plant(103900, "P-TK-08 Finance-only",
          Title="Finance request: Q3 capital accrual correction, project CP-2026-117",
          Description="Q3 accrual for capital project CP-2026-117 (Maumee Bay Substation transformer replacement, "
                      "TX-OH-31902) was booked at USD 185,000 instead of USD 1,850,000. Correcting journal "
                      "JE-2026-09-4471 to be posted before the 2026-10-07 close.",
          Status="In Progress", Priority="High", Category="Finance Request", Region="Ohio", SiteCode="COLRO",
          AssetTag="", AssignedTo="Finance Operations", CreatedBy="sofia.brennan@harbourline.example",
          Tags=["month-end"], CreatedDateTime=dt("2026-09-29T08:25:00"), LastModified=dt("2026-09-30T09:15:00"))
    plant(101999, "P-TK-09 Ontario+US ops",
          Title="Cross-border mutual assistance roster, winter storm season 2026-2027",
          Description="Roster of crews available for cross-border mutual assistance between Ontario and the US "
                      "operations from 2026-11-15 to 2027-03-31. Ontario storm crews CREW-ON-11, CREW-ON-14 and "
                      "CREW-ON-20; US storm crews CREW-NY-07, CREW-NY-13, CREW-OH-07, CREW-OH-12 and CREW-OH-18. "
                      "Border crossing "
                      "paperwork owner: US Field Dispatch (New York).",
          Status="Assigned", Priority="Medium", Category="Field Operations", Region="New York", SiteCode="ALBRO",
          AssetTag="", AssignedTo="US Field Dispatch (New York)", CreatedBy="quinn.delgado@harbourline.example",
          Tags=["mutual-aid", "storm"], CreatedDateTime=dt("2026-09-18T15:00:00"),
          LastModified=dt("2026-09-27T12:00:00"),
          Acl=[("group", "{{GROUP_OPS_ONTARIO}}", "grant"), ("group", "{{GROUP_OPS_US}}", "grant")])
    plant(104862, "P-TK-10 US-only",
          Title="Repeat failure: SW-OH-30110 stuck open during restoration",
          Description="SW-OH-30110 at Lima Depot stuck open during feeder restoration on 2026-09-18. This is the "
                      "ninth failure since November 2024. Engineering asks for a replacement business case. "
                      "Linked work order WO-2026-01043, storm crew CREW-OH-07.",
          Status="New", Priority="Critical", Category="Outage", Region="Ohio", SiteCode="LIMDP",
          AssetTag="SW-OH-30110", AssignedTo="US Field Dispatch (Ohio)", CreatedBy="avery.osei@harbourline.example",
          Tags=["restoration"], CreatedDateTime=dt("2026-09-18T21:35:00"), LastModified=dt("2026-09-30T08:05:00"))

    plant(102777, "P-TK-11 US-only",
          Title="Bushing tracking noted on TX-OH-20871, Lake Avenue, Ashtabula",
          Description="Routine inspection of TX-OH-20871 (50 kVA pole-mount, pole P-51260, Lake Avenue at West 5th "
                      "Street, Ashtabula) found minor surface tracking on the primary bushing. Wildlife guard "
                      "present. Cleaning deferred to the next planned outage. Work order WO-2025-01181, crew "
                      "CREW-OH-06.",
          Status="Closed", Priority="Low", Category="Asset Maintenance", Region="Ohio", SiteCode="ASHDP",
          AssetTag="TX-OH-20871", AssignedTo="US Field Dispatch (Ohio)", CreatedBy="drew.halvorsen@harbourline.example",
          Tags=["inspection"], CreatedDateTime=dt("2025-10-09T08:30:00"), LastModified=dt("2025-10-14T15:45:00"))

    # enrich
    for t in tickets:
        site = SITE_BY_CODE[t["SiteCode"]]
        t["SiteName"] = site[1]
        t["RegionCode"] = REGION_CODE[t["Region"]]
        t["AssetType"] = asset_by_tag[t["AssetTag"]]["AssetType"] if t["AssetTag"] else ""
        t["Url"] = f"{BASE_URL}/t/{t['TicketId']}"
        slug = t["Category"].lower().replace(" ", "-")
        t["IconUrl"] = f"{BASE_URL}/static/icons/{slug}.png"
    return tickets, assets, asset_id


def sql_str(v):
    if v is None or v == "":
        return "NULL"
    return "N'" + str(v).replace("'", "''") + "'"


def sql_dt(d):
    return "'" + d.strftime("%Y-%m-%dT%H:%M:%S") + "'"


def acl_json(acl):
    return json.dumps([{"type": ty, "value": va, "accessType": ac} for ty, va, ac in acl], separators=(",", ":"))


def write_sql(tickets, assets, asset_id, path):
    L = []
    w = L.append
    w("/*")
    w("  tickets-seed.sql: Harbourline Energy Co. service ticket database for Lab 7 (Copilot connector).")
    w("  Generated by tools/generate-data/build_tickets.py. Do not edit by hand; re-run the generator.")
    w("")
    w("  Target: SQL Server 2016 SP1 or later (uses CREATE OR ALTER and FOR JSON), including SQL Server")
    w("  Express and LocalDB. For Azure SQL Database, create the database HarbourlineTickets in the portal,")
    w("  connect to it, and run this script from the line 'Section 2' onward (USE is not supported there).")
    w("")
    w("  Idempotent: the database and tables are created only if missing, the view is CREATE OR ALTER, and")
    w("  the data section deletes all rows (child tables first) before re-inserting the same fixed keys.")
    w("")
    w("  ACL PrincipalId values are placeholder tokens substituted by data/connector/ingest-tickets.ps1:")
    w("    {{GROUP_OPS_ONTARIO}} {{GROUP_OPS_US}} {{GROUP_HR}} {{GROUP_FINANCE}} {{USER_FIN}} {{TENANT_ID}}")
    w("*/")
    w("SET NOCOUNT ON;")
    w("GO")
    w("-- Section 1: database")
    w("IF DB_ID(N'HarbourlineTickets') IS NULL")
    w("    CREATE DATABASE HarbourlineTickets;")
    w("GO")
    w("USE HarbourlineTickets;")
    w("GO")
    w("-- Section 2: tables (created only if missing)")
    w("""IF OBJECT_ID(N'dbo.Region', N'U') IS NULL
CREATE TABLE dbo.Region (
    RegionId    INT           NOT NULL CONSTRAINT PK_Region PRIMARY KEY,
    RegionCode  NVARCHAR(4)   NOT NULL CONSTRAINT UQ_Region_Code UNIQUE,
    RegionName  NVARCHAR(50)  NOT NULL,
    Country     NVARCHAR(50)  NOT NULL
);
GO
IF OBJECT_ID(N'dbo.Site', N'U') IS NULL
CREATE TABLE dbo.Site (
    SiteId      INT           NOT NULL CONSTRAINT PK_Site PRIMARY KEY,
    RegionId    INT           NOT NULL CONSTRAINT FK_Site_Region REFERENCES dbo.Region (RegionId),
    SiteCode    NVARCHAR(10)  NOT NULL CONSTRAINT UQ_Site_Code UNIQUE,
    SiteName    NVARCHAR(100) NOT NULL,
    City        NVARCHAR(60)  NOT NULL,
    SiteType    NVARCHAR(30)  NOT NULL
);
GO
IF OBJECT_ID(N'dbo.Asset', N'U') IS NULL
CREATE TABLE dbo.Asset (
    AssetId     INT           NOT NULL CONSTRAINT PK_Asset PRIMARY KEY,
    SiteId      INT           NOT NULL CONSTRAINT FK_Asset_Site REFERENCES dbo.Site (SiteId),
    AssetTag    NVARCHAR(20)  NOT NULL CONSTRAINT UQ_Asset_Tag UNIQUE,
    AssetType   NVARCHAR(40)  NOT NULL,
    Rating      NVARCHAR(60)  NULL,
    InstallYear INT           NULL
);
GO
IF OBJECT_ID(N'dbo.Ticket', N'U') IS NULL
CREATE TABLE dbo.Ticket (
    TicketId        INT            NOT NULL CONSTRAINT PK_Ticket PRIMARY KEY,
    SiteId          INT            NOT NULL CONSTRAINT FK_Ticket_Site REFERENCES dbo.Site (SiteId),
    AssetId         INT            NULL     CONSTRAINT FK_Ticket_Asset REFERENCES dbo.Asset (AssetId),
    Title           NVARCHAR(200)  NOT NULL,
    Description     NVARCHAR(MAX)  NOT NULL,
    Status          NVARCHAR(20)   NOT NULL,
    Priority        NVARCHAR(20)   NOT NULL,
    Category        NVARCHAR(40)   NOT NULL,
    CreatedBy       NVARCHAR(120)  NOT NULL,
    AssignedTo      NVARCHAR(120)  NULL,
    Tags            NVARCHAR(200)  NULL,
    CreatedDateTime DATETIME2(0)   NOT NULL,
    LastModified    DATETIME2(0)   NOT NULL,
    Url             NVARCHAR(200)  NOT NULL,
    IconUrl         NVARCHAR(200)  NOT NULL
);
GO
IF OBJECT_ID(N'dbo.TicketAcl', N'U') IS NULL
CREATE TABLE dbo.TicketAcl (
    TicketAclId   INT           NOT NULL CONSTRAINT PK_TicketAcl PRIMARY KEY,
    TicketId      INT           NOT NULL CONSTRAINT FK_TicketAcl_Ticket REFERENCES dbo.Ticket (TicketId),
    PrincipalType NVARCHAR(30)  NOT NULL CONSTRAINT CK_TicketAcl_Type
                  CHECK (PrincipalType IN (N'user', N'group', N'everyone', N'everyoneExceptGuests')),
    PrincipalId   NVARCHAR(100) NOT NULL,
    AccessType    NVARCHAR(10)  NOT NULL CONSTRAINT CK_TicketAcl_Access CHECK (AccessType IN (N'grant', N'deny'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Ticket_LastModified')
    CREATE INDEX IX_Ticket_LastModified ON dbo.Ticket (LastModified);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_TicketAcl_TicketId')
    CREATE INDEX IX_TicketAcl_TicketId ON dbo.TicketAcl (TicketId);
GO""")
    w("-- Section 3: view used by ingest-tickets.ps1 -SqlConnectionString (same columns as tickets.csv)")
    w("""CREATE OR ALTER VIEW dbo.vTicketIndex
AS
SELECT
    t.TicketId,
    t.Title,
    t.Description,
    t.Status,
    t.Priority,
    t.Category,
    r.RegionCode,
    r.RegionName AS Region,
    s.SiteCode,
    s.SiteName,
    a.AssetTag,
    a.AssetType,
    t.CreatedBy,
    t.AssignedTo,
    t.Tags,
    CONVERT(NVARCHAR(30), t.CreatedDateTime, 126) + N'Z' AS CreatedDateTime,
    CONVERT(NVARCHAR(30), t.LastModified, 126) + N'Z'    AS LastModified,
    t.Url,
    t.IconUrl,
    (SELECT acl.PrincipalType AS [type], acl.PrincipalId AS [value], acl.AccessType AS [accessType]
       FROM dbo.TicketAcl AS acl
      WHERE acl.TicketId = t.TicketId
      ORDER BY acl.TicketAclId
      FOR JSON PATH) AS AclJson
FROM dbo.Ticket AS t
JOIN dbo.Site   AS s ON s.SiteId = t.SiteId
JOIN dbo.Region AS r ON r.RegionId = s.RegionId
LEFT JOIN dbo.Asset AS a ON a.AssetId = t.AssetId;
GO""")
    w("-- Section 4: data (delete then re-insert fixed keys, so re-running gives the same result)")
    w("DELETE FROM dbo.TicketAcl;")
    w("DELETE FROM dbo.Ticket;")
    w("DELETE FROM dbo.Asset;")
    w("DELETE FROM dbo.Site;")
    w("DELETE FROM dbo.Region;")
    w("GO")
    w("INSERT INTO dbo.Region (RegionId, RegionCode, RegionName, Country) VALUES")
    w(",\n".join(f"    ({r[0]}, {sql_str(r[1])}, {sql_str(r[2])}, {sql_str(r[3])})" for r in REGIONS) + ";")
    w("GO")
    w("INSERT INTO dbo.Site (SiteId, RegionId, SiteCode, SiteName, City, SiteType) VALUES")
    w(",\n".join(f"    ({SITE_ID[s[0]]}, {REGION_ID[s[3]]}, {sql_str(s[0])}, {sql_str(s[1])}, {sql_str(s[2])}, "
                 f"{sql_str(s[4])})" for s in SITES) + ";")
    w("GO")

    def batches(rows, n=500):
        for i in range(0, len(rows), n):
            yield rows[i:i + n]

    for chunk in batches(assets):
        w("INSERT INTO dbo.Asset (AssetId, SiteId, AssetTag, AssetType, Rating, InstallYear) VALUES")
        w(",\n".join(f"    ({asset_id[a['AssetNumber']]}, {SITE_ID[a['SiteCode']]}, {sql_str(a['AssetNumber'])}, "
                     f"{sql_str(a['AssetType'])}, {sql_str(a['Rating'])}, {a['InstallYear']})" for a in chunk) + ";")
        w("GO")
    for chunk in batches(tickets):
        w("INSERT INTO dbo.Ticket (TicketId, SiteId, AssetId, Title, Description, Status, Priority, Category, "
          "CreatedBy, AssignedTo, Tags, CreatedDateTime, LastModified, Url, IconUrl) VALUES")
        rows = []
        for t in chunk:
            aid = asset_id[t["AssetTag"]] if t["AssetTag"] else "NULL"
            rows.append(f"    ({t['TicketId']}, {SITE_ID[t['SiteCode']]}, {aid}, {sql_str(t['Title'])}, "
                        f"{sql_str(t['Description'])}, {sql_str(t['Status'])}, {sql_str(t['Priority'])}, "
                        f"{sql_str(t['Category'])}, {sql_str(t['CreatedBy'])}, {sql_str(t['AssignedTo'])}, "
                        f"{sql_str(';'.join(t['Tags']))}, {sql_dt(t['CreatedDateTime'])}, "
                        f"{sql_dt(t['LastModified'])}, {sql_str(t['Url'])}, {sql_str(t['IconUrl'])})")
        w(",\n".join(rows) + ";")
        w("GO")
    acl_rows = []
    n = 0
    for t in tickets:
        for ty, va, ac in t["Acl"]:
            n += 1
            acl_rows.append(f"    ({n}, {t['TicketId']}, {sql_str(ty)}, {sql_str(va)}, {sql_str(ac)})")
    for chunk in batches(acl_rows):
        w("INSERT INTO dbo.TicketAcl (TicketAclId, TicketId, PrincipalType, PrincipalId, AccessType) VALUES")
        w(",\n".join(chunk) + ";")
        w("GO")
    w("-- Section 5: quick check")
    w("SELECT (SELECT COUNT(*) FROM dbo.Region) AS Regions, (SELECT COUNT(*) FROM dbo.Site) AS Sites,")
    w("       (SELECT COUNT(*) FROM dbo.Asset) AS Assets, (SELECT COUNT(*) FROM dbo.Ticket) AS Tickets,")
    w("       (SELECT COUNT(*) FROM dbo.TicketAcl) AS AclEntries;")
    w("GO")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(L) + "\n")
    return n


def write_csv(tickets, path):
    fields = ["TicketId", "Title", "Description", "Status", "Priority", "Category", "RegionCode", "Region",
              "SiteCode", "SiteName", "AssetTag", "AssetType", "CreatedBy", "AssignedTo", "Tags",
              "CreatedDateTime", "LastModified", "Url", "IconUrl", "AclJson"]
    with open(path, "w", encoding="utf-8", newline="") as f:
        wr = csv.DictWriter(f, fieldnames=fields, lineterminator="\n")
        wr.writeheader()
        for t in tickets:
            row = {k: t.get(k, "") for k in fields}
            row["Tags"] = ";".join(t["Tags"])
            row["CreatedDateTime"] = t["CreatedDateTime"].strftime("%Y-%m-%dT%H:%M:%SZ")
            row["LastModified"] = t["LastModified"].strftime("%Y-%m-%dT%H:%M:%SZ")
            row["AclJson"] = acl_json(t["Acl"])
            wr.writerow(row)


def main():
    os.makedirs(OUT, exist_ok=True)
    tickets, assets, asset_id = build()
    acl_count = write_sql(tickets, assets, asset_id, os.path.join(OUT, "tickets-seed.sql"))
    write_csv(tickets, os.path.join(OUT, "tickets.csv"))

    def pattern(t):
        return " + ".join(f"{ac}:{ty}:{va}" for ty, va, ac in t["Acl"])

    facts = {
        "ticket_count": len(tickets),
        "acl_entries": acl_count,
        "asset_rows": len(assets),
        "site_rows": len(SITES),
        "id_range": [tickets[0]["TicketId"], tickets[-1]["TicketId"]],
        "by_category": Counter(t["Category"] for t in tickets),
        "by_region": Counter(t["Region"] for t in tickets),
        "by_status": Counter(t["Status"] for t in tickets),
        "by_priority": Counter(t["Priority"] for t in tickets),
        "by_acl_pattern": Counter(pattern(t) for t in tickets),
        "open_critical": sorted(t["TicketId"] for t in tickets if t["Priority"] == "Critical"
                                and t["Status"] in ("New", "Assigned", "In Progress", "Pending")),
        "tickets_for_TX-ON-10423": [t["TicketId"] for t in tickets if t["AssetTag"] == "TX-ON-10423"],
        "tickets_for_SW-OH-30110": [t["TicketId"] for t in tickets if t["AssetTag"] == "SW-OH-30110"],
        "tickets_for_BRK-NY-24480": [t["TicketId"] for t in tickets if t["AssetTag"] == "BRK-NY-24480"],
        "tickets_for_TX-OH-20871": [t["TicketId"] for t in tickets if t["AssetTag"] == "TX-OH-20871"],
        "tickets_by_site": Counter(t["SiteName"] for t in tickets),
        "open_by_region": Counter(t["Region"] for t in tickets if t["Status"] in ("New", "Assigned", "In Progress", "Pending")),
        "planted": [{"TicketId": t["TicketId"], "tag": t["_planted"], "Title": t["Title"], "Status": t["Status"],
                     "Priority": t["Priority"], "Category": t["Category"], "Region": t["Region"],
                     "Site": t["SiteName"], "LastModified": t["LastModified"].isoformat(),
                     "Acl": acl_json(t["Acl"])} for t in tickets if t["_planted"]],
        "max_title_len": max(len(t["Title"]) for t in tickets),
    }
    with open(os.path.join(OUT, "_facts.json"), "w", encoding="utf-8") as f:
        json.dump(facts, f, indent=2, default=str)
    print(json.dumps({k: facts[k] for k in ["ticket_count", "acl_entries", "by_category", "by_acl_pattern",
                                            "max_title_len"]}, indent=1, default=str))


if __name__ == "__main__":
    main()
