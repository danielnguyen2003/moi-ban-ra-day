class_name Village
extends Node3D
## v4 village: 240 × 260 world (≈5× v3) with five districts, roads, paddies, lotus pond,
## sky dome + mountains, and dense MultiMesh foliage. See design/level-village.md.

const GROUND := preload("res://scripts/shaders/ground.gdshader")
const FOLIAGE := preload("res://scripts/shaders/foliage.gdshader")
const SKY := preload("res://scripts/shaders/sky.gdshader")
const FONT := preload("res://assets/fonts/google/bevietnampro/BeVietnamPro-ExtraBold.ttf")

const WORLD := Rect2(-120, -120, 240, 260)
const HOME := Vector3(0, 0, 0)
const FIELDS := Vector3(75, 0, -15)
const POND := Vector3(-78, 0, 5)
const POND_R := Vector2(24, 17)
const DINH := Vector3(0, 0, 82)
const GRAVES := Vector3(0, 0, -92)

var rects: Array[Rect2] = [WORLD]
var unlocked := 1
var obstacles: Array = []            ## [center, radius]
var _holes: Array[Vector3] = []
var _wisps: Array[Node3D] = []
var _flames: Array[OmniLight3D] = []
var _no_grass: Array = []            ## [center, radius] areas kept clear of foliage
var _paths: Array = []               ## [a, b, width]
var _foliage_mat: ShaderMaterial

func build(_areas := 1) -> void:
	seed(1604)
	_foliage_mat = ShaderMaterial.new(); _foliage_mat.shader = FOLIAGE
	_foliage_mat.set_shader_parameter("emission_from_alpha", 1.0)
	_sky()
	_ground()
	_roads()
	_home()
	_fields()
	_pond()
	_dinh()
	_graves()
	_bamboo_wall()
	_foliage()
	for k in 40:
		_holes.append(Vector3(randf_range(WORLD.position.x + 8, WORLD.end.x - 8), 0, randf_range(WORLD.position.y + 8, WORLD.end.y - 8)))
	randomize()

func set_unlocked(n: int) -> void:
	unlocked = n

func holes() -> Array[Vector3]:
	return _holes

func inside(p: Vector3) -> bool:
	if not WORLD.grow(-3.0).has_point(Vector2(p.x, p.z)):
		return false
	var d := Vector2((p.x - POND.x) / POND_R.x, (p.z - POND.z) / POND_R.y)
	return d.length() > 1.0

func clamp_inside(p: Vector3) -> Vector3:
	var r := WORLD.grow(-3.0)
	var q := Vector3(clampf(p.x, r.position.x, r.end.x), p.y, clampf(p.z, r.position.y, r.end.y))
	var d := Vector2((q.x - POND.x) / POND_R.x, (q.z - POND.z) / POND_R.y)
	if d.length() <= 1.0:
		var n := d.normalized() if d.length() > 0.001 else Vector2(1, 0)
		q.x = POND.x + n.x * POND_R.x * 1.02
		q.z = POND.z + n.y * POND_R.y * 1.02
	return q

func unlocked_bounds() -> Rect2:
	return WORLD

func _process(_dt: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	for i in _wisps.size():
		var w := _wisps[i]
		var base: Vector3 = w.get_meta("base")
		w.position = base + Vector3(sin(t * 0.7 + i) * 1.2, sin(t * 1.3 + i * 2.0) * 0.45, cos(t * 0.5 + i) * 1.2)
	for f in _flames:
		f.light_energy = f.get_meta("e") * (0.85 + 0.15 * sin(t * 9.0 + f.get_instance_id()) + randf() * 0.06)

# ============================================================ basics
func _part(mesh: Mesh, color: Color, pos := Vector3.ZERO, scale := Vector3.ONE, outline := true, extra := {}) -> MeshInstance3D:
	return Toon.part(mesh, color, pos, scale, outline, extra)

func _group(parts: Array) -> Node3D:
	var n := Node3D.new()
	for p in parts: n.add_child(p)
	return n

func _put(node: Node3D, pos: Vector3, rot_y := 0.0, solid_r := 0.0) -> Node3D:
	node.position = pos
	node.rotation.y = rot_y
	add_child(node)
	if solid_r > 0.0:
		_solid(pos, solid_r)
	return node

func _solid(pos: Vector3, r: float) -> void:
	obstacles.append([Vector3(pos.x, 0, pos.z), r])
	_no_grass.append([Vector3(pos.x, 0, pos.z), r + 0.5])
	var sb := StaticBody3D.new(); sb.collision_layer = 1; sb.collision_mask = 0
	var cs := CollisionShape3D.new(); var cy := CylinderShape3D.new(); cy.radius = r; cy.height = 4.0
	cs.shape = cy; cs.position.y = 2.0; sb.add_child(cs)
	sb.position = Vector3(pos.x, 0, pos.z)
	add_child(sb)

func _flat(rect: Rect2, mode: int, a: Color, b: Color, line := Color(0.2, 0.14, 0.16), y := 0.02) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = rect.size
	mi.mesh = pm
	mi.material_override = _ground_mat(mode, a, b, line)
	mi.position = Vector3(rect.get_center().x, y, rect.get_center().y)
	add_child(mi)

func _ground_mat(mode: int, a: Color, b: Color, line := Color(0.2, 0.14, 0.16)) -> ShaderMaterial:
	var m := ShaderMaterial.new(); m.shader = GROUND
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("base_a", a); m.set_shader_parameter("base_b", b); m.set_shader_parameter("line_c", line)
	return m

func _lamp(pos: Vector3, color := Color(1.0, 0.62, 0.28), energy := 2.0, rng := 10.0, shadows := false) -> void:
	var n := Node3D.new()
	var h := 2.6
	n.add_child(_part(Toon.cyl(0.07, 0.1, h, 8), Color(0.5, 0.42, 0.25), Vector3(0, h / 2, 0)))
	n.add_child(_part(Toon.box(Vector3(0.55, 0.06, 0.06)), Color(0.5, 0.42, 0.25), Vector3(0.22, h, 0)))
	var lp := Vector3(0.42, h - 0.3, 0)
	n.add_child(_part(Toon.cyl(0.13, 0.17, 0.08, 12), Color(0.3, 0.27, 0.24), lp + Vector3(0, -0.24, 0)))
	var glass := MeshInstance3D.new(); glass.mesh = Toon.sphere(0.17); glass.scale = Vector3(1, 1.4, 1)
	glass.material_override = Toon.glow(color, 3.5); glass.position = lp
	n.add_child(glass)
	n.add_child(_part(Toon.cyl(0.05, 0.14, 0.1, 12), Color(0.3, 0.27, 0.24), lp + Vector3(0, 0.27, 0)))
	var l := OmniLight3D.new(); l.light_color = color; l.light_energy = energy; l.omni_range = rng
	l.omni_attenuation = 1.3; l.shadow_enabled = shadows; l.position = lp
	l.set_meta("e", energy)
	n.add_child(l); _flames.append(l)
	_put(n, pos, randf() * TAU, 0.25)

func _wisp(pos: Vector3, color := Color(0.45, 0.95, 1.0)) -> void:
	var n := Node3D.new()
	var core := MeshInstance3D.new(); core.mesh = Toon.sphere(0.22); core.material_override = Toon.glow(color, 5.0)
	n.add_child(core)
	var halo := MeshInstance3D.new(); halo.mesh = Toon.sphere(0.55)
	var hm := StandardMaterial3D.new(); hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; hm.albedo_color = Color(color, 0.15)
	halo.material_override = hm; n.add_child(halo)
	var l := OmniLight3D.new(); l.light_color = color; l.light_energy = 1.4; l.omni_range = 6.0; n.add_child(l)
	_put(n, pos)
	n.set_meta("base", n.position)
	_wisps.append(n)

func _label(pos: Vector3, text: String) -> void:
	var l := Label3D.new()
	l.text = text; l.font = FONT; l.font_size = 120; l.outline_size = 30; l.pixel_size = 0.012
	l.modulate = Color(1.0, 0.9, 0.7, 0.75); l.outline_modulate = Color(0.08, 0.05, 0.15, 0.8)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = pos + Vector3(0, 9.0, 0)
	add_child(l)

# ============================================================ sky, ground, roads
func _sky() -> void:
	var dome := MeshInstance3D.new()
	var s := SphereMesh.new(); s.radius = 420.0; s.height = 840.0; s.rings = 24; s.radial_segments = 48
	dome.mesh = s
	var m := ShaderMaterial.new(); m.shader = SKY
	dome.material_override = m
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dome)
	# full moon with a soft halo, low over the far rice fields
	var moon := MeshInstance3D.new(); moon.mesh = Toon.sphere(14.0)
	moon.material_override = Toon.glow(Color(1.0, 0.95, 0.82), 2.2)
	moon.position = Vector3(-120, 120, -330); add_child(moon)
	var halo := MeshInstance3D.new(); halo.mesh = Toon.sphere(40.0)
	var hm := StandardMaterial3D.new(); hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; hm.albedo_color = Color(0.7, 0.75, 1.0, 0.08)
	hm.disable_fog = true
	halo.material_override = hm; halo.position = moon.position; add_child(halo)
	# distant mountains (silhouette ring)
	for k in 30:
		var a := k * TAU / 30.0 + randf() * 0.1
		var dist := randf_range(230.0, 290.0)
		var h := randf_range(35.0, 80.0)
		var mt := MeshInstance3D.new(); mt.mesh = Toon.cone(randf_range(45, 80), h, 7)
		var mm := StandardMaterial3D.new(); mm.albedo_color = Color(0.09, 0.08, 0.17).lerp(Color(0.14, 0.12, 0.25), randf())
		mm.roughness = 1.0
		mt.material_override = mm
		mt.position = Vector3(cos(a) * dist, h / 2 - 6.0, sin(a) * dist + 10.0)
		mt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mt)

func _ground() -> void:
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(700, 700)
	g.mesh = pm
	g.material_override = _ground_mat(2, Color(0.17, 0.27, 0.2), Color(0.12, 0.2, 0.17))
	add_child(g)

func _road(a: Vector3, b: Vector3, width := 4.0, lamps := true) -> void:
	_paths.append([a, b, width])
	var mid := (a + b) / 2.0
	var len := a.distance_to(b)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(width, len + width * 0.6)
	mi.mesh = pm
	mi.material_override = _ground_mat(3, Color(0.36, 0.29, 0.24), Color(0.3, 0.24, 0.2))
	mi.position = mid + Vector3(0, 0.03, 0)
	mi.rotation.y = atan2(b.x - a.x, b.z - a.z)
	add_child(mi)
	var cap := MeshInstance3D.new(); cap.mesh = Toon.cyl(width / 2, width / 2, 0.01, 20)
	cap.material_override = mi.material_override; cap.position = b + Vector3(0, 0.03, 0); add_child(cap)
	if lamps:
		var dir := (b - a).normalized()
		var side := dir.cross(Vector3.UP)
		var n := int(len / 16.0)
		for k in range(1, n):
			var p := a + dir * (len * k / n) + side * (width * 0.5 + 0.9) * (1.0 if k % 2 == 0 else -1.0)
			_lamp(p, Color(1.0, 0.62, 0.28), 1.6, 9.0)

func _roads() -> void:
	_road(HOME + Vector3(0, 0, 10), DINH - Vector3(0, 0, 14))
	_road(HOME + Vector3(0, 0, -10), GRAVES + Vector3(0, 0, 12))
	_road(HOME + Vector3(12, 0, 0), FIELDS + Vector3(-22, 0, 8))
	_road(HOME + Vector3(-12, 0, 0), POND + Vector3(28, 0, 2))
	_road(DINH + Vector3(16, 0, -6), FIELDS + Vector3(-6, 0, 24), 3.0)
	_road(DINH + Vector3(-16, 0, -6), POND + Vector3(8, 0, 22), 3.0)

func _near_path(p: Vector3, margin := 0.5) -> bool:
	for s in _paths:
		var a: Vector3 = s[0]; var b: Vector3 = s[1]
		var ab := b - a; ab.y = 0
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		var q := a + ab * t
		if Vector2(p.x - q.x, p.z - q.z).length() < s[2] * 0.5 + margin:
			return true
	return false

func _clear(p: Vector3, margin := 0.0) -> bool:
	for o in _no_grass:
		if Vector2(p.x - o[0].x, p.z - o[0].z).length() < o[1] + margin:
			return false
	return not _near_path(p, margin)

# ============================================================ props
func _house(pos: Vector3, rot := 0.0, w := 10.0, d := 6.0, wall := Color(0.86, 0.76, 0.56)) -> void:
	var n := Node3D.new()
	n.add_child(_part(Toon.box(Vector3(w + 1.0, 0.6, d + 1.0)), Color(0.55, 0.32, 0.26), Vector3(0, 0.3, 0)))   # brick plinth
	n.add_child(_part(Toon.box(Vector3(w, 2.6, d)), wall, Vector3(0, 1.9, 0)))
	n.add_child(_part(Toon.box(Vector3(w * 0.9, 2.2, 0.15)), Color(0.4, 0.22, 0.14), Vector3(0, 1.75, d / 2 + 0.05), Vector3.ONE, true, {"stripes": 16.0, "stripe_color": Color(0.3, 0.16, 0.1), "stripe_axis": Vector3(1, 0, 0)}))
	for k in 5:   # front columns (cột hiên)
		n.add_child(_part(Toon.cyl(0.16, 0.18, 2.8, 10), Color(0.42, 0.2, 0.12), Vector3(-w / 2 + 0.4 + k * (w - 0.8) / 4.0, 2.0, d / 2 + 1.1)))
	# tiled roof: two slabs with tile stripes, upturned corners, ridge with curled ends
	var tile := {"stripes": 26.0, "stripe_color": Color(0.32, 0.12, 0.1), "stripe_axis": Vector3(1, 0, 0)}
	for side in [-1.0, 1.0]:
		var slab := _part(Toon.box(Vector3(w + 2.4, 0.25, d * 0.72 + 1.4)), Color(0.55, 0.2, 0.15), Vector3(0, 4.05, side * (d * 0.32 + 0.35)), Vector3.ONE, true, tile)
		slab.rotation.x = side * 0.5
		n.add_child(slab)
	n.add_child(_part(Toon.box(Vector3(w + 2.6, 0.35, 0.45)), Color(0.45, 0.16, 0.12), Vector3(0, 5.15, 0)))
	for sx in [-1.0, 1.0]:
		n.add_child(_part(Toon.sphere(0.3), Color(0.45, 0.16, 0.12), Vector3(sx * (w / 2 + 1.3), 5.35, 0), Vector3(1.2, 1.4, 0.8)))
		for sz in [-1.0, 1.0]:
			var c := _part(Toon.cone(0.22, 0.8, 6), Color(0.55, 0.2, 0.15), Vector3(sx * (w / 2 + 1.25), 3.35, sz * (d / 2 + 1.0)))
			c.rotation = Vector3(sz * 0.6, 0, -sx * 0.6)
			n.add_child(c)
	# warm window glow
	var win := MeshInstance3D.new(); win.mesh = Toon.box(Vector3(1.2, 0.8, 0.05)); win.material_override = Toon.glow(Color(1.0, 0.7, 0.35), 2.0)
	win.position = Vector3(w * 0.3, 2.0, d / 2 + 0.12); n.add_child(win)
	_put(n, pos, rot)
	# solid footprint as overlapping circles
	var basis := Basis(Vector3.UP, rot)
	var steps := int(w / (d * 0.9)) + 1
	for k in steps + 1:
		var off := basis * Vector3(-w / 2 + d / 2 + k * (w - d) / maxf(steps, 1), 0, 0.4)
		_solid(pos + off, d * 0.62)

func _well(pos: Vector3) -> void:
	var n := _group([_part(Toon.cyl(1.0, 1.1, 1.0, 20), Color(0.58, 0.55, 0.52), Vector3(0, 0.5, 0), Vector3.ONE, true, {"stripes": 12.0, "stripe_color": Color(0.45, 0.43, 0.41), "stripe_axis": Vector3(0, 1, 0)}),
		_part(Toon.cyl(0.8, 0.8, 0.05, 20), Color(0.03, 0.05, 0.1), Vector3(0, 1.01, 0), Vector3.ONE, false)])
	for sx in [-0.9, 0.9]:
		n.add_child(_part(Toon.cyl(0.08, 0.08, 2.2, 6), Color(0.45, 0.32, 0.2), Vector3(sx, 1.6, 0)))
	n.add_child(_part(Toon.cyl(0.06, 0.06, 2.0, 6), Color(0.45, 0.32, 0.2), Vector3(0, 2.6, 0), Vector3.ONE, true))
	n.get_child(n.get_child_count() - 1).rotation.z = PI / 2
	n.add_child(_part(Toon.cyl(0.25, 0.2, 0.35, 10), Color(0.5, 0.4, 0.3), Vector3(0, 1.7, 0)))   # gàu
	_put(n, pos, 0.0, 1.2)

func _haystack(pos: Vector3, s := 1.0) -> void:
	var straw := Color(0.86, 0.7, 0.36)
	_put(_group([_part(Toon.cyl(1.0, 1.1, 1.6, 14), straw, Vector3(0, 0.8, 0) * s, Vector3.ONE * s, true, {"stripes": 22.0, "stripe_color": straw.darkened(0.2), "stripe_axis": Vector3(0, 1, 0)}),
		_part(Toon.cone(1.25, 1.4, 14), straw.darkened(0.08), Vector3(0, 2.3, 0) * s, Vector3.ONE * s),
		_part(Toon.cyl(0.05, 0.05, 1.0, 6), Color(0.4, 0.3, 0.2), Vector3(0, 3.2, 0) * s, Vector3.ONE * s)]), pos, randf() * TAU, 1.15 * s)

func _chum(pos: Vector3, s := 1.0) -> void:
	var c := Color(0.42, 0.28, 0.2)
	_put(_group([_part(Toon.sphere(0.6), c, Vector3(0, 0.55, 0) * s, Vector3(1, 1.05, 1) * s),
		_part(Toon.cyl(0.38, 0.45, 0.25), c.darkened(0.15), Vector3(0, 1.15, 0) * s, Vector3.ONE * s),
		_part(Toon.cyl(0.44, 0.44, 0.08), Color(0.6, 0.5, 0.3), Vector3(0, 1.3, 0) * s, Vector3.ONE * s)]), pos, randf() * TAU, 0.62 * s)

func _areca(pos: Vector3) -> void:   # cây cau: slim trunk with a frond crown
	var n := Node3D.new()
	var h := randf_range(7.0, 9.5)
	n.add_child(_part(Toon.cyl(0.14, 0.2, h, 8), Color(0.55, 0.5, 0.42), Vector3(0, h / 2, 0), Vector3.ONE, true, {"stripes": 30.0, "stripe_color": Color(0.42, 0.38, 0.32), "stripe_axis": Vector3(0, 1, 0)}))
	for k in 7:
		var piv := Node3D.new(); piv.position = Vector3(0, h, 0); piv.rotation = Vector3(0, k * TAU / 7.0, 0)
		var leaf := _part(Toon.sphere(0.5), Color(0.13, 0.27, 0.18), Vector3(0, -0.25, -0.9), Vector3(0.16, 0.04, 1.25), false)
		leaf.rotation.x = 0.55
		piv.add_child(leaf); n.add_child(piv)
	_put(n, pos, 0.0, 0.3)

func _banana(pos: Vector3) -> void:
	var n := Node3D.new()
	n.add_child(_part(Toon.cyl(0.2, 0.3, 3.2, 10), Color(0.45, 0.55, 0.3), Vector3(0, 1.6, 0)))
	for i in 7:
		var leaf := _part(Toon.sphere(0.5), Color(0.24, 0.55, 0.3).lightened(randf() * 0.1), Vector3.ZERO, Vector3(0.38, 0.06, 1.7))
		var piv := Node3D.new(); piv.position = Vector3(0, 3.2, 0); piv.rotation = Vector3(0.0, i * TAU / 7.0 + randf() * 0.4, 0)
		leaf.position = Vector3(0, -0.15, -1.0); leaf.rotation.x = 0.45
		piv.add_child(leaf); n.add_child(piv)
	if randf() < 0.5:   # hanging bunch with a purple blossom
		n.add_child(_part(Toon.sphere(0.25), Color(0.6, 0.65, 0.3), Vector3(0.3, 2.5, 0), Vector3(1, 1.4, 1)))
		n.add_child(_part(Toon.cone(0.16, 0.4, 8), Color(0.55, 0.2, 0.35), Vector3(0.3, 2.0, 0)))
	_put(n, pos, randf() * TAU, 0.35)

func _scarecrow(pos: Vector3) -> void:   # bù nhìn đội nón lá
	var n := Node3D.new()
	n.add_child(_part(Toon.cyl(0.07, 0.07, 3.0, 6), Color(0.45, 0.33, 0.2), Vector3(0, 1.5, 0)))
	var arm := _part(Toon.cyl(0.05, 0.05, 2.4, 6), Color(0.45, 0.33, 0.2), Vector3(0, 2.2, 0)); arm.rotation.z = PI / 2; n.add_child(arm)
	n.add_child(_part(Toon.box(Vector3(1.0, 1.0, 0.4)), Color(0.35, 0.3, 0.5), Vector3(0, 1.9, 0)))
	n.add_child(_part(Toon.sphere(0.32), Color(0.85, 0.75, 0.55), Vector3(0, 2.75, 0)))
	n.add_child(_part(Toon.cone(0.75, 0.45, 18), Color(0.92, 0.82, 0.55), Vector3(0, 3.15, 0), Vector3.ONE, true, {"stripes": 30.0, "stripe_color": Color(0.8, 0.68, 0.42), "stripe_axis": Vector3(0, 1, 0)}))
	for sx in [-0.11, 0.11]:
		var e := MeshInstance3D.new(); e.mesh = Toon.sphere(0.05); e.material_override = Toon.glow(Color(1.0, 0.6, 0.2), 4.0)
		e.position = Vector3(sx, 2.8, 0.29); n.add_child(e)
	_put(n, pos, randf_range(-0.4, 0.4), 0.4)

func _hut(pos: Vector3) -> void:   # chòi canh on stilts
	var n := Node3D.new()
	for p in [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(1, 0, 1)]:
		n.add_child(_part(Toon.cyl(0.1, 0.12, 3.0, 6), Color(0.45, 0.35, 0.22), p + Vector3(0, 1.5, 0)))
	n.add_child(_part(Toon.box(Vector3(2.6, 0.2, 2.6)), Color(0.55, 0.42, 0.28), Vector3(0, 3.0, 0)))
	n.add_child(_part(Toon.cone(2.3, 1.8, 4), Color(0.75, 0.62, 0.35), Vector3(0, 4.1, 0), Vector3.ONE, true, {"stripes": 24.0, "stripe_color": Color(0.6, 0.48, 0.26), "stripe_axis": Vector3(0, 1, 0)}))
	n.get_child(n.get_child_count() - 1).rotation.y = PI / 4
	var l := OmniLight3D.new(); l.light_color = Color(1, 0.6, 0.3); l.light_energy = 1.5; l.omni_range = 9.0; l.position = Vector3(0, 3.5, 0)
	l.set_meta("e", 1.5); n.add_child(l); _flames.append(l)
	var g := MeshInstance3D.new(); g.mesh = Toon.sphere(0.2); g.material_override = Toon.glow(Color(1, 0.65, 0.3), 4.0); g.position = Vector3(0, 3.4, 0); n.add_child(g)
	_put(n, pos, randf() * TAU, 1.6)

func _banyan(pos: Vector3, s := 1.0) -> void:   # cây đa cổ thụ
	var n := Node3D.new()
	n.add_child(_part(Toon.cyl(1.4, 2.2, 7.0, 16), Color(0.33, 0.26, 0.22), Vector3(0, 3.5, 0), Vector3.ONE, true, {"stripes": 9.0, "stripe_color": Color(0.26, 0.2, 0.17), "stripe_axis": Vector3(0, 1, 0.3)}))
	for i in 14:
		var a := i * TAU / 14.0
		n.add_child(_part(Toon.cyl(0.07, 0.12, 6.0, 5), Color(0.3, 0.24, 0.2), Vector3(cos(a) * randf_range(2.5, 4.5), 3.0, sin(a) * randf_range(2.5, 4.5))))
	for i in 9:
		var a := i * TAU / 9.0
		n.add_child(_part(Toon.sphere(3.0), Color(0.12, 0.27, 0.2).lightened(randf() * 0.08), Vector3(cos(a) * 3.0, 8.0 + randf() * 1.5, sin(a) * 3.0), Vector3(1.25, 0.8, 1.25)))
	n.add_child(_part(Toon.sphere(3.4), Color(0.14, 0.3, 0.22), Vector3(0, 10.0, 0), Vector3(1.2, 0.8, 1.2)))
	n.scale = Vector3.ONE * s
	_put(n, pos, randf() * TAU, 2.4 * s)

func _gao_tree(pos: Vector3) -> void:   # cây gạo: bare branches with red blossoms (graveyard landmark)
	var n := Node3D.new()
	n.add_child(_part(Toon.cyl(0.6, 0.9, 6.0, 10), Color(0.35, 0.3, 0.28), Vector3(0, 3.0, 0)))
	for i in 6:
		var b := _part(Toon.cyl(0.12, 0.25, 4.0, 6), Color(0.35, 0.3, 0.28), Vector3.ZERO)
		var piv := Node3D.new(); piv.position = Vector3(0, 5.0 + i * 0.4, 0); piv.rotation = Vector3(0.9, i * TAU / 6.0, 0)
		b.position.y = 2.0; piv.add_child(b); n.add_child(piv)
		for k in 6:
			var f := MeshInstance3D.new(); f.mesh = Toon.sphere(0.2); f.material_override = Toon.glow(Color(0.95, 0.2, 0.15), 1.4)
			f.position = Vector3(randf_range(-0.6, 0.6), 1.5 + k * 0.4, randf_range(-0.6, 0.6)); piv.add_child(f)
	_put(n, pos, 0.0, 1.0)

func _grave(pos: Vector3) -> void:   # mộ đất with a small stone and an incense ember
	var n := _group([_part(Toon.sphere(1.0), Color(0.22, 0.3, 0.25), Vector3.ZERO, Vector3(1.4, 0.55, 1.05)),
		_part(Toon.box(Vector3(0.7, 0.9, 0.18)), Color(0.55, 0.55, 0.58), Vector3(0, 0.45, -1.05))])
	if randf() < 0.5:
		var e := MeshInstance3D.new(); e.mesh = Toon.sphere(0.05); e.material_override = Toon.glow(Color(1, 0.35, 0.1), 6.0)
		e.position = Vector3(0.2, 0.75, -1.2); n.add_child(e)
	_put(n, pos, randf_range(-0.3, 0.3), 1.1)

func _gate(pos: Vector3, rot := 0.0) -> void:   # cổng làng
	var n := Node3D.new()
	for sx in [-3.2, 3.2]:
		n.add_child(_part(Toon.box(Vector3(1.4, 5.0, 1.4)), Color(0.75, 0.7, 0.62), Vector3(sx, 2.5, 0)))
		n.add_child(_part(Toon.cone(0.9, 1.0, 4), Color(0.5, 0.2, 0.15), Vector3(sx, 5.5, 0)))
	n.add_child(_part(Toon.box(Vector3(8.2, 1.2, 1.6)), Color(0.75, 0.7, 0.62), Vector3(0, 4.6, 0)))
	var roof := _part(Toon.box(Vector3(9.4, 0.3, 2.6)), Color(0.55, 0.2, 0.15), Vector3(0, 5.45, 0), Vector3.ONE, true, {"stripes": 26.0, "stripe_color": Color(0.32, 0.12, 0.1), "stripe_axis": Vector3(1, 0, 0)})
	n.add_child(roof)
	for sx in [-1.0, 1.0]:
		var c := _part(Toon.cone(0.2, 0.9, 6), Color(0.55, 0.2, 0.15), Vector3(sx * 4.8, 5.8, 0)); c.rotation.z = -sx * 0.7; n.add_child(c)
	n.add_child(_part(Toon.box(Vector3(3.0, 0.8, 0.1)), Color(0.3, 0.12, 0.1), Vector3(0, 4.6, 0.82)))
	_put(n, pos, rot)
	var basis := Basis(Vector3.UP, rot)
	_solid(pos + basis * Vector3(-3.2, 0, 0), 1.0)
	_solid(pos + basis * Vector3(3.2, 0, 0), 1.0)

func _dinh_hall(pos: Vector3) -> void:   # đình làng: long low hall with a big curved roof
	var n := Node3D.new()
	n.add_child(_part(Toon.box(Vector3(20, 0.8, 11)), Color(0.5, 0.45, 0.42), Vector3(0, 0.4, 0)))
	for x in range(-4, 5):
		for z in [-4.0, 0.0, 4.0]:
			n.add_child(_part(Toon.cyl(0.32, 0.36, 4.2, 10), Color(0.45, 0.13, 0.1), Vector3(x * 2.2, 2.9, z)))
	var tile := {"stripes": 30.0, "stripe_color": Color(0.28, 0.1, 0.08), "stripe_axis": Vector3(1, 0, 0)}
	for side in [-1.0, 1.0]:
		var slab := _part(Toon.box(Vector3(23, 0.35, 7.6)), Color(0.5, 0.18, 0.13), Vector3(0, 6.2, side * 3.0), Vector3.ONE, true, tile)
		slab.rotation.x = side * 0.42; n.add_child(slab)
	n.add_child(_part(Toon.box(Vector3(23.5, 0.6, 0.7)), Color(0.42, 0.14, 0.1), Vector3(0, 7.9, 0)))
	for sx in [-1.0, 1.0]:
		n.add_child(_part(Toon.sphere(0.6), Color(0.42, 0.14, 0.1), Vector3(sx * 12.0, 8.3, 0), Vector3(1.0, 1.6, 0.7)))   # đầu đao
		for sz in [-1.0, 1.0]:
			var c := _part(Toon.cone(0.35, 1.6, 6), Color(0.5, 0.18, 0.13), Vector3(sx * 11.8, 4.9, sz * 6.3))
			c.rotation = Vector3(sz * 0.7, 0, -sx * 0.7); n.add_child(c)
	var glow := MeshInstance3D.new(); glow.mesh = Toon.box(Vector3(10, 2.6, 0.1)); glow.material_override = Toon.glow(Color(1.0, 0.6, 0.3), 1.2)
	glow.position = Vector3(0, 2.6, -4.4); n.add_child(glow)
	var l := OmniLight3D.new(); l.light_color = Color(1, 0.6, 0.3); l.light_energy = 3.0; l.omni_range = 18.0; l.position = Vector3(0, 3.0, 2.0)
	l.set_meta("e", 3.0); n.add_child(l); _flames.append(l)
	_put(n, pos)
	for x in [-8.0, -2.7, 2.7, 8.0]:
		_solid(pos + Vector3(x, 0, 0), 5.2)

# ============================================================ districts
func _home() -> void:
	_flat(Rect2(-14, -12, 28, 24), 0, Color(0.52, 0.36, 0.31), Color(0.45, 0.31, 0.28))   # sân gạch
	_no_grass.append([HOME, 17.0])
	_house(HOME + Vector3(0, 0, -15), 0.0, 14.0, 6.5)
	_house(HOME + Vector3(-17, 0, -4), PI / 2, 9.0, 5.0, Color(0.8, 0.7, 0.5))
	_house(HOME + Vector3(17, 0, -5), -PI / 2, 8.0, 5.0, Color(0.78, 0.72, 0.6))
	_well(HOME + Vector3(9, 0, 7))
	_haystack(HOME + Vector3(-10, 0, 9)); _haystack(HOME + Vector3(-12.5, 0, 6.5), 0.8)
	for p in [Vector3(11, 0, -6), Vector3(12.3, 0, -4.8), Vector3(10.6, 0, -4.3)]:
		_chum(HOME + p, randf_range(0.7, 1.0))
	for p in [Vector3(-11, 0, -21), Vector3(11, 0, -21), Vector3(-21, 0, 8)]:
		_areca(HOME + p)
	# mâm cúng cô hồn
	var table := _group([_part(Toon.box(Vector3(1.8, 0.12, 1.1)), Color(0.45, 0.25, 0.15), Vector3(0, 0.55, 0))])
	for i in 4:
		table.add_child(_part(Toon.sphere(0.18), Color(0.95, 0.95, 0.9), Vector3(-0.6 + i * 0.4, 0.66, 0), Vector3(1, 0.5, 1)))
	var inc := MeshInstance3D.new(); inc.mesh = Toon.sphere(0.06); inc.material_override = Toon.glow(Color(1, 0.35, 0.1), 6.0)
	inc.position = Vector3(0, 1.1, 0.3); table.add_child(inc)
	_put(table, HOME + Vector3(-4, 0, 10), 0.0, 1.0)
	for p in [Vector3(-8, 0, 2), Vector3(8, 0, 2), Vector3(0, 0, 11)]:
		_lamp(HOME + p, Color(1.0, 0.62, 0.28), 2.4, 12.0, true)
	_gate(HOME + Vector3(0, 0, 16), 0.0)
	_label(HOME + Vector3(0, 0, -15), "Sân nhà")

func _fields() -> void:
	# paddies: water cells separated by grassy dykes (bờ ruộng)
	var cell := 9.0
	var origin := FIELDS + Vector3(-27, 0, -36)
	for ix in 6:
		for iz in 8:
			var c := origin + Vector3(ix * cell + cell / 2, 0, iz * cell + cell / 2)
			if Vector2(c.x - FIELDS.x, c.z - FIELDS.z).length() < 6.0:
				continue
			_flat(Rect2(c.x - cell / 2 + 0.6, c.z - cell / 2 + 0.6, cell - 1.2, cell - 1.2), 4, Color(0.06, 0.1, 0.2), Color(0.1, 0.17, 0.3), Color(), 0.025)
	_no_grass.append([FIELDS + Vector3(0, 0, 0), 1.0])
	_scarecrow(FIELDS + Vector3(-9, 0, -18)); _scarecrow(FIELDS + Vector3(14, 0, 10)); _scarecrow(FIELDS + Vector3(6, 0, -30))
	_hut(FIELDS + Vector3(2, 0, 2))
	for k in 18:   # banana grove to the east
		_banana(FIELDS + Vector3(randf_range(30, 42), 0, randf_range(-30, 30)))
	for k in 6:
		_haystack(FIELDS + Vector3(randf_range(-26, 26), 0, randf_range(30, 40)), randf_range(0.7, 1.0))
	_label(FIELDS, "Ruộng lúa")

func _pond() -> void:
	var water := MeshInstance3D.new()
	var cy := CylinderMesh.new(); cy.top_radius = 1.0; cy.bottom_radius = 1.0; cy.height = 0.02; cy.radial_segments = 48
	water.mesh = cy
	water.scale = Vector3(POND_R.x, 1, POND_R.y)
	water.material_override = _ground_mat(4, Color(0.05, 0.09, 0.2), Color(0.09, 0.16, 0.3))
	water.position = POND + Vector3(0, 0.03, 0)
	add_child(water)
	var bank := MeshInstance3D.new(); bank.mesh = cy
	bank.scale = Vector3(POND_R.x + 1.6, 1, POND_R.y + 1.6)
	bank.material_override = _ground_mat(3, Color(0.28, 0.23, 0.2), Color(0.22, 0.18, 0.16))
	bank.position = POND + Vector3(0, 0.015, 0)
	add_child(bank)
	_no_grass.append([POND, POND_R.x + 2.0])
	# lotus leaves + flowers on the water (no collision)
	for k in 70:
		var a := randf() * TAU; var r := sqrt(randf()) * 0.88
		var p := POND + Vector3(cos(a) * POND_R.x * r, 0.06, sin(a) * POND_R.y * r)
		add_child(_part(Toon.cyl(0.7, 0.7, 0.03, 14), Color(0.16, 0.38, 0.24), p, Vector3.ONE * randf_range(0.6, 1.3), false))
		if randf() < 0.35:
			var f := Node3D.new(); f.position = p + Vector3(0, 0.15, 0)
			for q in 6:
				var pet := _part(Toon.sphere(0.18), Color(1.0, 0.65, 0.8), Vector3(cos(q * TAU / 6) * 0.15, 0.1, sin(q * TAU / 6) * 0.15), Vector3(0.6, 1.0, 0.6), false)
				pet.rotation = Vector3(sin(q * TAU / 6) * 0.5, 0, -cos(q * TAU / 6) * 0.5)
				f.add_child(pet)
			var heart := MeshInstance3D.new(); heart.mesh = Toon.sphere(0.08); heart.material_override = Toon.glow(Color(1.0, 0.9, 0.4), 2.5)
			heart.position.y = 0.12; f.add_child(heart)
			add_child(f)
	# bamboo bridge (cầu tre) out to a little fishing hut, and a thuyền nan
	var bridge := Node3D.new()
	for k in 12:
		bridge.add_child(_part(Toon.box(Vector3(1.6, 0.12, 0.35)), Color(0.62, 0.52, 0.32), Vector3(0, 0.45, -k * 0.6)))
	for k in 4:
		bridge.add_child(_part(Toon.cyl(0.06, 0.06, 1.2, 6), Color(0.5, 0.4, 0.25), Vector3(0.8, 0.5, -k * 2.0)))
	bridge.position = POND + Vector3(18, 0, 6); bridge.rotation.y = -PI / 2.6
	add_child(bridge)
	var boat := _part(Toon.sphere(1.0), Color(0.35, 0.28, 0.2), POND + Vector3(-6, 0.05, -4), Vector3(0.9, 0.35, 0.9), true, {"stripes": 20.0, "stripe_color": Color(0.28, 0.22, 0.16), "stripe_axis": Vector3(1, 0, 1)})
	add_child(boat)
	for k in 12:
		var a := k * TAU / 12.0 + randf() * 0.2
		_wisp_if(k % 4 == 0, POND + Vector3(cos(a) * POND_R.x * 0.6, 1.4, sin(a) * POND_R.y * 0.6))
	_lamp(POND + Vector3(26, 0, 0), Color(1, 0.62, 0.28), 2.2, 12.0, true)
	_label(POND, "Ao làng")

func _wisp_if(cond: bool, p: Vector3) -> void:
	if cond:
		_wisp(p)

func _dinh() -> void:
	_flat(Rect2(DINH.x - 22, DINH.z - 16, 44, 30), 3, Color(0.4, 0.33, 0.28), Color(0.34, 0.28, 0.24))
	_no_grass.append([DINH, 19.0])
	_dinh_hall(DINH + Vector3(0, 0, 4))
	_banyan(DINH + Vector3(-30, 0, -4), 1.2)
	_banyan(DINH + Vector3(32, 0, 10), 0.9)
	_gate(DINH + Vector3(0, 0, -17), 0.0)
	for x in [-14.0, -7.0, 7.0, 14.0]:
		_lamp(DINH + Vector3(x, 0, -10), Color(1.0, 0.5, 0.3), 2.0, 11.0)
	for k in 6:
		_areca(DINH + Vector3(randf_range(-40, 40), 0, randf_range(16, 30)))
	_label(DINH + Vector3(0, 0, 4), "Đình làng")

func _graves() -> void:
	_flat(Rect2(GRAVES.x - 30, GRAVES.z - 20, 60, 36), 2, Color(0.15, 0.21, 0.23), Color(0.1, 0.15, 0.18))
	_gao_tree(GRAVES + Vector3(0, 0, -6))
	for k in 34:
		var p := GRAVES + Vector3(randf_range(-28, 28), 0, randf_range(-18, 14))
		if p.distance_to(GRAVES + Vector3(0, 0, -6)) < 4.0 or _near_path(p, 1.5):
			continue
		_grave(p)
	for k in 10:
		_wisp(GRAVES + Vector3(randf_range(-26, 26), 1.6, randf_range(-18, 14)), Color(0.5, 1.0, 0.9) if k % 2 == 0 else Color(0.6, 0.75, 1.0))
	_label(GRAVES + Vector3(0, 0, -6), "Bãi tha ma")

# ============================================================ instanced vegetation
func _bamboo_clump_mesh() -> ArrayMesh:
	var parts := []
	for k in 7:
		var h := randf_range(6.0, 10.0)
		var p := Vector3(randf_range(-0.9, 0.9), h / 2, randf_range(-0.9, 0.9))
		parts.append([Toon.cyl(0.08, 0.11, h, 6), MeshKit.xf(p, Vector3.ONE, Vector3(randf_range(-0.1, 0.1), 0, randf_range(-0.1, 0.1))), Color(0.32, 0.42, 0.24)])
		parts.append([Toon.sphere(0.6, 6, 8), MeshKit.xf(Vector3(p.x, h, p.z), Vector3(1.0, 0.5, 1.0)), Color(0.1, 0.22, 0.15)])
		parts.append([Toon.sphere(0.45, 6, 8), MeshKit.xf(Vector3(p.x + 0.4, h - 1.6, p.z), Vector3(1.0, 0.45, 1.0)), Color(0.12, 0.25, 0.16)])
	return MeshKit.merge(parts)

func _bamboo_wall() -> void:
	var xforms := []
	var r := WORLD.grow(1.5)
	var per := 2.6
	for edge in 4:
		var a: Vector2; var b: Vector2
		match edge:
			0: a = r.position; b = Vector2(r.end.x, r.position.y)
			1: a = Vector2(r.end.x, r.position.y); b = r.end
			2: a = r.end; b = Vector2(r.position.x, r.end.y)
			_: a = Vector2(r.position.x, r.end.y); b = r.position
		var n := int(a.distance_to(b) / per)
		for k in n:
			for row in 2:
				var p := a.lerp(b, (k + randf()) / n)
				var out := Vector2(-(b - a).y, (b - a).x).normalized() * (row * 2.4 + randf() * 0.8)
				xforms.append(MeshKit.xf(Vector3(p.x - out.x, 0, p.y - out.y), Vector3.ONE * randf_range(0.8, 1.25), Vector3(0, randf() * TAU, 0)))
	# hedges around the home compound
	for k in 40:
		var a := k * TAU / 40.0
		var p := HOME + Vector3(cos(a) * 21.0, 0, sin(a) * 19.0)
		if absf(p.x) < 4.0 and p.z > 0:
			continue   # gate gap
		if _near_path(p, 1.0):
			continue
		if k % 2 == 0:
			continue   # sparse, decorative only: a walled courtyard turned the first stage into a cage
		xforms.append(MeshKit.xf(p, Vector3.ONE * randf_range(0.55, 0.75), Vector3(0, randf() * TAU, 0)))
		_no_grass.append([p, 1.0])
	var mm := MeshKit.scatter(_bamboo_clump_mesh(), xforms, _foliage_mat, true)
	add_child(mm)

func _foliage() -> void:
	# grass tufts
	var tuft := MeshKit.merge([
		[Toon.cone(0.12, 0.7, 4), MeshKit.xf(Vector3(0, 0.35, 0), Vector3.ONE, Vector3(0.2, 0, 0.1)), Color(0.15, 0.26, 0.17)],
		[Toon.cone(0.1, 0.55, 4), MeshKit.xf(Vector3(0.12, 0.27, 0.05), Vector3.ONE, Vector3(-0.3, 0, 0.3)), Color(0.18, 0.3, 0.19)],
		[Toon.cone(0.1, 0.6, 4), MeshKit.xf(Vector3(-0.1, 0.3, -0.06), Vector3.ONE, Vector3(0.1, 0, -0.35)), Color(0.13, 0.23, 0.16)],
	])
	var flower := MeshKit.merge([
		[Toon.cyl(0.02, 0.02, 0.45, 4), MeshKit.xf(Vector3(0, 0.22, 0)), Color(0.25, 0.42, 0.25)],
		[Toon.sphere(0.11, 4, 6), MeshKit.xf(Vector3(0, 0.48, 0), Vector3(1, 0.6, 1)), Color(1.0, 0.85, 0.45, 0.4)],
	])
	var flower2 := MeshKit.merge([
		[Toon.cyl(0.02, 0.02, 0.4, 4), MeshKit.xf(Vector3(0, 0.2, 0)), Color(0.25, 0.42, 0.25)],
		[Toon.sphere(0.1, 4, 6), MeshKit.xf(Vector3(0, 0.42, 0), Vector3(1, 0.6, 1)), Color(0.75, 0.6, 1.0, 0.4)],
	])
	var stone := MeshKit.merge([[Toon.sphere(0.3, 5, 6), MeshKit.xf(Vector3(0, 0.1, 0), Vector3(1.3, 0.6, 1.0)), Color(0.42, 0.4, 0.45)]])
	var rice := MeshKit.merge([
		[Toon.cone(0.06, 0.9, 3), MeshKit.xf(Vector3(0, 0.45, 0), Vector3.ONE, Vector3(0.15, 0, 0)), Color(0.42, 0.58, 0.28)],
		[Toon.cone(0.06, 0.85, 3), MeshKit.xf(Vector3(0.06, 0.42, 0), Vector3.ONE, Vector3(-0.2, 0, 0.2)), Color(0.5, 0.62, 0.3)],
		[Toon.cone(0.06, 0.8, 3), MeshKit.xf(Vector3(-0.05, 0.4, 0.04), Vector3.ONE, Vector3(0.05, 0, -0.25)), Color(0.62, 0.62, 0.32)],
	])
	var reed := MeshKit.merge([
		[Toon.cyl(0.03, 0.04, 1.8, 4), MeshKit.xf(Vector3(0, 0.9, 0)), Color(0.38, 0.45, 0.28)],
		[Toon.capsule(0.07, 0.4), MeshKit.xf(Vector3(0, 1.8, 0)), Color(0.45, 0.32, 0.22)],
	])
	var g := []; var fl := []; var fl2 := []; var st := []
	var area := WORLD.grow(-2.0)
	for k in 9000:
		var p := Vector3(randf_range(area.position.x, area.end.x), 0, randf_range(area.position.y, area.end.y))
		if not _clear(p):
			continue
		var x := MeshKit.xf(p, Vector3.ONE * randf_range(0.7, 1.5), Vector3(0, randf() * TAU, 0))
		var r := randf()
		if r < 0.86: g.append(x)
		elif r < 0.93: fl.append(x)
		elif r < 0.97: fl2.append(x)
		else: st.append(x)
	add_child(MeshKit.scatter(tuft, g, _foliage_mat))
	add_child(MeshKit.scatter(flower, fl, _foliage_mat))
	add_child(MeshKit.scatter(flower2, fl2, _foliage_mat))
	add_child(MeshKit.scatter(stone, st, _foliage_mat))
	# rice rows in the paddies
	var rx := []
	var origin := FIELDS + Vector3(-27, 0, -36)
	for ix in 6:
		for iz in 8:
			var c := origin + Vector3(ix * 9.0 + 4.5, 0, iz * 9.0 + 4.5)
			if Vector2(c.x - FIELDS.x, c.z - FIELDS.z).length() < 6.0:
				continue
			for a in 6:
				for b in 6:
					var p := c + Vector3(-3.4 + a * 1.36 + randf() * 0.2, 0, -3.4 + b * 1.36 + randf() * 0.2)
					rx.append(MeshKit.xf(p, Vector3.ONE * randf_range(0.8, 1.1), Vector3(0, randf() * TAU, 0)))
	add_child(MeshKit.scatter(rice, rx, _foliage_mat))
	# reeds along the pond bank
	var rd := []
	for k in 260:
		var a := randf() * TAU
		var s := randf_range(1.0, 1.12)
		rd.append(MeshKit.xf(POND + Vector3(cos(a) * POND_R.x * s, 0, sin(a) * POND_R.y * s), Vector3.ONE * randf_range(0.7, 1.2), Vector3(0, randf() * TAU, 0)))
	add_child(MeshKit.scatter(reed, rd, _foliage_mat))
