"""Course repository self-check.

Run from the repository root: python3 tools/self-check.py

Checks:
  1. Every file listed in the PLAN.md inventory (section 4.7) exists.
  2. Every caveat in reference/caveats-index.md links to an existing lab break-it section.
  3. Every eval CSV expected_source that names a repo path points to a file in data/.
  4. Every relative Markdown link resolves (file and, for .md targets, heading anchor).
  5. No em or en dashes in text files or inside docx, xlsx and pptx XML.
Exit code 1 if any check fails.
"""
import csv
import glob
import os
import re
import sys
import zipfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
os.chdir(ROOT)

# Generated at setup time and gitignored; allowed as eval sources.
GENERATED = {
    "data/sharepoint/Harbourline-Hub/HR-Policies/Employee-Handbook-Full.docx": "tools/generate-data/generate_oversized_handbook.py",
    "data/sharepoint/Harbourline-Operations/Archive-Bulk/": "tools/generate-data/generate_archive_bulk.py",
}
NON_PATH_PREFIXES = ("api:", "dataverse:", "connector:", "agent:", "admin:", "none")
DASHES = (chr(0x2013), chr(0x2014))
SKIP_DIRS = {".git", "node_modules", "__pycache__"}

failures = []


def fail(check, msg):
    failures.append(f"[{check}] {msg}")


def slug(heading):
    h = re.sub(r"`", "", heading.strip().lower())
    h = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", h)
    h = re.sub(r"[^\w\- ]", "", h)
    return h.replace(" ", "-")


def anchors(path):
    out, seen = set(), {}
    in_code = False
    for line in open(path, encoding="utf-8"):
        if line.lstrip().startswith("```"):
            in_code = not in_code
        if in_code or not line.startswith("#"):
            continue
        s = slug(line.lstrip("#"))
        n = seen.get(s, 0)
        out.add(s if n == 0 else f"{s}-{n}")
        seen[s] = n + 1
    return out


def walk(exts):
    for d, dirs, files in os.walk("."):
        dirs[:] = [x for x in dirs if x not in SKIP_DIRS]
        for f in files:
            if f.lower().endswith(exts):
                yield os.path.normpath(os.path.join(d, f))


def generated_ok(path):
    for g, gen in GENERATED.items():
        if path == g or (g.endswith("/") and (path + "/").startswith(g)):
            return os.path.exists(gen)
    return False


# 1. PLAN inventory
plan = open("PLAN.md", encoding="utf-8").read()
inv = plan.split("### 4.7 Full file inventory", 1)[1].split("```", 2)[1]
for raw in inv.splitlines():
    entry = raw.split("#", 1)[0].strip()
    if not entry:
        continue
    m = re.match(r"^(\S+?)/\{([^}]*)\}", entry)
    paths = []
    if m:
        paths = [f"{m.group(1)}/{p.strip()}" for p in m.group(2).split(",") if p.strip() and "..." not in p]
    elif "..." in entry:
        base = entry.split("...")[0].strip().rstrip("/")
        paths = [base] if base and not base.endswith(".csv") else []
    else:
        paths = [re.sub(r"\s*\(.*$", "", entry).split(" + ")[0].strip()]
    for p in paths:
        p = p.rstrip("/")
        if not p:
            continue
        if "*" in p:
            base = p.split("*")[0].rstrip("/")
            if not os.path.isdir(base):
                fail("inventory", f"missing folder: {base}")
            continue
        if not (os.path.exists(p) or generated_ok(p) or glob.glob(p + "*")):
            fail("inventory", f"missing: {p}")
for n in range(1, 13):
    lab = glob.glob(f"labs/lab-{n:02d}-*")
    if not lab:
        fail("inventory", f"lab {n:02d} folder missing")
        continue
    need = ["README.md", "validate.md", "cleanup.md"] + (["facilitator-notes.md", "recap.md"] if n == 1 else ["break-it.md"])
    for f in need:
        if not os.path.exists(os.path.join(lab[0], f)):
            fail("inventory", f"{lab[0]}/{f} missing")
    if not os.path.exists(f"evals/lab-{n:02d}-questions.csv"):
        fail("inventory", f"evals/lab-{n:02d}-questions.csv missing")
    if not os.path.isdir(f"solutions/lab-{n:02d}"):
        fail("inventory", f"solutions/lab-{n:02d} missing")

# 2. Caveats link to labs
idx = open("reference/caveats-index.md", encoding="utf-8").read()
rows = [l for l in idx.splitlines() if re.match(r"^\| C-\d\d-[a-z] \|", l)]
if not rows:
    fail("caveats", "no caveat rows found")
for r in rows:
    cid = r.split("|")[1].strip()
    m = re.search(r"\[break-it\]\(\.\./(labs/[^)#]+)(#[^)]*)?\)", r)
    if not m:
        fail("caveats", f"{cid} has no lab link")
        continue
    target = m.group(1)
    if not os.path.exists(target):
        fail("caveats", f"{cid} links to missing {target}")
    elif m.group(2) and m.group(2)[1:] not in anchors(target):
        fail("caveats", f"{cid} anchor {m.group(2)} not in {target}")

# 3. Eval sources exist
for f in sorted(glob.glob("evals/*-questions.csv")):
    for row in csv.DictReader(open(f, newline="", encoding="utf-8")):
        src = (row.get("expected_source") or "").strip()
        for part in [s.strip() for s in src.split(";") if s.strip()]:
            if part.startswith(NON_PATH_PREFIXES):
                continue
            if not part.startswith("data/"):
                fail("evals", f"{f} {row['id']}: source not in data/: {part}")
            elif not (os.path.exists(part) or generated_ok(part)):
                fail("evals", f"{f} {row['id']}: missing source {part}")

# 4. Markdown links
link_re = re.compile(r"(?<!!)\[[^\]]*\]\(([^)\s]+)\)")
for md in walk((".md",)):
    text = open(md, encoding="utf-8").read()
    text = re.sub(r"```.*?```", "", text, flags=re.S)
    for target in link_re.findall(text):
        if re.match(r"^[a-z]+:", target) or target.startswith("<"):
            continue
        path, _, frag = target.partition("#")
        full = os.path.normpath(os.path.join(os.path.dirname(md), path)) if path else md
        if not os.path.exists(full):
            fail("links", f"{md}: broken link {target}")
        elif frag and full.endswith(".md") and frag not in anchors(full):
            fail("links", f"{md}: missing anchor {target}")

# 5. Dashes
for p in walk((".md", ".csv", ".ps1", ".psm1", ".py", ".js", ".mjs", ".json", ".yaml", ".yml", ".sql", ".txt", ".http")):
    if p.endswith("package-lock.json"):
        continue
    t = open(p, encoding="utf-8", errors="ignore").read()
    if any(d in t for d in DASHES):
        fail("dashes", p)
for p in walk((".docx", ".xlsx", ".pptx")):
    with zipfile.ZipFile(p) as z:
        for n in z.namelist():
            if n.endswith(".xml") and any(d in z.read(n).decode("utf-8", "ignore") for d in DASHES):
                fail("dashes", f"{p}:{n}")
                break

if failures:
    print("\n".join(failures))
    print(f"\nFAILED: {len(failures)} problem(s)")
    sys.exit(1)
print("All checks passed.")
