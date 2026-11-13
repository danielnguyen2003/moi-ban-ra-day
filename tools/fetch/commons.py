"""Download audio/images from Wikimedia Commons after checking the license (CC0 / PD / CC BY / CC BY-SA).
BY-SA files are kept unmodified-or-shared-alike and credited in docs/CREDITS.md.
usage: python3 tools/fetch/commons.py "File:Some name.ogg" <slug> [audio|refs]
"""
import os, re, sys, urllib.parse
sys.path.insert(0, os.path.dirname(__file__))
from common import ROOT, get_json, download, ledger

API = "https://commons.wikimedia.org/w/api.php"

def main(title, slug, kind="audio"):
    q = f"{API}?action=query&format=json&prop=imageinfo&iiprop=url|extmetadata&titles={urllib.parse.quote(title)}"
    page = next(iter(get_json(q)["query"]["pages"].values()))
    ii = page["imageinfo"][0]; meta = ii["extmetadata"]
    lic = meta.get("LicenseShortName", {}).get("value", "")
    if not re.search(r"CC0|Public domain|^CC BY(-SA)? [0-9.]+$|^CC BY(-SA)?$", lic, re.I):  # BY-SA: file stays BY-SA, credited
        sys.exit(f"refusing {title}: license {lic!r}")
    artist = re.sub("<[^>]+>", "", meta.get("Artist", {}).get("value", "unknown")).strip()
    ext = os.path.splitext(ii["url"])[1].lower()
    sub = ("audio", "commons") if kind == "audio" else ("refs", "_cache")
    out = os.path.join(ROOT, "assets", *sub, slug) if kind == "audio" else os.path.join(ROOT, "refs", "_cache", slug)
    download(ii["url"], os.path.join(out, slug + ext))
    if kind == "audio":
        ledger(f"commons/{slug}", "Wikimedia Commons", ii["descriptionurl"], artist[:80], lic)
    print("ok", slug, "|", lic, "|", artist[:50])

if __name__ == "__main__":
    main(*sys.argv[1:])
