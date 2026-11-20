class_name PlantKit
extends RefCounted
## Procedural plants made of real leaf geometry (folded, tapering, drooping strips with a midrib),
## baked to vertex-coloured meshes for MultiMesh. Original stylised designs of plants of the
## northern Vietnamese countryside: lúa, cỏ, lau sậy, chuối, cau, tre, đa.

static var _st: SurfaceTool
static var _rng := RandomNumberGenerator.new()

static func _begin() -> void:
	_st = SurfaceTool.new()
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)

static func _end() -> ArrayMesh:
	_st.generate_normals()
	return _st.commit()

static func _tri(a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	_st.set_color(ca); _st.add_vertex(a)
	_st.set_color(cb); _st.add_vertex(b)
	_st.set_color(cc); _st.add_vertex(c)

## One leaf: starts at `xf.origin`, grows along local +Z, droops along -Y.
## fold > 0 lifts the midrib (V-shaped leaf), width_pow shapes the outline, tear adds banana splits.
static func leaf(xf: Transform3D, length: float, width: float, droop: float, base: Color, tip: Color,
		segs := 8, fold := 0.15, width_pow := 0.6, tear := 0.0) -> void:
	var prev := []
	for k in segs + 1:
		var u := float(k) / segs
		var w := width * pow(sin(clampf(u * 1.08, 0.0, 1.0) * PI), width_pow) * (1.0 - u * 0.15)
		var z := u * length
		var y := -droop * u * u * length
		var mid := Vector3(0, y + fold * w, z)
		var l := Vector3(-w, y, z)
		var r := Vector3(w, y, z)
		var col := base.lerp(tip, u)
		var row := [xf * l, xf * mid, xf * r, col]
		if k > 0:
			var torn := tear > 0.0 and _rng.randf() < tear
			if not torn:
				_tri(prev[0], prev[1], row[1], prev[3], prev[3].lightened(0.06), row[3].lightened(0.06))
				_tri(prev[0], row[1], row[0], prev[3], row[3].lightened(0.06), row[3])
			if not (tear > 0.0 and _rng.randf() < tear):
				_tri(prev[1], prev[2], row[2], prev[3].lightened(0.06), prev[3], row[3])
				_tri(prev[1], row[2], row[1], prev[3].lightened(0.06), row[3], row[3].lightened(0.06))
		prev = row
	return

## Tapered tube along +Y from y0 to y1 with optional gentle curve; node rings for bamboo.
static func stem(base: Vector3, height: float, r0: float, r1: float, c0: Color, c1: Color, curve := Vector3.ZERO, segs := 6, sides := 6, rings := 0, ring_col := Color()) -> void:
	for k in segs:
		var u0 := float(k) / segs; var u1 := float(k + 1) / segs
		var p0 := base + Vector3(0, height * u0, 0) + curve * u0 * u0
		var p1 := base + Vector3(0, height * u1, 0) + curve * u1 * u1
		var ra := lerpf(r0, r1, u0); var rb := lerpf(r0, r1, u1)
		var ca := c0.lerp(c1, u0); var cb := c0.lerp(c1, u1)
		if rings > 0:
			var band := fmod(u1 * rings, 1.0) < 1.0 / segs * rings
			if band: cb = ring_col
		for s in sides:
			var a0 := TAU * s / sides; var a1 := TAU * (s + 1) / sides
			var d0 := Vector3(cos(a0), 0, sin(a0)); var d1 := Vector3(cos(a1), 0, sin(a1))
			_tri(p0 + d0 * ra, p1 + d0 * rb, p1 + d1 * rb, ca, cb, cb)
			_tri(p0 + d0 * ra, p1 + d1 * rb, p0 + d1 * ra, ca, cb, ca)

static func _xf(pos: Vector3, yaw: float, pitch: float, roll := 0.0) -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(pitch, yaw, roll), EULER_ORDER_YXZ), pos)

# ================================================================== plants
static func grass_clump(seed_: int) -> ArrayMesh:
	_rng.seed = seed_; _begin()
	for k in 6:
		var yaw := _rng.randf() * TAU
		_st_leaf_up(Vector3(_rng.randf_range(-0.1, 0.1), 0, _rng.randf_range(-0.1, 0.1)), yaw, _rng.randf_range(0.4, 0.85), 0.05,
			Color(0.1, 0.2, 0.13), Color(0.3, 0.46, 0.27).lerp(Color(0.45, 0.5, 0.28), _rng.randf()))
	return _end()

## Blade that rises then arches over (for grass, rice, reeds).
static func _st_leaf_up(at: Vector3, yaw: float, length: float, width: float, c0: Color, c1: Color, arch := 0.9) -> void:
	leaf(_xf(at, yaw, -PI / 2 + _rng.randf_range(0.15, 0.45)), length, width, arch * _rng.randf_range(0.4, 1.0), c0, c1, 6, 0.0, 0.4)

static func rice_clump(seed_: int) -> ArrayMesh:
	_rng.seed = seed_; _begin()
	for k in 8:
		_st_leaf_up(Vector3(_rng.randf_range(-0.08, 0.08), 0, _rng.randf_range(-0.08, 0.08)), _rng.randf() * TAU, _rng.randf_range(0.7, 1.05), 0.045,
			Color(0.16, 0.3, 0.16), Color(0.55, 0.62, 0.3), 1.1)
	for k in 3:   # golden panicles nodding over
		var yaw := _rng.randf() * TAU
		leaf(_xf(Vector3(0, 0.8, 0), yaw, -0.5), 0.45, 0.05, 1.6, Color(0.75, 0.66, 0.3), Color(0.95, 0.82, 0.45), 6, 0.05, 0.9)
	return _end()

static func reed_clump(seed_: int) -> ArrayMesh:
	_rng.seed = seed_; _begin()
	for k in 5:
		var p := Vector3(_rng.randf_range(-0.2, 0.2), 0, _rng.randf_range(-0.2, 0.2))
		var h := _rng.randf_range(1.4, 2.0)
		stem(p, h, 0.025, 0.015, Color(0.3, 0.38, 0.22), Color(0.45, 0.5, 0.3), Vector3(_rng.randf_range(-0.15, 0.15), 0, 0.1), 4, 4)
		stem(p + Vector3(0, h, 0), 0.32, 0.05, 0.03, Color(0.42, 0.28, 0.18), Color(0.5, 0.34, 0.22), Vector3.ZERO, 2, 6)
		_st_leaf_up(p, _rng.randf() * TAU, h * 0.8, 0.04, Color(0.2, 0.3, 0.18), Color(0.45, 0.52, 0.3), 0.7)
	return _end()

static func banana(seed_: int) -> ArrayMesh:
	_rng.seed = seed_; _begin()
	var h := _rng.randf_range(2.4, 3.2)
	stem(Vector3.ZERO, h, 0.24, 0.17, Color(0.35, 0.42, 0.22), Color(0.48, 0.58, 0.32), Vector3(0, 0, 0), 5, 10)
	var n := 8
	for k in n:
		var yaw := k * TAU / n + _rng.randf_range(-0.3, 0.3)
		var age := float(k) / n   # older leaves droop more and are torn
		var pitch := lerpf(-1.05, -0.2, age)
		leaf(_xf(Vector3(0, h - 0.1, 0), yaw, pitch), _rng.randf_range(2.0, 2.7), _rng.randf_range(0.45, 0.6), lerpf(0.25, 0.75, age),
			Color(0.16, 0.36, 0.2), Color(0.32, 0.56, 0.3).lerp(Color(0.5, 0.55, 0.3), age * 0.6), 10, 0.12, 0.35, age * 0.25)
	if _rng.randf() < 0.6:   # buồng chuối + bắp chuối
		stem(Vector3(0.2, h - 0.6, 0), 0.6, 0.12, 0.1, Color(0.55, 0.62, 0.3), Color(0.6, 0.66, 0.32), Vector3(0.2, -0.2, 0), 3, 8)
		stem(Vector3(0.35, h - 0.8, 0), -0.4, 0.13, 0.02, Color(0.45, 0.16, 0.3), Color(0.55, 0.2, 0.35), Vector3.ZERO, 3, 8)
	return _end()

static func areca(seed_: int) -> ArrayMesh:
	_rng.seed = seed_; _begin()
	var h := _rng.randf_range(7.0, 9.5)
	var bend := Vector3(_rng.randf_range(-0.6, 0.6), 0, _rng.randf_range(-0.6, 0.6))
	stem(Vector3.ZERO, h, 0.17, 0.12, Color(0.42, 0.4, 0.34), Color(0.55, 0.53, 0.45), bend, 10, 7, 14, Color(0.33, 0.31, 0.27))
	var top := Vector3(0, h, 0) + bend
	stem(top - Vector3(0, 0.6, 0), 0.8, 0.16, 0.12, Color(0.3, 0.45, 0.25), Color(0.35, 0.5, 0.28), Vector3.ZERO, 2, 7)   # crownshaft
	for k in 9:
		var yaw := k * TAU / 9.0 + _rng.randf_range(-0.2, 0.2)
		var pitch := _rng.randf_range(-0.6, 0.1)
		var fl := _rng.randf_range(2.2, 3.0)
		var fx := _xf(top, yaw, pitch)
		# rachis + leaflets on both sides
		leaf(fx, fl, 0.03, 0.55, Color(0.3, 0.38, 0.2), Color(0.35, 0.42, 0.22), 8, 0.0, 0.2)
		for j in 12:
			var u := 0.12 + j * 0.07
			var z := u * fl
			var y := -0.55 * u * u * fl
			for side in [-1.0, 1.0]:
				var lx := fx * Vector3(0, y, z)
				var d := fx.basis * Vector3(side, -0.25, 0.35).normalized()
				var lb := Basis.looking_at(-d, Vector3.UP)
				leaf(Transform3D(lb, lx), lerpf(0.75, 0.35, u), 0.07, 0.4, Color(0.13, 0.3, 0.18), Color(0.28, 0.47, 0.26), 4, 0.02, 0.5)
	return _end()

static func bamboo_clump(seed_: int) -> ArrayMesh:
	_rng.seed = seed_; _begin()
	for k in 7:
		var p := Vector3(_rng.randf_range(-0.9, 0.9), 0, _rng.randf_range(-0.9, 0.9))
		var h := _rng.randf_range(6.0, 10.0)
		var lean := Vector3(_rng.randf_range(-1.2, 1.2), 0, _rng.randf_range(-1.2, 1.2)) + p * 0.8
		stem(p, h, 0.09, 0.06, Color(0.3, 0.4, 0.22), Color(0.45, 0.55, 0.3), lean, 12, 6, 9, Color(0.55, 0.58, 0.35))
		# leafy twigs on the upper half: fans of slim lanceolate leaves
		for b in 6:
			var u := _rng.randf_range(0.45, 0.98)
			var at := p + Vector3(0, h * u, 0) + lean * u * u
			var yaw := _rng.randf() * TAU
			for f in 6:
				leaf(_xf(at, yaw + _rng.randf_range(-0.7, 0.7), _rng.randf_range(-0.2, 0.5)), _rng.randf_range(0.45, 0.7), 0.06, 0.9,
					Color(0.12, 0.28, 0.17), Color(0.3, 0.5, 0.28).lerp(Color(0.45, 0.5, 0.25), _rng.randf() * 0.4), 5, 0.02, 0.5)
	return _end()

## Leaf cluster for broad-leaf canopies (banyan, gạo): a puff of small leaves around a centre.
static func leaf_cluster(seed_: int, c0: Color, c1: Color) -> ArrayMesh:
	_rng.seed = seed_; _begin()
	for k in 22:
		var d := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.4, 1), _rng.randf_range(-1, 1)).normalized()
		var at := d * _rng.randf_range(0.2, 0.7)
		var b := Basis.looking_at(-d, Vector3.UP) if absf(d.y) < 0.95 else Basis()
		leaf(Transform3D(b, at), _rng.randf_range(0.45, 0.65), 0.17, 0.3, c0, c1.lerp(c0, _rng.randf() * 0.4), 4, 0.05, 0.7)
	return _end()
