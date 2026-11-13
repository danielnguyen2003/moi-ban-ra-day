"""Release tool: full builds once, then tiny patch packs for the in-game updater (F9).
  python3 tools/release.py base            # export full Win+Linux builds for game/version_base
  python3 tools/release.py patch "notes"   # export a diff pack vs base + earlier patches
  python3 tools/release.py publish         # copy manifest + patches to updates/ and git push
  python3 tools/release.py fetch           # fresh machine: restore build/release from updates/ + base commit
`base` must run on a clean, committed tree: the manifest records HEAD as base_commit.
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
    commit = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, capture_output=True, text=True).stdout.strip()
    save({"base": bid, "base_commit": commit, "full": {"windows": wz, "linux": lz}, "base_pck": "base.pck",
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

UPD = os.path.join(ROOT, "updates")   # committed: manifest.json + patch-*.pck, served by raw.githubusercontent.com

def publish():
    """Copy manifest + patches into updates/ and push. Full builds are handed out once, outside git."""
    m = load()
    os.makedirs(UPD, exist_ok=True)
    shutil.copy(MAN, os.path.join(UPD, "manifest.json"))
    for p in m["patches"]:
        shutil.copy(os.path.join(REL, p["file"]), os.path.join(UPD, p["file"]))
    run("git", "add", "updates")
    msg = f"Publish updates for {m['base']}: {len(m['patches'])} patch(es)"
    if subprocess.run(["git", "diff", "--cached", "--quiet"], cwd=ROOT).returncode != 0:
        run("git", "commit", "-m", msg + "\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>")
    run("git", "-c", "push.negotiate=true", "push", "origin", "HEAD:main")

def fetch():
    """Rebuild build/release/ on a fresh machine: re-export base.pck from the recorded base commit."""
    m = json.load(open(os.path.join(UPD, "manifest.json")))
    os.makedirs(REL, exist_ok=True)
    shutil.copy(os.path.join(UPD, "manifest.json"), MAN)
    for p in m["patches"]:
        shutil.copy(os.path.join(UPD, p["file"]), os.path.join(REL, p["file"]))
    wt = os.path.join(ROOT, "build", "base_worktree")
    shutil.rmtree(wt, ignore_errors=True)
    run("git", "worktree", "add", "--force", wt, m["base_commit"])
    subprocess.run([GODOT, "--headless", "--import"], cwd=wt)
    subprocess.run([GODOT, "--headless", "--export-pack", "Linux", os.path.join(REL, "base.pck")], cwd=wt, check=True)
    run("git", "worktree", "remove", "--force", wt)

if __name__ == "__main__":
    {"base": base, "patch": patch, "publish": publish, "fetch": fetch}[sys.argv[1]](*sys.argv[2:])
