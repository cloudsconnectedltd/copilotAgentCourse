"""Regenerate reference/caveats-index.md from labs/*/caveats.csv.

Run from the repository root: python3 tools/build_caveats_index.py
"""
import csv
import glob
import os
import re


def slug(heading):
    h = heading.strip().lower()
    h = re.sub(r"[^\w\- ]", "", h)
    return h.replace(" ", "-")


def cell(s):
    return (s or "").replace("|", "/").replace("\n", " ").strip()


def main():
    out = [
        "# Caveats index",
        "",
        "Every caveat the course triggers, one row each. The **Lab** column links to the break-it section that reproduces it. "
        "Limit IDs refer to [limits.md](limits.md); rows tagged SNIP or UNVERIFIED there need a check on Microsoft Learn.",
        "",
        "Generated from `labs/*/caveats.csv` by `tools/build_caveats_index.py`. Edit those files, then regenerate this index.",
        "",
    ]
    missing = []
    for f in sorted(glob.glob("labs/*/caveats.csv")):
        d = os.path.dirname(f)
        lab = os.path.basename(d)
        bi = os.path.join(d, "break-it.md")
        heads = [l.lstrip("#").strip() for l in open(bi, encoding="utf-8") if l.startswith("#")] if os.path.exists(bi) else []
        num = lab.split("-")[1]
        out += [f"## Lab {num}: [{lab}](../labs/{lab}/README.md)", "",
                "| ID | Caveat | Symptom | Cause | Fix | Limits | Lab | Doc |",
                "|---|---|---|---|---|---|---|---|"]
        for x in csv.DictReader(open(f, newline="", encoding="utf-8")):
            h = [h for h in heads if x["caveat_id"] in h]
            link = f"../labs/{lab}/break-it.md" + (f"#{slug(h[0])}" if h else "")
            if not h:
                missing.append(x["caveat_id"])
            docs = " ".join(f"[doc]({u.strip()})" for u in re.split(r"[ ;]+", x["doc_url"]) if u.strip().startswith("http"))
            out.append(f"| {x['caveat_id']} | {cell(x['name'])} | {cell(x['symptom'])} | {cell(x['cause'])} | "
                       f"{cell(x['fix'])} | {cell(x['limit_ids'])} | [break-it]({link}) | {docs} |")
        out.append("")
    with open("reference/caveats-index.md", "w", encoding="utf-8") as fh:
        fh.write("\n".join(out))
    if missing:
        print("No break-it heading found for:", ", ".join(missing))


if __name__ == "__main__":
    main()
