"""Release tool: full builds once, then tiny patch packs for the in-game updater (F9).
  python3 tools/release.py base            # export full Win+Linux builds for game/version_base
  python3 tools/release.py patch "notes"   # export a diff pack vs base + earlier patches
  python3 tools/release.py publish         # upload to GitHub release "updates" (needs gh auth)
State lives in build/release/ (manifest.json, base.pck, patch-*.pck); base.pck is also uploaded
so a fresh machine can rebuild patches: python3 tools/release.py fetch
"""
import hashlib, json, os, re, shutil, subprocess, sys, tarfile, zipfile
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
REL = os.path.join(ROOT, "build", "release")
MAN = os.path.join(REL, "manifest.json")
REPO = "danielnguyen2003/moi-ban-ra-day"
TAG = "updates"
GODOT = os.environ.get("GODOT", "godot")

def base_id():
    m = re.search(r'version_base="([^"]+)"', open(os.path.join(ROOT, "project.godot"), encoding="utf-8").read())
    return m.group(1)

def sha(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()

def run(*a):
    print("+", " ".join(a)); subprocess.run(a, cwd=ROOT, check=True)

def load():
    return json.load(open(MAN)) if os.path.exists(MAN) else None

def save(m):
    json.dump(m, open(MAN, "w"), indent=2, ensure_ascii=False)

def base():
    bid = base_id()
    shutil.rmtree(REL, ignore_errors=True); os.makedirs(REL)
    w = os.path.join(ROOT, "build", "windows"); l = os.path.join(ROOT, "build", "linux")
    for d in (w, l):
        shutil.rmtree(d, ignore_errors=True); os.makedirs(d)
    run(GODOT, "--headless", "--export-release", "Windows", "build/windows/MoiBanRaDay.exe")
    run(GODOT, "--headless", "--export-release", "Linux", "build/linux/MoiBanRaDay.x86_64")
    shutil.copy(os.path.join(l, "MoiBanRaDay.pck"), os.path.join(REL, "base.pck"))
    wz = f"MoiBanRaDay-{bid}-windows-x86_64.zip"; lz = f"MoiBanRaDay-{bid}-linux-x86_64.tar.gz"
    with zipfile.ZipFile(os.path.join(REL, wz), "w", zipfile.ZIP_DEFLATED) as z:
        for f in os.listdir(w):
            z.write(os.path.join(w, f), f"MoiBanRaDay/{f}")
    with tarfile.open(os.path.join(REL, lz), "w:gz") as t:
        t.add(l, "MoiBanRaDay")
    save({"base": bid, "full": {"windows": wz, "linux": lz}, "base_pck": "base.pck",
          "base_sha256": sha(os.path.join(REL, "base.pck")), "patches": []})
    print("base", bid, "ready in", REL)

def patch(notes=""):
    m = load()
    assert m and m["base"] == base_id(), "run `base` first (or `fetch`) for " + base_id()
    n = len(m["patches"]) + 1
    name = f"patch-{n:04d}.pck"
    prev = [os.path.join(REL, "base.pck")] + [os.path.join(REL, p["file"]) for p in m["patches"]]
    run(GODOT, "--headless", "--export-patch", "Linux", os.path.join(REL, name), "--patches", ",".join(prev))
    p = os.path.join(REL, name)
    m["patches"].append({"id": f"p{n}", "file": name, "sha256": sha(p), "size": os.path.getsize(p), "notes": notes})
    save(m)
    print(f"{name}: {os.path.getsize(p) / 1024:.1f} KB")

def publish():
    m = load()
    files = [MAN, os.path.join(REL, "base.pck")] + [os.path.join(REL, p["file"]) for p in m["patches"]]
    files += [os.path.join(REL, f) for f in m["full"].values()]
    if subprocess.run(["gh", "release", "view", TAG, "-R", REPO], capture_output=True).returncode != 0:
        run("gh", "release", "create", TAG, "-R", REPO, "--title", "Bản cập nhật (Updates)",
            "--notes", "Tải bản đầy đủ một lần; sau đó bấm F9 trong game để nhận bản vá.", "--latest")
    run("gh", "release", "upload", TAG, "-R", REPO, "--clobber", *[f for f in files if os.path.exists(f)])

def fetch():
    os.makedirs(REL, exist_ok=True)
    run("gh", "release", "download", TAG, "-R", REPO, "-D", REL, "--clobber", "-p", "manifest.json", "-p", "base.pck", "-p", "patch-*.pck")

if __name__ == "__main__":
    {"base": base, "patch": patch, "publish": publish, "fetch": fetch}[sys.argv[1]](*sys.argv[2:])
