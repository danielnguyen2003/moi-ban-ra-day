"""Download a Sketchfab model (glb) with its license into assets/models/sketchfab/<slug>/.
The API token is injected by the session proxy; locally set SKETCHFAB_TOKEN instead.
usage: python3 tools/fetch/sketchfab.py <uid> <slug>
"""
import os, sys, zipfile
sys.path.insert(0, os.path.dirname(__file__))
from common import ROOT, get_json, download, ledger

ALLOWED = {"by", "cc0"}

def main(uid, slug):
    tok = os.environ.get("SKETCHFAB_TOKEN")
    hdr = {"Authorization": f"Token {tok}"} if tok else {}
    info = get_json(f"https://api.sketchfab.com/v3/models/{uid}", hdr)
    lic = (info.get("license") or {}).get("slug")
    if lic not in ALLOWED:
        sys.exit(f"refusing {uid}: license {lic!r} not in {ALLOWED}")
    links = get_json(f"https://api.sketchfab.com/v3/models/{uid}/download", hdr)
    out = os.path.join(ROOT, "assets", "models", "sketchfab", slug)
    if "glb" in links:
        download(links["glb"]["url"], os.path.join(out, f"{slug}.glb"))
    else:
        z = download(links["gltf"]["url"], os.path.join(out, "gltf.zip"))
        zipfile.ZipFile(z).extractall(out); os.remove(z)
    author = info["user"]["displayName"] or info["user"]["username"]
    ledger(f"sketchfab/{slug}", "Sketchfab", info["viewerUrl"], author,
           "CC0" if lic == "cc0" else "CC-BY-4.0")
    with open(os.path.join(out, "LICENSE.txt"), "w", encoding="utf-8") as f:
        f.write(f"{info['name']} by {author}\n{info['viewerUrl']}\nLicense: {info['license']['label']}\n")
    print("ok", slug, lic, author)

if __name__ == "__main__":
    main(*sys.argv[1:])
