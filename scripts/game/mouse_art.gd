class_name MouseArt
extends RefCounted
## Builds one vertex-coloured, animation-tagged mesh per mouse kind (original chibi designs).
## Every kind has its own silhouette: ears, snout, tail, helmet, wings, belly, lantern...

const A_BODY := 0; const A_FEET_A := 1; const A_FEET_B := 2; const A_TAIL := 3
const A_EARS := 4; const A_WINGS := 5; const A_RIGID := 6

static var _st: SurfaceTool

static func _add(mesh: Mesh, xf: Transform3D, col: Color, tag: int) -> void:
	var arr := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx = arr[Mesh.ARRAY_INDEX]
	var nb := xf.basis.inverse().transposed()
	var order: PackedInt32Array = idx if idx != null and idx.size() > 0 else PackedInt32Array(range(verts.size()))
	for k in order:
		_st.set_color(col)
		_st.set_uv(Vector2(tag, 0))
		_st.set_normal((nb * norms[k]).normalized())
		_st.add_vertex(xf * verts[k])

static func _sph(c: Vector3, r: Vector3, col: Color, tag := A_BODY, rot := Vector3.ZERO) -> void:
	_add(Toon.sphere(1.0, 8, 12), MeshKit.xf(c, r, rot), col, tag)

static func _cone(c: Vector3, r: float, h: float, col: Color, tag := A_BODY, rot := Vector3.ZERO) -> void:
	_add(Toon.cone(r, h, 8), MeshKit.xf(c, Vector3.ONE, rot), col, tag)

static func _box(c: Vector3, s: Vector3, col: Color, tag := A_RIGID, rot := Vector3.ZERO) -> void:
	_add(Toon.box(s), MeshKit.xf(c, Vector3.ONE, rot), col, tag)

static func _cyl(c: Vector3, r: float, h: float, col: Color, tag := A_RIGID, rot := Vector3.ZERO) -> void:
	_add(Toon.cyl(r, r, h, 12), MeshKit.xf(c, Vector3.ONE, rot), col, tag)

## Common chibi mouse. opts: fur, belly, ear_scale, eye (Color, alpha<1 glows), snout_len, body (Vector3),
## tail_len, feet (bool), whiskers (bool), teeth (bool), torn_ear (bool), long_legs (bool)
static func _base(o: Dictionary) -> void:
	var fur: Color = o.get("fur", Color(0.75, 0.71, 0.69))
	var belly: Color = o.get("belly", fur.lightened(0.35))
	var pink := Color(0.98, 0.62, 0.7)
	var body: Vector3 = o.get("body", Vector3(0.26, 0.22, 0.32))
	var by: float = body.y + 0.04
	_sph(Vector3(0, by, 0.02), body, fur)
	_sph(Vector3(0, by - 0.05, -0.12), Vector3(body.x * 0.75, body.y * 0.7, body.z * 0.6), belly)
	# head
	var hy := by + body.y * 0.6
	var hz := -body.z * 0.85
	_sph(Vector3(0, hy, hz), Vector3(0.21, 0.19, 0.2), fur)
	var sl: float = o.get("snout_len", 0.0)
	if sl > 0.0:
		_cone(Vector3(0, hy - 0.04, hz - 0.2 - sl * 0.5), 0.09, 0.2 + sl, fur, A_BODY, Vector3(-PI / 2, 0, 0))
		_sph(Vector3(0, hy - 0.04, hz - 0.32 - sl), Vector3(0.04, 0.04, 0.04), pink)
	else:
		_sph(Vector3(0, hy - 0.05, hz - 0.15), Vector3(0.1, 0.08, 0.09), belly)
		_sph(Vector3(0, hy - 0.02, hz - 0.24), Vector3(0.04, 0.035, 0.035), pink)
	var es: float = o.get("ear_scale", 1.0)
	for sx in [-1.0, 1.0]:
		var ear_s: float = es * (0.6 if o.get("torn_ear", false) and sx > 0 else 1.0)
		_sph(Vector3(0.15 * sx, hy + 0.17, hz + 0.02), Vector3(0.14, 0.14, 0.04) * ear_s, fur, A_EARS)
		_sph(Vector3(0.15 * sx, hy + 0.17, hz - 0.005), Vector3(0.095, 0.095, 0.03) * ear_s, pink, A_EARS)
		var eye: Color = o.get("eye", Color(0.03, 0.03, 0.05))
		_sph(Vector3(0.085 * sx, hy + 0.04, hz - 0.165), Vector3(0.05, 0.062, 0.03), eye)
		_sph(Vector3(0.07 * sx, hy + 0.07, hz - 0.19), Vector3(0.016, 0.016, 0.01), Color(1, 1, 1, 0.6))
		_sph(Vector3(0.14 * sx, hy - 0.04, hz - 0.13), Vector3(0.035, 0.022, 0.015), Color(1.0, 0.55, 0.62))   # blush
		if o.get("whiskers", true):
			for k in 2:
				_box(Vector3(0.16 * sx, hy - 0.03 + 0.03 * k, hz - 0.2), Vector3(0.2, 0.008, 0.008), Color(0.95, 0.95, 0.95), A_BODY, Vector3(0, 0, (0.15 - 0.3 * k) * sx))
	if o.get("teeth", false):
		_box(Vector3(0, hy - 0.11, hz - 0.2), Vector3(0.06, 0.05, 0.02), Color(1.0, 0.97, 0.85), A_BODY)
	# feet
	if o.get("feet", true):
		var long: bool = o.get("long_legs", false)
		for p in [[Vector3(-0.13, 0.05, -0.15), A_FEET_A], [Vector3(0.13, 0.05, -0.15), A_FEET_B],
				[Vector3(-0.14, 0.05, 0.2), A_FEET_B], [Vector3(0.14, 0.05, 0.2), A_FEET_A]]:
			var back: bool = p[0].z > 0
			var fs := Vector3(0.06, 0.045, 0.1) * (Vector3(1.2, 1.0, 2.2) if long and back else Vector3.ONE)
			_sph(p[0], fs, pink, p[1])
	# tail: curling chain of beads
	var tl: float = o.get("tail_len", 1.0)
	for j in 9:
		var z := body.z + 0.02 + j * 0.07 * tl
		_sph(Vector3(0, 0.1 + j * 0.035 + sin(j * 0.6) * 0.03, z), Vector3(0.028, 0.028, 0.05) * (1.0 - j * 0.05), pink, A_TAIL)

static func build(kind: int) -> ArrayMesh:
	_st = SurfaceTool.new()
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var red_eye := Color(1.0, 0.18, 0.12, 0.25)
	match kind:
		MiceSwarm.Kind.NHAT:
			_base({"fur": Color(0.76, 0.72, 0.7), "ear_scale": 1.25})
		MiceSwarm.Kind.CONG:
			_base({"fur": Color(0.42, 0.34, 0.29), "belly": Color(0.62, 0.52, 0.45), "eye": red_eye, "teeth": true, "torn_ear": true, "body": Vector3(0.3, 0.24, 0.36), "tail_len": 1.3})
			_box(Vector3(-0.1, 0.52, -0.38), Vector3(0.12, 0.02, 0.02), Color(0.75, 0.45, 0.45), A_BODY, Vector3(0, 0, 0.6))   # scar
		MiceSwarm.Kind.VANG:
			_base({"fur": Color(1.0, 0.8, 0.28, 0.75), "belly": Color(1.0, 0.92, 0.6, 0.8), "ear_scale": 1.2})
			for k in 3:   # little floating sparkles
				_sph(Vector3(cos(k * 2.1) * 0.3, 0.75 + k * 0.05, sin(k * 2.1) * 0.3 - 0.1), Vector3(0.03, 0.03, 0.03), Color(1, 1, 0.8, 0.0), A_EARS)
		MiceSwarm.Kind.MA:
			_base({"fur": Color(0.55, 0.95, 1.0, 0.45), "belly": Color(0.8, 1.0, 1.0, 0.4), "eye": Color(0.05, 0.2, 0.3, 0.7), "feet": false, "tail_len": 0.6, "whiskers": false})
			_cone(Vector3(0, 0.12, 0.32), 0.2, 0.5, Color(0.55, 0.95, 1.0, 0.4), A_TAIL, Vector3(PI / 2 + 0.3, 0, 0))   # wispy tail
		MiceSwarm.Kind.CHU:
			_base({"fur": Color(0.5, 0.42, 0.55), "belly": Color(0.65, 0.58, 0.7), "snout_len": 0.22, "ear_scale": 0.6, "eye": red_eye, "body": Vector3(0.28, 0.2, 0.36)})
			for k in 3:   # stink curls
				_sph(Vector3(-0.1 + k * 0.1, 0.62 + k * 0.08, 0.25), Vector3(0.06, 0.06, 0.06), Color(0.6, 0.85, 0.35, 0.5), A_EARS)
		MiceSwarm.Kind.LINH:
			_base({"fur": Color(0.6, 0.55, 0.52), "eye": red_eye, "body": Vector3(0.28, 0.23, 0.33)})
			_sph(Vector3(0, 0.66, -0.3), Vector3(0.24, 0.13, 0.24), Color(0.75, 0.55, 0.25), A_RIGID)   # nồi đồng helmet
			_cyl(Vector3(0, 0.6, -0.3), 0.25, 0.03, Color(0.6, 0.42, 0.2), A_RIGID)
			_cyl(Vector3(0.18, 0.32, -0.5), 0.22, 0.04, Color(0.7, 0.58, 0.35), A_RIGID, Vector3(PI / 2, 0, 0))   # woven shield
			_cyl(Vector3(0.18, 0.32, -0.53), 0.08, 0.02, Color(0.85, 0.2, 0.15), A_RIGID, Vector3(PI / 2, 0, 0))
		MiceSwarm.Kind.NHAY:
			_base({"fur": Color(0.85, 0.6, 0.38), "belly": Color(1.0, 0.88, 0.72), "ear_scale": 1.5, "long_legs": true, "eye": red_eye, "tail_len": 1.5})
		MiceSwarm.Kind.BEO:
			_base({"fur": Color(0.88, 0.7, 0.72), "belly": Color(1.0, 0.88, 0.88), "body": Vector3(0.42, 0.36, 0.42), "ear_scale": 0.9})
		MiceSwarm.Kind.DOI:
			_base({"fur": Color(0.28, 0.24, 0.32), "belly": Color(0.45, 0.4, 0.5), "eye": red_eye, "ear_scale": 1.3, "feet": false})
			for sx in [-1.0, 1.0]:
				_sph(Vector3(0.45 * sx, 0.35, 0.0), Vector3(0.38, 0.03, 0.22), Color(0.22, 0.18, 0.28), A_WINGS)
				_cone(Vector3(0.7 * sx, 0.35, 0.12), 0.08, 0.25, Color(0.22, 0.18, 0.28), A_WINGS, Vector3(PI / 2, 0, 0))
		MiceSwarm.Kind.DEN:
			_base({"fur": Color(0.7, 0.66, 0.6)})
			_cyl(Vector3(0.22, 0.6, -0.25), 0.012, 0.8, Color(0.45, 0.3, 0.18), A_RIGID, Vector3(0.3, 0, 0))   # stick
			_sph(Vector3(0.22, 1.0, -0.4), Vector3(0.17, 0.22, 0.17), Color(1.0, 0.25, 0.15, 0.3), A_EARS)    # red paper lantern
			_cyl(Vector3(0.22, 1.24, -0.4), 0.08, 0.05, Color(0.95, 0.75, 0.3, 0.5), A_EARS)
		MiceSwarm.Kind.TUONG:
			_base({"fur": Color(0.36, 0.3, 0.28), "eye": red_eye, "teeth": true, "body": Vector3(0.32, 0.27, 0.38), "tail_len": 1.4})
			_sph(Vector3(0, 0.42, 0.0), Vector3(0.34, 0.2, 0.3), Color(0.8, 0.62, 0.25), A_RIGID)   # gold breastplate
			_box(Vector3(0, 0.66, -0.36), Vector3(0.44, 0.07, 0.1), Color(0.85, 0.15, 0.12), A_RIGID)   # red headband
			_box(Vector3(0.22, 0.6, -0.22), Vector3(0.05, 0.25, 0.06), Color(0.85, 0.15, 0.12), A_RIGID, Vector3(0.4, 0, 0.3))
			_box(Vector3(0, 0.55, 0.34), Vector3(0.5, 0.04, 0.4), Color(0.6, 0.08, 0.1), A_RIGID, Vector3(-0.5, 0, 0))   # cape

	return _st.commit()
