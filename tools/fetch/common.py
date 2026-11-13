"""Shared helpers: download with md5 check and append to docs/ASSET_LEDGER.csv."""
import csv, hashlib, json, os, sys, time, urllib.error, urllib.request
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
LEDGER = os.path.join(ROOT, "docs", "ASSET_LEDGER.csv")
UA = {"User-Agent": "IndieGameAssetFetcher/0.2 (non-commercial prototype tooling; python-urllib)"}

def get_json(url, headers=None):
    req = urllib.request.Request(url, headers={**UA, **(headers or {})})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)

def download(url, dest, md5=None, headers=None):
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    if os.path.exists(dest) and (md5 is None or _md5(dest) == md5):
        return dest
    req = urllib.request.Request(url, headers={**UA, **(headers or {})})
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=600) as r, open(dest + ".part", "wb") as f:
                while chunk := r.read(1 << 20):
                    f.write(chunk)
            break
        except urllib.error.HTTPError as e:
            if e.code != 429 or attempt == 4:
                raise
            time.sleep(int(e.headers.get("Retry-After", "0") or 0) or 10 * (attempt + 1))
    os.replace(dest + ".part", dest)
    if md5 and _md5(dest) != md5:
        sys.exit(f"md5 mismatch: {dest}")
    return dest

def _md5(p):
    h = hashlib.md5()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()

def ledger(name, source, url, author, license_, modified="no", used_in=""):
    rows = []
    if os.path.exists(LEDGER):
        with open(LEDGER, newline="", encoding="utf-8") as f:
            rows = list(csv.reader(f))
    header, body = (rows[0], rows[1:]) if rows else (["name","source","url","author","license","modified","used_in"], [])
    body = [r for r in body if r and r[0] != name]
    body.append([name, source, url, author, license_, modified, used_in])
    with open(LEDGER, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f); w.writerow(header); w.writerows(sorted(body))
