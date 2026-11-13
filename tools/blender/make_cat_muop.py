"""Turn the CC-BY orange 'cat Walk' model into a grey-brown mèo mướp and clean it up.
- deletes the stray 2 m Icosphere and empty lamps shipped in the source
- re-tints the orange fur (hue 10–50°) toward brown-grey tabby, deepens stripes; eyes untouched
usage: blender -b -P tools/blender/make_cat_muop.py -- <in.glb> <out.glb>
"""
import bpy, sys, numpy as np, colorsys
argv = sys.argv[sys.argv.index("--") + 1:]
src, dst = argv
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
for o in list(bpy.data.objects):
    if o.name.startswith("Icosphere") or o.name.startswith("Lamp"):
        bpy.data.objects.remove(o, do_unlink=True)

def retint(img):
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    rgb = px[..., :3]
    mx, mn = rgb.max(-1), rgb.min(-1)
    v = mx; d = mx - mn
    s = np.where(mx > 1e-5, d / np.maximum(mx, 1e-5), 0)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    hue = np.zeros_like(v)
    m = d > 1e-5
    hr = np.where(mx == r, ((g - b) / np.where(m, d, 1)) % 6, 0)
    hg = np.where(mx == g, (b - r) / np.where(m, d, 1) + 2, 0)
    hb = np.where(mx == b, (r - g) / np.where(m, d, 1) + 4, 0)
    hue = np.where(mx == r, hr, np.where(mx == g, hg, hb)) * 60.0
    # Protect the eyeball (bottom-right of the atlas in Blender's bottom-up pixel order).
    yy, xx = np.mgrid[0:h, 0:w]
    eye = (xx > w * 0.74) & (yy < h * 0.16)
    orange = (hue > 8) & (hue < 52) & (s > 0.12) & ~eye
    # Target: warm grey-brown (hue ~30°, sat 0.18), darker mid-tones so stripes read as black-brown.
    s2 = np.where(orange, s * 0.32, s)
    v2 = np.where(orange, np.clip(v ** 1.35 * 0.92, 0, 1), v)
    h2 = np.where(orange, 30.0, hue)
    # HSV -> RGB
    c = v2 * s2; x = c * (1 - np.abs((h2 / 60.0) % 2 - 1)); m0 = v2 - c
    hi = (h2 // 60).astype(int) % 6
    out = np.zeros_like(rgb)
    for i, (a, bb, cc) in enumerate([(c, x, 0), (x, c, 0), (0, c, x), (0, x, c), (x, 0, c), (c, 0, x)]):
        sel = hi == i
        for ch, val in enumerate((a, bb, cc)):
            out[..., ch] = np.where(sel, (val if np.ndim(val) else np.full_like(v2, val)) + m0, out[..., ch])
    px[..., :3] = np.where(orange[..., None], out, rgb)
    img.pixels[:] = px.ravel()
    img.update()

for im in bpy.data.images:
    if im.size[0] > 0:
        retint(im)
        im.pack()
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_animations=True, export_image_format="AUTO")
print("WROTE", dst)
