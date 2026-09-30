#!/usr/bin/env python3
"""Generate the Harbourline Energy Co. Dataverse seed data.

Outputs (deterministic, fixed seed):
  data/dataverse/Assets.csv      1,200 rows
  data/dataverse/Crews.csv          60 rows
  data/dataverse/WorkOrders.csv  3,000 rows
  data/dataverse/_facts.json     computed aggregates used to write the answer key

Re-run any time: python3 tools/generate-data/build_dataverse.py
The planted rows (tags P-DV-xx, see data/answer-keys/dataverse-connector.md) are fixed.

Consistency with other course data:
  * Crews CREW-ON-01..08, CREW-NY-01..05, CREW-OH-01..05 match data/api/src/data/crews.json exactly
    (crewId, crewLead, crewSize, baseDepot, specialty).
  * TX-ON-10423 (Kingston ON) and TX-OH-20871 (Ashtabula OH) match the Lab 9 field reports in
    data/sharepoint/lab-09-drops/.
"""
import csv
import json
import os
import random
from collections import Counter, defaultdict
from datetime import date, timedelta

SEED = 20260930
TODAY = date(2026, 9, 30)
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "data", "dataverse")

rng = random.Random(SEED)

REGIONS = {
    "ON": ("Ontario", "CAD"),
    "NY": ("New York", "USD"),
    "OH": ("Ohio", "USD"),
}

# Sites per region (code, name, city, kind). Depots match data/api crews.json baseDepot values.
# build_tickets.py reads site codes and names from Assets.csv, so keep them in sync through this file.
SITES = {
    "ON": [
        ("KNGSC", "Kingston Service Centre", "Kingston", "depot"),
        ("BELDP", "Belleville Depot", "Belleville", "depot"),
        ("PTBDP", "Peterborough Depot", "Peterborough", "depot"),
        ("OSHSC", "Oshawa Service Centre", "Oshawa", "depot"),
        ("BARDP", "Barrie Depot", "Barrie", "depot"),
        ("BRKDP", "Brockville Depot", "Brockville", "depot"),
        ("CATTS", "Cataraqui Transformer Station", "Kingston", "station"),
    ],
    "NY": [
        ("SYROC", "Syracuse Operations Center", "Syracuse", "depot"),
        ("ROCDP", "Rochester Depot", "Rochester", "depot"),
        ("UTIDP", "Utica Depot", "Utica", "depot"),
        ("WTNDP", "Watertown Depot", "Watertown", "depot"),
        ("MOHSS", "Mohawk Valley Substation", "Utica", "station"),
    ],
    "OH": [
        ("TOLOC", "Toledo Operations Center", "Toledo", "depot"),
        ("LIMDP", "Lima Depot", "Lima", "depot"),
        ("MANDP", "Mansfield Depot", "Mansfield", "depot"),
        ("FNDDP", "Findlay Depot", "Findlay", "depot"),
        ("ASHDP", "Ashtabula Depot", "Ashtabula", "depot"),
        ("MAUSS", "Maumee Bay Substation", "Toledo", "station"),
    ],
}
SITE_BY_CODE = {s[0]: s for reg in SITES.values() for s in reg}

ASSET_TYPES = [
    # prefix, choice label, weight
    ("POLE", "Pole", 40),
    ("TX", "Transformer", 25),
    ("SW", "Switch", 12),
    ("BRK", "Breaker", 8),
    ("RCL", "Recloser", 8),
    ("REG", "Voltage Regulator", 7),
]
TYPE_LABEL = {p: l for p, l, _ in ASSET_TYPES}

MANUFACTURERS = {
    "POLE": ["Timberline Utility Poles", "Great Lakes Pole Co.", "Corvane Composite Structures"],
    "TX": ["Ashby and Moore Electric", "Northfield Transformer Co.", "Lakeport Transformer Works"],
    "SW": ["Lakeport Switchgear", "Corvane Industries", "Ridgeline Power Systems"],
    "BRK": ["Ridgeline Power Systems", "Ashby and Moore Electric", "Lakeport Switchgear"],
    "RCL": ["Corvane Industries", "Northfield Transformer Co."],
    "REG": ["Ashby and Moore Electric", "Lakeport Transformer Works"],
}

RATINGS = {
    "POLE": ["35 ft Class 4 wood", "40 ft Class 3 wood", "45 ft Class 2 wood", "50 ft Class 1 wood", "45 ft composite"],
    "TX": ["25 kVA pole-mount", "50 kVA pole-mount", "75 kVA pole-mount", "167 kVA pole-mount",
           "300 kVA pad-mount", "500 kVA pad-mount", "1,000 kVA pad-mount", "10 MVA station", "20 MVA station"],
    "SW": ["15 kV 600 A gang-operated", "27.6 kV 900 A load-break", "15 kV 200 A inline", "27.6 kV 600 A motorized"],
    "BRK": ["15 kV 1,200 A vacuum", "27.6 kV 2,000 A vacuum", "44 kV 1,200 A SF6", "69 kV 2,000 A SF6"],
    "RCL": ["15 kV 560 A three-phase", "27.6 kV 800 A three-phase", "15 kV 100 A single-phase"],
    "REG": ["13.8 kV 328 A single-phase", "27.6 kV 219 A single-phase", "7.2 kV 438 A step"],
}

STATUS_ASSET = [("In Service", 93), ("Out of Service", 4), ("Retired", 3)]

# Crews that must match data/api/src/data/crews.json exactly: code, lead, size, depot, specialty
API_CREWS = [
    ("CREW-ON-01", "Marcus Bellamy", 5, "Kingston Service Centre", "Overhead lines"),
    ("CREW-ON-02", "Janelle Fortier", 6, "Kingston Service Centre", "Underground cable"),
    ("CREW-ON-03", "Devon Achebe", 5, "Kingston Service Centre", "Overhead lines"),
    ("CREW-ON-04", "Shauna Leclerc", 6, "Belleville Depot", "Vegetation management"),
    ("CREW-ON-05", "Pieter Van Dyk", 3, "Peterborough Depot", "Overhead lines"),
    ("CREW-ON-06", "Rena Kaplan", 6, "Oshawa Service Centre", "Overhead lines"),
    ("CREW-ON-07", "Graham Oduya", 6, "Barrie Depot", "Underground cable"),
    ("CREW-ON-08", "Colette Aubin", 3, "Brockville Depot", "Substation"),
    ("CREW-NY-01", "Tyrone Castellano", 4, "Syracuse Operations Center", "Overhead lines"),
    ("CREW-NY-02", "Megan Iverson", 6, "Syracuse Operations Center", "Underground cable"),
    ("CREW-NY-03", "Sal Okonkwo", 5, "Rochester Depot", "Substation"),
    ("CREW-NY-04", "Brianna Holt", 4, "Rochester Depot", "Underground cable"),
    ("CREW-NY-05", "Wes Kaminski", 6, "Utica Depot", "Overhead lines"),
    ("CREW-OH-01", "Dale Rutherford", 6, "Toledo Operations Center", "Substation"),
    ("CREW-OH-02", "Keisha Monroe", 3, "Toledo Operations Center", "Underground cable"),
    ("CREW-OH-03", "Evan Szabo", 5, "Lima Depot", "Substation"),
    ("CREW-OH-04", "Lorena Pruitt", 6, "Mansfield Depot", "Vegetation management"),
    ("CREW-OH-05", "Garrett Ames", 5, "Findlay Depot", "Overhead lines"),
]

# Leads for the 42 crews that exist only in Dataverse (none reuse API crew leads or persona names)
LEAD_NAMES = [
    "Dana Kowalski", "Raj Mehta", "Luc Tremblay", "Sarah O'Donnell", "Kwame Asante", "Mei Lin Zhou",
    "Tyler Brandt", "Aisha Rahman", "Paolo Ricci", "Jenna McAllister", "Owen Fraser", "Harpreet Gill",
    "Marisol Vega", "Ben Achterberg", "Nadia Petrova", "Curtis Blackwood", "Yuki Tanaka", "Grace Mbeki",
    "Declan Walsh", "Fatima Haddad", "Ivan Kovac", "Leah Goldstein", "Samir Farouk", "Colleen Brady",
    "Derek Nakamura", "Ines Carvalho", "Travis Holloway", "Anika Sorensen", "Gabriel Dufresne", "Hannah Voss",
    "Tessa Whitaker", "Victor Almeida", "Rhiannon Price", "Jonah Feldman", "Priscilla Ng", "Kieran Doyle",
    "Selena Ortiz", "Wes Hartley", "Lina Novak", "Andre Baptiste", "Maeve Gallagher", "Rohan Iyer",
]

SPECIALTIES = ["Overhead lines", "Underground cable", "Substation", "Vegetation management",
               "Protection and control", "Storm response"]

CERTS_COMMON = ["Lockout/Tagout (LOTO)", "First Aid and CPR", "Bucket Truck Rescue"]
CERTS_OPTIONAL = {
    "Overhead lines": ["Live-Line Glove 15 kV", "Live-Line Glove 27.6 kV", "Pole Top Rescue"],
    "Underground cable": ["Confined Space Entry", "Underground Cable Splicing", "Vault Entry"],
    "Substation": ["Substation Entry", "SF6 Gas Handling", "Transformer Oil Sampling"],
    "Protection and control": ["Substation Entry", "Relay Testing", "Arc Flash Level 4"],
    "Vegetation management": ["Vegetation Line Clearance", "Chainsaw Safety", "Aerial Lift Operation"],
    "Storm response": ["Live-Line Glove 15 kV", "Pole Top Rescue", "Traffic Control"],
}

PRIORITIES = [("Emergency", 6), ("High", 22), ("Routine", 57), ("Deferred", 15)]
WORK_TYPES = ["Inspection", "Preventive Maintenance", "Corrective Repair", "Replacement",
              "Emergency Restoration", "Vegetation Clearance"]

# Choice values used in schema.md and import-dataverse.ps1. Publisher option value prefix 71480.
CHOICES = {
    "hle_priority": {"Emergency": 714800000, "High": 714800001, "Routine": 714800002, "Deferred": 714800003},
    "hle_status": {"New": 714800100, "Scheduled": 714800101, "In Progress": 714800102, "On Hold": 714800103,
                   "Completed": 714800104, "Cancelled": 714800105},
}

TITLES = {
    "POLE": {
        "Inspection": ["Ten-year pole test and treat", "Visual inspection after vehicle contact report", "Ground-line inspection"],
        "Preventive Maintenance": ["Re-tension guy wire", "Replace pole number tag and reflector", "Install woodpecker guard"],
        "Corrective Repair": ["Replace cracked crossarm", "Straighten leaning pole", "Replace broken insulator on OH line"],
        "Replacement": ["Replace decayed pole", "Replace pole after car strike", "Upgrade to Class 2 pole for new TX"],
        "Emergency Restoration": ["Pole down, wires on road", "Pole fire at crossarm, feeder locked out", "Broken pole after ice storm"],
        "Vegetation Clearance": ["Trim trees encroaching on OH conductors", "Remove danger tree near pole", "Clear ROW vines on guy"],
    },
    "TX": {
        "Inspection": ["Infrared scan of TX connections", "Annual TX oil sample and DGA", "Pad-mount TX security check"],
        "Preventive Maintenance": ["Tighten TX secondary connections", "Repaint pad-mount TX cabinet", "Replace TX lock and signage"],
        "Corrective Repair": ["TX oil leak at bushing gasket", "Replace blown TX fuse", "TX tap changer drift, adjust"],
        "Replacement": ["Replace overloaded TX", "Replace TX with PCB label", "Upgrade TX for new service load"],
        "Emergency Restoration": ["TX failed, customers out", "TX fire, fire department on site", "TX flooded, isolate and replace"],
        "Vegetation Clearance": ["Clear shrubs around pad-mount TX", "Trim limbs over pole-mount TX", "Remove vines on TX enclosure"],
    },
    "SW": {
        "Inspection": ["SW operation test", "Infrared scan of SW blades", "Annual SW mechanism inspection"],
        "Preventive Maintenance": ["Lubricate SW mechanism", "Adjust SW blade alignment", "Replace SW operating handle lock"],
        "Corrective Repair": ["SW fails to operate", "SW blade burned, replace contacts", "SW motor operator fault"],
        "Replacement": ["Replace obsolete SW", "Replace SW with load-break unit", "Replace damaged SW after flashover"],
        "Emergency Restoration": ["SW stuck open during restoration", "SW flashover, feeder out", "SW damaged by lightning"],
        "Vegetation Clearance": ["Clear brush around SW structure", "Trim trees near SW", "Clear access path to SW"],
    },
    "BRK": {
        "Inspection": ["BRK trip timing test", "BRK counter reading and inspection", "BRK SF6 pressure check"],
        "Preventive Maintenance": ["BRK mechanism service", "Replace BRK trip coil", "BRK contact resistance test"],
        "Corrective Repair": ["BRK low SF6 alarm", "BRK failed to close on command", "BRK heater failure"],
        "Replacement": ["Replace oil BRK with vacuum BRK", "Replace BRK at end of life", "Replace BRK bushing"],
        "Emergency Restoration": ["BRK failed to trip on fault", "BRK tank rupture", "BRK lockout, station bus out"],
        "Vegetation Clearance": ["Clear weeds inside BRK fence", "Treat station yard vegetation", "Trim trees at station fence"],
    },
    "RCL": {
        "Inspection": ["RCL counter and battery check", "RCL controller firmware audit", "RCL visual inspection"],
        "Preventive Maintenance": ["Replace RCL control battery", "Update RCL settings", "Clean RCL bushings"],
        "Corrective Repair": ["RCL lockout on OH line", "RCL control communication loss", "RCL fails to reclose"],
        "Replacement": ["Replace hydraulic RCL with electronic RCL", "Replace RCL control cabinet", "Replace damaged RCL"],
        "Emergency Restoration": ["RCL lockout during storm", "RCL damaged by fault, feeder out", "RCL flashover"],
        "Vegetation Clearance": ["Trim trees near RCL", "Clear brush at RCL pole", "Remove danger tree upstream of RCL"],
    },
    "REG": {
        "Inspection": ["REG counter reading", "REG oil sample", "REG control check"],
        "Preventive Maintenance": ["REG control calibration", "REG bypass switch service", "Replace REG position indicator"],
        "Corrective Repair": ["REG stuck on tap", "REG control fault", "REG oil leak"],
        "Replacement": ["Replace REG at end of life", "Replace REG control", "Replace REG after lightning damage"],
        "Emergency Restoration": ["REG failed, low voltage complaints", "REG fire", "REG bypassed during outage"],
        "Vegetation Clearance": ["Trim trees near REG bank", "Clear REG platform vines", "Clear access to REG bank"],
    },
}

DESC_TAIL = [
    "Crew to confirm isolation points and complete LOTO before work.",
    "Coordinate with system control for switching orders.",
    "Customer notifications required if planned outage exceeds 2 hours.",
    "Take photos before and after work and attach to the WO.",
    "Check for nesting birds before work (seasonal restriction).",
    "Traffic control plan required on municipal road.",
    "Use insulated tools; minimum approach distance applies.",
    "Record readings in the asset history after completion.",
]

EARLIEST = date(2024, 10, 1)

# Planted asset numbers (fixed). Numbers are unique across all regions.
PLANTED_ASSETS = ["TX-ON-10423", "TX-OH-20871", "POLE-NY-20017", "SW-OH-30110", "POLE-ON-11250",
                  "BRK-NY-24480", "RCL-ON-13307", "TX-OH-31902", "POLE-NY-26615"]


def weighted(pairs):
    items = [p[0] for p in pairs]
    weights = [p[-1] for p in pairs]
    return rng.choices(items, weights=weights, k=1)[0]


def rand_date(a, b):
    return a + timedelta(days=rng.randint(0, (b - a).days))


# ---------------------------------------------------------------- assets
def build_assets():
    counts = {"ON": 600, "NY": 330, "OH": 270}
    base = {"ON": 10000, "NY": 20000, "OH": 30000}
    used = set(int(n.split("-")[2]) for n in PLANTED_ASSETS)
    assets = []
    for reg, n in counts.items():
        planted_here = sorted(p for p in PLANTED_ASSETS if p.split("-")[1] == reg)
        for _ in range(n - len(planted_here)):
            t = weighted([(p, w) for p, _, w in ASSET_TYPES])
            while True:
                num = rng.randint(base[reg] + 1, base[reg] + 9999)
                if num not in used:
                    used.add(num)
                    break
            assets.append(make_asset(f"{t}-{reg}-{num}", t, reg))
        for p in planted_here:
            assets.append(make_asset(p, p.split("-")[0], reg))
    return assets


def make_asset(number, t, reg):
    site = rng.choice(SITES[reg])
    year = rng.randint(1962, 2025)
    age = TODAY.year - year
    cond = max(5, min(100, int(rng.gauss(100 - age * 1.1, 10))))
    status = weighted(STATUS_ASSET)
    last_insp = rand_date(date(2023, 1, 1), date(2026, 9, 15))
    return {
        "AssetNumber": number,
        "AssetType": TYPE_LABEL[t],
        "Region": REGIONS[reg][0],
        "SiteCode": site[0],
        "SiteName": site[1],
        "City": site[2],
        "Manufacturer": rng.choice(MANUFACTURERS[t]),
        "Rating": rng.choice(RATINGS[t]),
        "InstallYear": year,
        "ConditionScore": cond,
        "OperationalStatus": status,
        "LastInspectionDate": last_insp.isoformat(),
    }


def set_site(a, code):
    s = SITE_BY_CODE[code]
    a.update(SiteCode=s[0], SiteName=s[1], City=s[2])


def plant_assets(assets):
    by = {a["AssetNumber"]: a for a in assets}
    fixed = {
        "TX-ON-10423": ("KNGSC", dict(Manufacturer="Northfield Transformer Co.", Rating="25 kVA pole-mount",
                                      InstallYear=1987, ConditionScore=38, OperationalStatus="In Service",
                                      LastInspectionDate="2026-08-28")),
        "TX-OH-20871": ("ASHDP", dict(Manufacturer="Lakeport Transformer Works", Rating="50 kVA pole-mount",
                                      InstallYear=1992, ConditionScore=44, OperationalStatus="In Service",
                                      LastInspectionDate="2025-10-14")),
        "POLE-NY-20017": ("WTNDP", dict(Manufacturer="Great Lakes Pole Co.", Rating="40 ft Class 3 wood",
                                        InstallYear=1958, ConditionScore=41, OperationalStatus="In Service",
                                        LastInspectionDate="2026-07-10")),
        "SW-OH-30110": ("LIMDP", dict(Manufacturer="Lakeport Switchgear", Rating="27.6 kV 600 A motorized",
                                      InstallYear=1994, ConditionScore=34, OperationalStatus="In Service",
                                      LastInspectionDate="2026-08-21")),
        "POLE-ON-11250": ("OSHSC", dict(Manufacturer="Timberline Utility Poles", Rating="45 ft Class 2 wood",
                                        InstallYear=1971, ConditionScore=12, OperationalStatus="Retired",
                                        LastInspectionDate="2025-03-04")),
        "BRK-NY-24480": ("MOHSS", dict(Manufacturer="Ridgeline Power Systems", Rating="69 kV 2,000 A SF6",
                                       InstallYear=2003, ConditionScore=63, OperationalStatus="In Service",
                                       LastInspectionDate="2025-07-18")),
        "RCL-ON-13307": ("BARDP", dict(Manufacturer="Corvane Industries", Rating="27.6 kV 800 A three-phase",
                                       InstallYear=2011, ConditionScore=71, OperationalStatus="In Service",
                                       LastInspectionDate="2026-05-30")),
        "TX-OH-31902": ("MAUSS", dict(Manufacturer="Lakeport Transformer Works", Rating="20 MVA station",
                                      InstallYear=1976, ConditionScore=24, OperationalStatus="Out of Service",
                                      LastInspectionDate="2026-03-12")),
        "POLE-NY-26615": ("ROCDP", dict(Manufacturer="Great Lakes Pole Co.", Rating="40 ft Class 3 wood",
                                        InstallYear=1989, ConditionScore=52, OperationalStatus="In Service",
                                        LastInspectionDate="2025-12-12")),
    }
    for num, (site, vals) in fixed.items():
        set_site(by[num], site)
        by[num].update(vals)
    # POLE-NY-20017 is the unique oldest asset
    for a in assets:
        if a["AssetNumber"] != "POLE-NY-20017" and a["InstallYear"] <= 1961:
            a["InstallYear"] = 1962


# ---------------------------------------------------------------- crews
def short_site(name):
    for suffix in (" Service Centre", " Operations Center", " Depot", " Transformer Station", " Substation"):
        if name.endswith(suffix):
            return name[: -len(suffix)]
    return name


def make_certs(spec, reg):
    certs = list(CERTS_COMMON)
    opts = CERTS_OPTIONAL[spec]
    certs += rng.sample(opts, k=rng.randint(1, len(opts)))
    if reg == "ON" and "Live-Line Glove 15 kV" in certs:
        certs[certs.index("Live-Line Glove 15 kV")] = "Live-Line Glove 27.6 kV"
    return "; ".join(dict.fromkeys(certs))


def build_crews():
    crews = []
    api_codes = {c[0] for c in API_CREWS}
    for code, lead, size, depot, spec in API_CREWS:
        reg = code.split("-")[1]
        crews.append({"CrewCode": code, "CrewName": "", "Region": REGIONS[reg][0], "BaseDepot": depot,
                      "Specialty": spec, "CrewLead": lead, "CrewSize": size, "Certifications": make_certs(spec, reg)})
    lead_iter = iter(LEAD_NAMES)
    counts = {"ON": 24, "NY": 18, "OH": 18}
    depots = {reg: [s[1] for s in SITES[reg] if s[3] == "depot"] for reg in SITES}
    k = 0
    for reg, n in counts.items():
        for i in range(1, n + 1):
            code = f"CREW-{reg}-{i:02d}"
            if code in api_codes:
                continue
            spec = SPECIALTIES[k % len(SPECIALTIES)]
            depot = depots[reg][k % len(depots[reg])]
            k += 1
            lead = next(lead_iter)
            crews.append({"CrewCode": code, "CrewName": "", "Region": REGIONS[reg][0], "BaseDepot": depot,
                          "Specialty": spec, "CrewLead": lead, "CrewSize": rng.randint(3, 8),
                          "Certifications": make_certs(spec, reg)})
    by = {c["CrewCode"]: c for c in crews}
    # planted crew facts (only non-API crews are changed)
    by["CREW-ON-17"]["CrewLead"] = "Dana Kowalski"  # same lead as CREW-ON-09 (P-DV-09)
    assert by["CREW-ON-09"]["CrewLead"] == "Dana Kowalski"
    by["CREW-ON-11"].update(Specialty="Storm response", BaseDepot="Kingston Service Centre",
                            Certifications="Lockout/Tagout (LOTO); First Aid and CPR; Bucket Truck Rescue; "
                                           "Live-Line Glove 27.6 kV; Pole Top Rescue; Traffic Control")
    by["CREW-ON-19"].update(Specialty="Overhead lines", BaseDepot="Barrie Depot",
                            Certifications="Lockout/Tagout (LOTO); First Aid and CPR; Bucket Truck Rescue; "
                                           "Live-Line Glove 27.6 kV; Pole Top Rescue")
    by["CREW-OH-06"].update(Specialty="Overhead lines", BaseDepot="Ashtabula Depot",
                            Certifications="Lockout/Tagout (LOTO); First Aid and CPR; Bucket Truck Rescue; "
                                           "Live-Line Glove 15 kV; Pole Top Rescue")
    by["CREW-OH-07"].update(Specialty="Storm response", BaseDepot="Toledo Operations Center",
                            Certifications="Lockout/Tagout (LOTO); First Aid and CPR; Bucket Truck Rescue; "
                                           "Live-Line Barehand 69 kV; Pole Top Rescue")
    for c in crews:
        if "Barehand" in c["Certifications"] and c["CrewCode"] != "CREW-OH-07":
            raise AssertionError("barehand must be unique")
    # names: "<depot short> <Specialty> Crew <letter>", letters counted per depot and specialty
    crews.sort(key=lambda c: c["CrewCode"])
    seen = Counter()
    for c in crews:
        key = (c["BaseDepot"], c["Specialty"])
        seen[key] += 1
        spec_title = " ".join(w if w == "and" else w.capitalize() for w in c["Specialty"].split())
        c["CrewName"] = f"{short_site(c['BaseDepot'])} {spec_title} Crew {chr(64 + seen[key])}"
    return crews


# ---------------------------------------------------------------- work orders
def pick_status(opened, priority):
    age = (TODAY - opened).days
    if priority == "Emergency" and age > 7:
        return weighted([("Completed", 97), ("Cancelled", 3)])
    if age > 90:
        if priority == "Deferred":
            return weighted([("Completed", 70), ("Cancelled", 12), ("On Hold", 18)])
        return weighted([("Completed", 92), ("Cancelled", 6), ("On Hold", 2)])
    if priority == "Emergency":
        return weighted([("In Progress", 45), ("Scheduled", 15), ("Completed", 40)])
    return weighted([("New", 18), ("Scheduled", 27), ("In Progress", 20), ("On Hold", 8), ("Completed", 27)])


DUE_DAYS = {"Emergency": 1, "High": 7, "Routine": 30, "Deferred": 120}
HOURS = {"Inspection": (2, 6), "Preventive Maintenance": (3, 10), "Corrective Repair": (4, 16),
         "Replacement": (8, 40), "Emergency Restoration": (4, 24), "Vegetation Clearance": (4, 20)}
COST_PER_HOUR = {"CAD": 185, "USD": 165}
MATERIAL = {"Pole": 4200, "Transformer": 18500, "Switch": 9800, "Breaker": 62000, "Recloser": 38000,
            "Voltage Regulator": 27000}


def make_wo(asset, crew, opened, priority, work_type, prefix_t):
    reg_code = asset["AssetNumber"].split("-")[1]
    currency = REGIONS[reg_code][1]
    title_core = rng.choice(TITLES[prefix_t][work_type])
    status = pick_status(opened, priority)
    due = opened + timedelta(days=DUE_DAYS[priority])
    lo, hi = HOURS[work_type]
    est = round(rng.uniform(lo, hi) * 2) / 2
    completed = ""
    actual = ""
    if status == "Completed":
        c = opened + timedelta(days=max(0, int(DUE_DAYS[priority] * rng.uniform(0.2, 1.3))))
        c = min(c, TODAY)
        completed = c.isoformat()
        actual = round(est * rng.uniform(0.7, 1.5) * 2) / 2
    cost = est * COST_PER_HOUR[currency]
    if work_type == "Replacement":
        cost += MATERIAL[asset["AssetType"]]
    desc = (f"{title_core} on {asset['AssetNumber']} ({asset['AssetType'].lower()}, {asset['Rating']}) at "
            f"{asset['SiteName']}. " + " ".join(rng.sample(DESC_TAIL, 2)))
    return {
        "WorkOrderNumber": "",
        "Title": f"{title_core}: {asset['AssetNumber']}",
        "Description": desc,
        "WorkType": work_type,
        "Priority": priority,
        "Status": status,
        "AssetNumber": asset["AssetNumber"],
        "CrewCode": crew["CrewCode"],
        "Region": asset["Region"],
        "OpenedOn": opened.isoformat(),
        "DueDate": due.isoformat(),
        "CompletedOn": completed,
        "EstimatedHours": est,
        "ActualHours": actual,
        "EstimatedCost": round(cost, 2),
        "Currency": currency,
    }


def work_type_for(priority):
    if priority == "Emergency":
        return "Emergency Restoration"
    return rng.choice([w for w in WORK_TYPES if w != "Emergency Restoration"])


def pick_crew(region_crews, t, wt):
    if wt == "Vegetation Clearance":
        wanted = {"Vegetation management"}
    elif wt == "Emergency Restoration":
        wanted = {"Storm response", "Overhead lines"}
    elif t in ("BRK", "REG") or (t == "TX" and rng.random() < 0.4):
        wanted = {"Substation", "Protection and control"}
    elif t == "TX":
        wanted = {"Overhead lines", "Underground cable"}
    else:
        wanted = {"Overhead lines", "Storm response", "Protection and control"}
    pool = [c for c in region_crews if c["Specialty"] in wanted] or region_crews
    return rng.choice(pool)


def build_work_orders(assets, crews):
    crews_by_region = defaultdict(list)
    for c in crews:
        crews_by_region[c["Region"]].append(c)
    by_asset = {a["AssetNumber"]: a for a in assets}
    crew_by = {c["CrewCode"]: c for c in crews}
    reserved = set(PLANTED_ASSETS) - {"POLE-NY-20017"}
    per_asset = Counter()
    wos = []
    random_assets = [a for a in assets if a["AssetNumber"] not in reserved]

    planted = []

    def add(asset_no, crew_code, opened, priority, work_type, status, title, desc, due=None,
            completed=None, est=None, actual=None, cost=None, tag=None):
        a = by_asset[asset_no]
        c = crew_by[crew_code]
        wo = make_wo(a, c, opened, priority, work_type, asset_no.split("-")[0])
        wo.update(Status=status, Title=title, Description=desc)
        if due:
            wo["DueDate"] = due.isoformat()
        wo["CompletedOn"] = completed.isoformat() if completed else ""
        if status != "Completed":
            wo["ActualHours"] = ""
        if est is not None:
            wo["EstimatedHours"] = est
        if actual is not None:
            wo["ActualHours"] = actual
        if cost is not None:
            wo["EstimatedCost"] = cost
        wo["_tag"] = tag
        planted.append(wo)

    # P-DV-01 TX-ON-10423 (Kingston pole-mount; Lab 9 field report FR-EON-2026-1187 on 2026-10-01)
    add("TX-ON-10423", "CREW-ON-03", date(2025, 11, 3), "Routine", "Inspection", "Completed",
        "Visual inspection of pole-mount TX: TX-ON-10423",
        "Routine patrol inspection of TX-ON-10423 (25 kVA pole-mount, pole P-30912, Bath Road near Collins Bay "
        "Road, Kingston). Tank, bushings and lid gasket in good condition. No oil staining.",
        completed=date(2025, 11, 20), est=2.0, actual=2.0, cost=370.0, tag="P-DV-01")
    add("TX-ON-10423", "CREW-ON-03", date(2026, 8, 28), "High", "Inspection", "Completed",
        "Infrared scan of TX connections: TX-ON-10423",
        "Infrared scan of TX-ON-10423 on pole P-30912, Bath Road, Kingston: connections normal. Light oil film "
        "noted at the tank lid gasket. Monitor at next patrol; no action required yet.",
        completed=date(2026, 9, 2), est=3.0, actual=3.0, cost=555.0, tag="P-DV-01")

    # P-DV-03 TX-OH-20871 (Ashtabula pole-mount; Lab 9 field report FR-OHN-2026-0918 on 2026-10-03)
    add("TX-OH-20871", "CREW-OH-06", date(2025, 10, 9), "Routine", "Inspection", "Completed",
        "Visual inspection of pole-mount TX: TX-OH-20871",
        "Routine inspection of TX-OH-20871 (50 kVA pole-mount, pole P-51260, Lake Avenue at West 5th Street, "
        "Ashtabula). Primary bushing has minor surface tracking; wildlife guard present. Recommend cleaning at "
        "next planned outage.", completed=date(2025, 10, 14), est=2.0, actual=2.5, cost=330.0, tag="P-DV-03")

    # P-DV-04 SW-OH-30110 nine work orders, repeat failures
    sw_dates = [date(2024, 11, 14), date(2025, 1, 22), date(2025, 3, 9), date(2025, 5, 30), date(2025, 8, 12),
                date(2025, 10, 27), date(2026, 1, 16), date(2026, 5, 4), date(2026, 9, 18)]
    sw_crews = ["CREW-OH-03", "CREW-OH-03", "CREW-OH-01", "CREW-OH-03", "CREW-OH-03", "CREW-OH-01",
                "CREW-OH-03", "CREW-OH-03", "CREW-OH-07"]
    for i, (d, cc) in enumerate(zip(sw_dates, sw_crews)):
        last = i == len(sw_dates) - 1
        add("SW-OH-30110", cc, d, "High" if not last else "Emergency",
            "Corrective Repair" if not last else "Emergency Restoration",
            "Completed" if not last else "Scheduled",
            ("SW fails to operate: SW-OH-30110" if not last else "SW stuck open during restoration: SW-OH-30110"),
            (f"Motor operator on SW-OH-30110 (Lima) failed to open on SCADA command (occurrence {i + 1}). "
             "Reset control, cleaned contacts and tested three operations."
             if not last else
             "SW-OH-30110 (Lima) stuck open during feeder restoration on 2026-09-18; field crew used manual "
             "bypass. Ninth failure in 23 months. Engineering review of replacement requested."),
            completed=(d + timedelta(days=3)) if not last else None,
            est=6.0, actual=(6.5 if not last else None), cost=990.0, tag="P-DV-04")

    # P-DV-05 mutual aid: Ontario crew on NY asset
    add("POLE-NY-26615", "CREW-ON-11", date(2025, 12, 11), "Emergency", "Emergency Restoration", "Completed",
        "Broken pole after ice storm: POLE-NY-26615",
        "Ice storm Ulla: pole POLE-NY-26615 snapped at ground line on feeder ROC-7 near Rochester. Restored by "
        "Ontario crew CREW-ON-11 under the cross-border mutual assistance agreement. Replaced with 40 ft Class 3 "
        "pole.", completed=date(2025, 12, 12), est=12.0, actual=14.5, cost=6180.0, tag="P-DV-05")

    # P-DV-06 retired asset with active WO (data defect)
    add("POLE-ON-11250", "CREW-ON-06", date(2025, 2, 17), "Routine", "Inspection", "Completed",
        "Ten-year pole test and treat: POLE-ON-11250",
        "Ground-line decay found on POLE-ON-11250 (Oshawa), remaining strength 58 percent. Recommend replacement.",
        completed=date(2025, 3, 4), est=2.0, actual=2.0, cost=370.0, tag="P-DV-06")
    add("POLE-ON-11250", "CREW-ON-06", date(2026, 9, 21), "Routine", "Corrective Repair", "In Progress",
        "Replace cracked crossarm: POLE-ON-11250",
        "Crossarm on POLE-ON-11250 (Oshawa) cracked at the through-bolt. Crew to confirm isolation and complete "
        "LOTO. Note: asset record shows status Retired.", est=6.0, cost=1110.0, tag="P-DV-06")

    # P-DV-07 deferred, on hold for outage window
    add("BRK-NY-24480", "CREW-NY-03", date(2025, 7, 15), "Routine", "Inspection", "Completed",
        "BRK SF6 pressure check: BRK-NY-24480",
        "SF6 pressure on BRK-NY-24480 at 0.58 MPa, alarm at 0.55 MPa. Monitor monthly.",
        completed=date(2025, 7, 18), est=2.0, actual=2.0, cost=330.0, tag="P-DV-07")
    add("BRK-NY-24480", "CREW-NY-03", date(2026, 6, 2), "Deferred", "Preventive Maintenance", "On Hold",
        "BRK mechanism service: BRK-NY-24480",
        "Mechanism service on 69 kV breaker BRK-NY-24480 at Mohawk Valley Substation is on hold awaiting a "
        "planned outage window. System control has offered the window of 2027-01-12 to 2027-01-15.",
        due=date(2027, 1, 15), est=16.0, cost=2640.0, tag="P-DV-07")

    # P-DV-08 OH means overhead, not Ohio (glossary trap)
    add("RCL-ON-13307", "CREW-ON-19", date(2026, 9, 24), "High", "Corrective Repair", "Scheduled",
        "RCL lockout on OH line: RCL-ON-13307",
        "RCL-ON-13307 locked out three times on the OH line section of feeder 44M7 near Barrie. Suspect "
        "tree contact on the OH conductors downstream. Patrol the ROW and report before reclosing.",
        est=8.0, cost=1480.0, tag="P-DV-08")

    # P-DV-10 highest cost
    add("TX-OH-31902", "CREW-OH-01", date(2026, 4, 7), "High", "Replacement", "Scheduled",
        "Replace 20 MVA station TX: TX-OH-31902",
        "Station transformer TX-OH-31902 at Maumee Bay Substation (Toledo) failed its insulation power factor "
        "test and was removed from service. Replace with new 20 MVA unit (long-lead item, delivery expected "
        "2026-11). Total approved budget USD 1,850,000 including mobile TX rental. Capital project CP-2026-117.",
        due=date(2026, 12, 15), est=320.0, cost=1850000.0, tag="P-DV-10")

    # P-DV-02 oldest asset
    add("POLE-NY-20017", "CREW-NY-01", date(2026, 7, 8), "Routine", "Inspection", "Completed",
        "Ten-year pole test and treat: POLE-NY-20017",
        "POLE-NY-20017 (Watertown, installed 1958, oldest pole in service) passed resistograph test with 71 "
        "percent remaining strength. Retreated at ground line. Next test due 2031.",
        completed=date(2026, 7, 10), est=2.0, actual=2.5, cost=330.0, tag="P-DV-02")

    n_planted = len(planted)
    assert n_planted == 20, n_planted
    while len(wos) < 3000 - n_planted:
        a = rng.choice(random_assets)
        if per_asset[a["AssetNumber"]] >= 7:
            continue
        priority = weighted(PRIORITIES)
        opened = rand_date(EARLIEST, TODAY)
        if a["OperationalStatus"] == "Retired" and opened > date(2025, 3, 31):
            continue
        t = a["AssetNumber"].split("-")[0]
        wt = work_type_for(priority)
        crew = pick_crew(crews_by_region[a["Region"]], t, wt)
        wo = make_wo(a, crew, opened, priority, wt, t)
        if a["OperationalStatus"] == "Retired" and wo["Status"] not in ("Completed", "Cancelled"):
            wo["Status"] = "Cancelled"
        wos.append(wo)
        per_asset[a["AssetNumber"]] += 1

    wos.extend(planted)
    wos.sort(key=lambda w: (w["OpenedOn"], w["AssetNumber"], w["Title"]))
    seq = Counter()
    for w in wos:
        y = w["OpenedOn"][:4]
        seq[y] += 1
        w["WorkOrderNumber"] = f"WO-{y}-{seq[y]:05d}"
    return wos


WO_FIELDS = ["WorkOrderNumber", "Title", "Description", "WorkType", "Priority", "Status", "AssetNumber",
             "CrewCode", "Region", "OpenedOn", "DueDate", "CompletedOn", "EstimatedHours", "ActualHours",
             "EstimatedCost", "Currency"]
ASSET_FIELDS = ["AssetNumber", "AssetType", "Region", "SiteCode", "SiteName", "City", "Manufacturer", "Rating",
                "InstallYear", "ConditionScore", "OperationalStatus", "LastInspectionDate"]
CREW_FIELDS = ["CrewCode", "CrewName", "Region", "BaseDepot", "Specialty", "CrewLead", "CrewSize",
               "Certifications"]


def main():
    os.makedirs(OUT, exist_ok=True)
    assets = build_assets()
    plant_assets(assets)
    assets.sort(key=lambda a: a["AssetNumber"])
    crews = build_crews()
    wos = build_work_orders(assets, crews)

    def write(name, rows, fields):
        with open(os.path.join(OUT, name), "w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=fields, extrasaction="ignore", lineterminator="\n")
            w.writeheader()
            w.writerows(rows)

    write("Assets.csv", assets, ASSET_FIELDS)
    write("Crews.csv", crews, CREW_FIELDS)
    write("WorkOrders.csv", wos, WO_FIELDS)

    # verify API crew rows are exact
    api_path = os.path.join(ROOT, "data", "api", "src", "data", "crews.json")
    if os.path.exists(api_path):
        with open(api_path, encoding="utf-8") as f:
            api = {c["crewId"]: c for c in json.load(f)}
        for c in crews:
            if c["CrewCode"] in api:
                x = api[c["CrewCode"]]
                assert (x["crewLead"], x["crewSize"], x["baseDepot"], x["specialty"]) == \
                       (c["CrewLead"], c["CrewSize"], c["BaseDepot"], c["Specialty"]), c["CrewCode"]
        assert set(api) <= {c["CrewCode"] for c in crews}

    open_states = {"New", "Scheduled", "In Progress", "On Hold"}
    status_of = {a["AssetNumber"]: a["OperationalStatus"] for a in assets}
    facts = {
        "asset_count": len(assets),
        "crew_count": len(crews),
        "wo_count": len(wos),
        "assets_by_region": Counter(a["Region"] for a in assets),
        "assets_by_type": Counter(a["AssetType"] for a in assets),
        "assets_by_status": Counter(a["OperationalStatus"] for a in assets),
        "assets_condition_below_30": sum(1 for a in assets if a["ConditionScore"] < 30),
        "assets_condition_below_30_by_region": Counter(a["Region"] for a in assets if a["ConditionScore"] < 30),
        "crews_by_region": Counter(c["Region"] for c in crews),
        "crews_by_specialty": Counter(c["Specialty"] for c in crews),
        "wo_by_priority": Counter(w["Priority"] for w in wos),
        "wo_by_status": Counter(w["Status"] for w in wos),
        "wo_by_region": Counter(w["Region"] for w in wos),
        "open_emergency": sorted(w["WorkOrderNumber"] + " " + w["AssetNumber"] + " " + w["Status"] + " " +
                                 w["CrewCode"] for w in wos
                                 if w["Priority"] == "Emergency" and w["Status"] in open_states),
        "open_wo_count": sum(1 for w in wos if w["Status"] in open_states),
        "open_wo_by_region": Counter(w["Region"] for w in wos if w["Status"] in open_states),
        "overdue_open_as_of_2026_09_30": sum(1 for w in wos if w["Status"] in open_states
                                             and w["DueDate"] < TODAY.isoformat()),
        "max_wo_per_asset_excluding_SW-OH-30110": max(Counter(w["AssetNumber"] for w in wos
                                                              if w["AssetNumber"] != "SW-OH-30110").values()),
        "wo_per_planted_asset": {k: sum(1 for w in wos if w["AssetNumber"] == k) for k in PLANTED_ASSETS},
        "top_costs": sorted(((w["EstimatedCost"], w["WorkOrderNumber"]) for w in wos), reverse=True)[:3],
        "oldest_install_years": sorted({a["InstallYear"] for a in assets})[:3],
        "lowest_condition_assets": sorted((a["ConditionScore"], a["AssetNumber"]) for a in assets)[:5],
        "crews_with_barehand": [c["CrewCode"] for c in crews if "Barehand" in c["Certifications"]],
        "crews_led_by_dana": [c["CrewCode"] for c in crews if c["CrewLead"] == "Dana Kowalski"],
        "cross_region_wos": [w["WorkOrderNumber"] for w in wos
                             if w["CrewCode"].split("-")[1] != w["AssetNumber"].split("-")[1]],
        "retired_assets_with_open_wo": sorted({w["AssetNumber"] for w in wos if w["Status"] in open_states
                                               and status_of[w["AssetNumber"]] == "Retired"}),
        "wo_for_TX-ON-10423": [w["WorkOrderNumber"] for w in wos if w["AssetNumber"] == "TX-ON-10423"],
        "wo_for_TX-OH-20871": [w["WorkOrderNumber"] for w in wos if w["AssetNumber"] == "TX-OH-20871"],
        "planted_wos": [dict(w) for w in wos if w.get("_tag")],
        "choice_values": CHOICES,
    }
    with open(os.path.join(OUT, "_facts.json"), "w", encoding="utf-8") as f:
        json.dump(facts, f, indent=2, default=str)
    print(json.dumps({k: facts[k] for k in ["asset_count", "crew_count", "wo_count", "open_emergency",
                                            "cross_region_wos", "retired_assets_with_open_wo",
                                            "crews_with_barehand", "crews_led_by_dana"]}, indent=1, default=str))


if __name__ == "__main__":
    main()
