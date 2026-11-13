"""Fail if any asset folder under assets/models or assets/textures or assets/audio lacks a ledger row."""
import csv, os, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
names = {r["name"] for r in csv.DictReader(open(os.path.join(ROOT, "docs", "ASSET_LEDGER.csv"), encoding="utf-8"))}
missing = []
for kind in ("models", "textures", "audio", "fonts"):
    base = os.path.join(ROOT, "assets", kind)
    if not os.path.isdir(base):
        continue
    for src in sorted(os.listdir(base)):
        for item in sorted(os.listdir(os.path.join(base, src))):
            if f"{src}/{item}" not in names:
                missing.append(f"assets/{kind}/{src}/{item}")
if missing:
    print("Missing ledger rows:\n  " + "\n  ".join(missing)); sys.exit(1)
print(f"ledger ok ({len(names)} entries)")
