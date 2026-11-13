"""Download Poly Haven (CC0) assets.
usage: python3 tools/fetch/polyhaven.py model street_rat 2k
       python3 tools/fetch/polyhaven.py texture bamboo_wall 4k
"""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from common import ROOT, get_json, download, ledger

def main(kind, asset_id, res="2k"):
    info = get_json(f"https://api.polyhaven.com/info/{asset_id}")
    files = get_json(f"https://api.polyhaven.com/files/{asset_id}")
    authors = ", ".join(info.get("authors", {}).keys())
    if kind == "model":
        out = os.path.join(ROOT, "assets", "models", "polyhaven", asset_id)
        g = files["gltf"][res]["gltf"]
        download(g["url"], os.path.join(out, f"{asset_id}.gltf"), g.get("md5"))
        for rel, f in g["include"].items():
            download(f["url"], os.path.join(out, rel), f.get("md5"))
    else:
        out = os.path.join(ROOT, "assets", "textures", "polyhaven", asset_id)
        maps = {"Diffuse": "diff", "nor_gl": "nor_gl", "arm": "arm"}  # arm = AO, Rough, Metal packed
        for key, short in maps.items():
            if key in files and res in files[key]:
                fmt = "jpg" if "jpg" in files[key][res] else "png"
                f = files[key][res][fmt]
                download(f["url"], os.path.join(out, f"{asset_id}_{short}_{res}.{fmt}"), f.get("md5"))
    ledger(f"polyhaven/{asset_id}", "Poly Haven", f"https://polyhaven.com/a/{asset_id}", authors, "CC0")
    print("ok", asset_id, "->", out)

if __name__ == "__main__":
    main(*sys.argv[1:])
