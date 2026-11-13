"""Search/download Freesound HQ previews (CC0 / CC-BY only). Key is proxy-injected (header Authorization: Token ...).
usage: python3 tools/fetch/freesound.py search "night insects vietnam"
       python3 tools/fetch/freesound.py get <sound_id> <slug>
"""
import json, os, sys, urllib.parse
sys.path.insert(0, os.path.dirname(__file__))
from common import ROOT, get_json, download, ledger

API = "https://freesound.org/apiv2"
OK = ("Creative Commons 0", "Attribution")
HDR = {"Authorization": "Token " + os.environ.get("FREESOUND_KEY", "proxy-injected")}

def search(q):
    flt = 'license:("Creative Commons 0" OR "Attribution")'
    url = f"{API}/search/text/?query={urllib.parse.quote(q)}&filter={urllib.parse.quote(flt)}&fields=id,name,license,duration,username,avg_rating&page_size=20&sort=rating_desc"
    for r in get_json(url, HDR)["results"]:
        print(f'{r["id"]:>8}  {r["duration"]:6.1f}s  {r["avg_rating"]:.1f}  {r["license"].split("/")[-3] if "/" in r["license"] else r["license"]:<10} {r["username"][:16]:<16} {r["name"][:60]}')

def get(sid, slug):
    s = get_json(f"{API}/sounds/{sid}/?fields=id,name,license,username,url,previews", HDR)
    if not any(k in s["license"] or k.lower().replace(" ", "") in s["license"] for k in ("publicdomain/zero", "licenses/by/")):
        sys.exit(f"refusing {sid}: license {s['license']}")
    lic = "CC0" if "zero" in s["license"] else "CC-BY"
    out = os.path.join(ROOT, "assets", "audio", "freesound", slug)
    download(s["previews"]["preview-hq-ogg"], os.path.join(out, f"{slug}.ogg"), headers=HDR)
    ledger(f"freesound/{slug}", "Freesound", s["url"], s["username"], lic)
    print("ok", slug, lic, s["username"])

if __name__ == "__main__":
    {"search": lambda *a: search(" ".join(a)), "get": get}[sys.argv[1]](*sys.argv[2:])
