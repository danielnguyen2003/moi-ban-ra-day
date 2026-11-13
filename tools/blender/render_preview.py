"""Import a glTF/GLB, report rig/animation stats, render a moody preview (oil-lamp key, moonlight rim).
usage: blender -b -P tools/blender/render_preview.py -- <model> <out.png> [frame]
"""
import bpy, sys, math, mathutils
argv = sys.argv[sys.argv.index("--") + 1:]
src, out = argv[0], argv[1]
frame = int(argv[2]) if len(argv) > 2 else None

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
sc = bpy.context.scene
for o in list(sc.objects):
    if o.type == "MESH" and o.parent is None and o.name.startswith("Icosphere"):
        bpy.data.objects.remove(o, do_unlink=True)  # glTF importer's bone display shape
meshes = [o for o in sc.objects if o.type == "MESH"]
arms = [o for o in sc.objects if o.type == "ARMATURE"]
print("STATS meshes=%d tris=%d armatures=%s bones=%s actions=%s" % (
    len(meshes), sum(len(m.data.polygons) for m in meshes),
    [a.name for a in arms], [len(a.data.bones) for a in arms],
    [(a.name, round(a.frame_range[1] - a.frame_range[0])) for a in bpy.data.actions]))
if frame is not None:
    sc.frame_set(frame)
bpy.context.view_layer.update()

# world-space bounds of evaluated meshes
dg = bpy.context.evaluated_depsgraph_get()
pts = []
for o in meshes:
    ev = o.evaluated_get(dg)
    pts += [ev.matrix_world @ v.co for v in ev.to_mesh().vertices]
mn = mathutils.Vector([min(p[i] for p in pts) for i in range(3)])
mx = mathutils.Vector([max(p[i] for p in pts) for i in range(3)])
size = mx - mn; ctr = (mn + mx) / 2
print("BOUNDS size=%s" % [round(s, 3) for s in size])
r = max(size) or 1

# floor: dark earthen ground
bpy.ops.mesh.primitive_plane_add(size=r * 8, location=(ctr.x, ctr.y, mn.z))
fl = bpy.context.object; mat = bpy.data.materials.new("floor"); mat.use_nodes = True
mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.06, 0.045, 0.035, 1)
mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.9
fl.data.materials.append(mat)

def light(kind, loc, energy, color, size=0.05):
    d = bpy.data.lights.new(kind, kind); d.energy = energy; d.color = color
    if kind == "POINT": d.shadow_soft_size = size * r
    o = bpy.data.objects.new(kind, d); o.location = loc; sc.collection.objects.link(o); return o
light("POINT", ctr + mathutils.Vector((r * 0.9, -r * 0.8, r * 0.5)), 80 * r * r, (1.0, 0.55, 0.22))   # oil lamp ~1800K
sun = light("SUN", (0, 0, 0), 0.4, (0.55, 0.65, 1.0))                                                 # moonlight
sun.rotation_euler = (math.radians(55), 0, math.radians(150))

cam_d = bpy.data.cameras.new("cam"); cam_d.lens = 50
cam = bpy.data.objects.new("cam", cam_d); sc.collection.objects.link(cam); sc.camera = cam
cam.location = ctr + mathutils.Vector((r * 1.3, -r * 1.9, r * 0.35))
cam.rotation_euler = (ctr - cam.location).to_track_quat("-Z", "Y").to_euler()

sc.world = bpy.data.worlds.new("w"); sc.world.color = (0.003, 0.003, 0.005)
sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = 48; sc.cycles.use_denoising = True
sc.render.resolution_x, sc.render.resolution_y = 640, 400
sc.view_settings.view_transform = "AgX"
sc.render.filepath = out
bpy.ops.render.render(write_still=True)
print("RENDERED", out)
