class_name Village
extends Node3D
## Builds the night village. Six regions unlock in order; locked ones sit under dark mist.

const GROUND := preload("res://scripts/shaders/ground.gdshader")
const FONT := preload("res://assets/fonts/google/bevietnampro/BeVietnamPro-ExtraBold.ttf")

## x0, z0, x1, z1 per region (matches Upgrades.AREAS order).
const RECTS := [
	Rect2(-12, -6, 24, 16),    # 0 sân gạch
	Rect2(-12, -20, 24, 14),   # 1 gian nhà & bếp
	Rect2(12, -20, 18, 30),    # 2 vườn chuối
	Rect2(-30, -20, 18, 30),   # 3 ao làng
	Rect2(-30, 10, 60, 18),    # 4 đình & cây đa
	Rect2(-30, 28, 60, 16),    # 5 bãi tha ma
]

## Layout is authored at 1x and scaled on the XZ plane so the whole village is ~3x bigger in area.
const S := 1.8
var rects: Array[Rect2] = []
var unlocked := 1
var holes_by_area: Array = []        ## Array[Array[Vector3]]
var obstacles: Array = []            ## [center, radius]
var _mist: Array[Node3D] = []
var _labels: Array[Label3D] = []
var _wisps: Array[Node3D] = []
var _flames: Array[OmniLight3D] = []

func _s(p: Vector3) -> Vector3:
	return Vector3(p.x * S, p.y, p.z * S)

func _sr(r: Rect2) -> Rect2:
	return Rect2(r.position * S, r.size * S)

func build(areas: int) -> void:
	seed(1604)   # same village every run
	for r in RECTS:
		rects.append(_sr(r))
	for i in RECTS.size():
		holes_by_area.append([])
	_area_san(); _area_nha(); _area_vuon(); _area_ao(); _area_dinh(); _area_thama()
	for i in RECTS.size():
		_scatter(i)
		_add_mist(i)
	randomize()
	set_unlocked(areas)

func set_unlocked(n: int) -> void:
	unlocked = n
	for i in _mist.size():
		_mist[i].visible = i >= n
		_labels[i].visible = i == n   # only the next region shows its name + price hint

func holes() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in mini(unlocked, holes_by_area.size()):
		for h in holes_by_area[i]:
			out.append(h)
	return out

func inside(p: Vector3) -> bool:
	for i in mini(unlocked, rects.size()):
		var r: Rect2 = rects[i].grow(-0.4)
		if r.has_point(Vector2(p.x, p.z)):
			return true
	return false

func clamp_inside(p: Vector3) -> Vector3:
	if inside(p):
		return p
	var best := p; var bd := INF
	for i in mini(unlocked, rects.size()):
		var r: Rect2 = rects[i].grow(-0.5)
		var q := Vector3(clampf(p.x, r.position.x, r.end.x), p.y, clampf(p.z, r.position.y, r.end.y))
		var d := q.distance_squared_to(p)
		if d < bd:
			bd = d; best = q
	return best

func unlocked_bounds() -> Rect2:
	var r: Rect2 = rects[0]
	for i in mini(unlocked, rects.size()):
		r = r.merge(rects[i])
	return r

func _process(_dt: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	for i in _wisps.size():
		var w := _wisps[i]
		var base: Vector3 = w.get_meta("base")
		w.position = base + Vector3(sin(t * 0.7 + i) * 0.8, sin(t * 1.3 + i * 2.0) * 0.35, cos(t * 0.5 + i) * 0.8)
	for f in _flames:
		f.light_energy = f.get_meta("e") * (0.85 + 0.15 * sin(t * 9.0 + f.get_instance_id()) + randf() * 0.08)

# ================================================================ helpers
func _ground(rect: Rect2, mode: int, a: Color, b: Color, line := Color(0.25, 0.16, 0.18), y := 0.0) -> void:
	rect = _sr(rect)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = rect.size
	mi.mesh = pm
	var m := ShaderMaterial.new(); m.shader = GROUND
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("base_a", a); m.set_shader_parameter("base_b", b); m.set_shader_parameter("line_c", line)
	mi.material_override = m
	mi.position = Vector3(rect.get_center().x, y, rect.get_center().y)
	add_child(mi)

func _put(node: Node3D, pos: Vector3, rot_y := 0.0, solid_r := 0.0, scaled := false) -> Node3D:
	if not scaled:
		pos = _s(pos)
	node.position = pos
	node.rotation.y = rot_y
	add_child(node)
	if solid_r > 0.0:
		obstacles.append([Vector3(pos.x, 0, pos.z), solid_r])
		var sb := StaticBody3D.new(); sb.collision_layer = 1; sb.collision_mask = 0
		var cs := CollisionShape3D.new(); var cy := CylinderShape3D.new(); cy.radius = solid_r; cy.height = 3.0
		cs.shape = cy; cs.position.y = 1.5; sb.add_child(cs)
		sb.position = Vector3(pos.x, 0, pos.z)
		add_child(sb)
	return node

func _group(parts: Array) -> Node3D:
	var n := Node3D.new()
	for p in parts:
		n.add_child(p)
	return n

func _hole(area: int, pos: Vector3, scaled := false) -> void:
	if not scaled:
		pos = _s(pos)
	holes_by_area[area].append(pos)
	var h := Toon.part(Toon.cyl(0.32, 0.32, 0.02, 20), Color(0.05, 0.03, 0.06), pos + Vector3(0, 0.015, 0), Vector3(1, 1, 0.75), false)
	add_child(h)
	add_child(Toon.part(Toon.cyl(0.4, 0.45, 0.06, 20), Color(0.3, 0.22, 0.2), pos, Vector3(1, 1, 0.8), false))

func _lamp(pos: Vector3, color := Color(1.0, 0.62, 0.28), energy := 2.2, rng := 9.0, post := true) -> void:
	# đèn bão (hurricane lamp) on a bamboo post, or standing on a surface.
	var n := Node3D.new()
	var h := 2.4 if post else 0.0
	if post:
		n.add_child(Toon.part(Toon.cyl(0.07, 0.09, h, 8), Color(0.55, 0.45, 0.25), Vector3(0, h / 2, 0)))
		n.add_child(Toon.part(Toon.box(Vector3(0.5, 0.06, 0.06)), Color(0.55, 0.45, 0.25), Vector3(0.2, h, 0)))
	var lp := Vector3(0.38 if post else 0.0, h - 0.25 if post else 0.25, 0)
	n.add_child(Toon.part(Toon.cyl(0.13, 0.16, 0.08, 12), Color(0.35, 0.3, 0.25), lp + Vector3(0, -0.22, 0)))
	var glass := MeshInstance3D.new(); glass.mesh = Toon.sphere(0.16); glass.scale = Vector3(1, 1.4, 1)
	glass.material_override = Toon.glow(color, 3.5); glass.position = lp
	n.add_child(glass)
	n.add_child(Toon.part(Toon.cyl(0.05, 0.13, 0.08, 12), Color(0.35, 0.3, 0.25), lp + Vector3(0, 0.25, 0)))
	var l := OmniLight3D.new(); l.light_color = color; l.light_energy = energy; l.omni_range = rng
	l.omni_attenuation = 1.2; l.shadow_enabled = true; l.position = lp
	l.set_meta("e", energy)
	n.add_child(l); _flames.append(l)
	_put(n, pos, 0.0, 0.25 if post else 0.0)

func _wisp(pos: Vector3, color := Color(0.45, 0.95, 1.0)) -> void:
	# ma trơi: floating will-o'-wisp with a soft light (cute, not menacing)
	var n := Node3D.new()
	var core := MeshInstance3D.new(); core.mesh = Toon.sphere(0.18); core.material_override = Toon.glow(color, 5.0)
	n.add_child(core)
	var halo := MeshInstance3D.new(); halo.mesh = Toon.sphere(0.4)
	var hm := StandardMaterial3D.new(); hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; hm.albedo_color = Color(color, 0.18)
	halo.material_override = hm; n.add_child(halo)
	var l := OmniLight3D.new(); l.light_color = color; l.light_energy = 1.2; l.omni_range = 5.0; n.add_child(l)
	_put(n, pos)
	n.set_meta("base", n.position)
	_wisps.append(n)

func _chum(pos: Vector3, s := 1.0) -> void:
	var c := Color(0.42, 0.28, 0.2)
	_put(_group([
		Toon.part(Toon.sphere(0.6), c, Vector3(0, 0.55, 0) * s, Vector3(1, 1.05, 1) * s),
		Toon.part(Toon.cyl(0.38, 0.45, 0.25), c.darkened(0.15), Vector3(0, 1.15, 0) * s, Vector3.ONE * s),
		Toon.part(Toon.cyl(0.42, 0.42, 0.06), Color(0.3, 0.22, 0.15), Vector3(0, 1.3, 0) * s, Vector3.ONE * s),
	]), pos, randf() * TAU, 0.62 * s)

func _tree_banana(pos: Vector3) -> void:
	var n := Node3D.new()
	n.add_child(Toon.part(Toon.cyl(0.18, 0.26, 3.0, 10), Color(0.45, 0.55, 0.3), Vector3(0, 1.5, 0)))
	for i in 6:
		var leaf := Toon.part(Toon.sphere(0.5), Color(0.25, 0.55, 0.3).lightened(randf() * 0.1), Vector3.ZERO, Vector3(0.35, 0.06, 1.6))
		var piv := Node3D.new(); piv.position = Vector3(0, 3.0, 0); piv.rotation = Vector3(0.0, i * TAU / 6.0 + randf() * 0.4, 0)
		leaf.position = Vector3(0, -0.1, -0.9); leaf.rotation.x = 0.45
		piv.add_child(leaf); n.add_child(piv)
	_put(n, pos, randf() * TAU, 0.3)

func _bamboo(pos: Vector3, count := 7) -> void:
	var n := Node3D.new()
	for i in count:
		var h := randf_range(4.0, 6.5)
		var p := Vector3(randf_range(-0.7, 0.7), h / 2, randf_range(-0.7, 0.7))
		var stem := Toon.part(Toon.cyl(0.07, 0.09, h, 8), Color(0.45, 0.6, 0.3), p)
		stem.rotation = Vector3(randf_range(-0.12, 0.12), 0, randf_range(-0.12, 0.12))
		n.add_child(stem)
		n.add_child(Toon.part(Toon.sphere(0.8), Color(0.22, 0.42, 0.25), Vector3(p.x, h, p.z), Vector3(1.0, 0.6, 1.0)))
	_put(n, pos, 0.0, 0.9)

func _house_wall(a: Vector3, b: Vector3, h := 1.6, col := Color(0.78, 0.68, 0.52)) -> void:
	a = _s(a); b = _s(b)
	var mid := (a + b) / 2.0
	var len := a.distance_to(b)
	var w := Toon.part(Toon.box(Vector3(len, h, 0.3)), col, Vector3(0, h / 2, 0))
	var cap := Toon.part(Toon.box(Vector3(len + 0.2, 0.18, 0.5)), Color(0.45, 0.22, 0.18), Vector3(0, h + 0.09, 0))
	_put(_group([w, cap]), mid, -atan2(b.z - a.z, b.x - a.x), 0.0, true)

func _label(i: int, text: String) -> void:
	var r: Rect2 = rects[i]
	var l := Label3D.new()
	l.text = text
	l.font = FONT
	l.font_size = 140
	l.outline_size = 36
	l.pixel_size = 0.01
	l.modulate = Color(0.95, 0.88, 1.0, 0.9)
	l.outline_modulate = Color(0.08, 0.05, 0.15, 0.9)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = Vector3(r.get_center().x, 3.5, r.get_center().y)
	add_child(l)
	_labels.append(l)

func _add_mist(i: int) -> void:
	var r: Rect2 = rects[i]
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(r.size.x, 6.0, r.size.y)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.05, 0.04, 0.12, 0.82)
	mi.material_override = m
	mi.position = Vector3(r.get_center().x, 3.0, r.get_center().y)
	add_child(mi)
	_mist.append(mi)
	_label(i, "Vùng khóa · " + Upgrades.AREAS[i].name)

# ================================================================ regions
func _area_san() -> void:
	var r: Rect2 = RECTS[0]
	_ground(r, 0, Color(0.52, 0.36, 0.31), Color(0.45, 0.31, 0.28), Color(0.2, 0.15, 0.17))
	# porch (hiên) with columns along the house front
	_ground(Rect2(-12, -6, 24, 2.2), 1, Color(0.42, 0.28, 0.2), Color(0.36, 0.24, 0.17), Color(0.18, 0.12, 0.1), 0.06)
	for x in [-10.0, -5.0, 0.0, 5.0, 10.0]:
		_put(Toon.part(Toon.cyl(0.22, 0.25, 3.2, 12), Color(0.38, 0.22, 0.15), Vector3(0, 1.6, 0)), Vector3(x, 0, -4.2), 0.0, 0.3)
	_house_wall(Vector3(-12, 0, -6), Vector3(-12, 0, 10), 1.0, Color(0.55, 0.38, 0.3))
	_house_wall(Vector3(-12, 0, 10), Vector3(12, 0, 10), 1.0, Color(0.55, 0.38, 0.3))
	# chum vại cluster, rice straw stack, stone mortar
	_chum(Vector3(9.5, 0, -1.5)); _chum(Vector3(10.5, 0, 0.3), 0.8); _chum(Vector3(9.0, 0, 1.3), 0.7)
	_put(_group([Toon.part(Toon.sphere(1.0), Color(0.86, 0.7, 0.35), Vector3(0, 0.8, 0), Vector3(1.2, 1.0, 1.2)),
		Toon.part(Toon.cone(0.5, 0.6), Color(0.75, 0.6, 0.3), Vector3(0, 1.9, 0))]), Vector3(-9, 0, 6), 0.0, 1.2)
	_put(_group([Toon.part(Toon.cyl(0.45, 0.5, 0.6, 14), Color(0.55, 0.55, 0.58), Vector3(0, 0.3, 0)),
		Toon.part(Toon.cyl(0.3, 0.3, 0.05, 14), Color(0.25, 0.25, 0.28), Vector3(0, 0.61, 0), Vector3.ONE, false)]), Vector3(4, 0, 6.5), 0.0, 0.5)
	# mâm cúng cô hồn: low table with bowls and a single incense glow
	var table := _group([Toon.part(Toon.box(Vector3(1.8, 0.12, 1.1)), Color(0.45, 0.25, 0.15), Vector3(0, 0.55, 0))])
	for x in [-0.75, 0.75]:
		for z in [-0.4, 0.4]:
			table.add_child(Toon.part(Toon.box(Vector3(0.1, 0.5, 0.1)), Color(0.4, 0.22, 0.13), Vector3(x, 0.25, z)))
	for i in 4:
		table.add_child(Toon.part(Toon.sphere(0.18), Color(0.95, 0.95, 0.9), Vector3(-0.6 + i * 0.4, 0.66, 0), Vector3(1, 0.5, 1)))
	var incense := MeshInstance3D.new(); incense.mesh = Toon.sphere(0.05); incense.material_override = Toon.glow(Color(1, 0.35, 0.1), 6.0)
	incense.position = Vector3(0, 1.1, 0.3); table.add_child(incense)
	table.add_child(Toon.part(Toon.cyl(0.015, 0.015, 0.5), Color(0.8, 0.3, 0.2), Vector3(0, 0.85, 0.3), Vector3.ONE, false))
	_put(table, Vector3(-4, 0, 7.5), 0.0, 1.0)
	_lamp(Vector3(-6.5, 0, 2)); _lamp(Vector3(6.5, 0, 2))
	for p in [Vector3(-11, 0, -2), Vector3(11, 0, 8), Vector3(-11, 0, 9), Vector3(2, 0, 9.3)]:
		_hole(0, p)

func _area_nha() -> void:
	var r: Rect2 = RECTS[1]
	_ground(r, 1, Color(0.42, 0.28, 0.2), Color(0.35, 0.23, 0.16), Color(0.16, 0.1, 0.08), 0.02)
	_house_wall(Vector3(-12, 0, -20), Vector3(12, 0, -20), 2.2)
	_house_wall(Vector3(-12, 0, -20), Vector3(-12, 0, -6), 2.2)
	_house_wall(Vector3(12, 0, -20), Vector3(12, 0, -6), 2.2)
	_house_wall(Vector3(-4, 0, -20), Vector3(-4, 0, -14), 2.0)   # partition to the kitchen side
	# altar (bàn thờ): lacquered red table, incense bowl, photo frame, two oil lamps
	var altar := _group([
		Toon.part(Toon.box(Vector3(3.2, 0.2, 1.1)), Color(0.55, 0.12, 0.1), Vector3(0, 1.4, 0)),
		Toon.part(Toon.box(Vector3(3.0, 1.3, 0.9)), Color(0.42, 0.1, 0.08), Vector3(0, 0.65, 0)),
		Toon.part(Toon.box(Vector3(0.7, 0.9, 0.08)), Color(0.3, 0.2, 0.12), Vector3(0, 2.0, 0.35)),
		Toon.part(Toon.cyl(0.25, 0.2, 0.3, 14), Color(0.85, 0.82, 0.7), Vector3(0, 1.65, -0.05)),
		Toon.part(Toon.box(Vector3(3.6, 0.5, 0.12)), Color(0.75, 0.55, 0.2), Vector3(0, 3.0, 0.45)),
	])
	_put(altar, Vector3(4, 0, -19.2), 0.0, 1.4)
	_lamp(Vector3(5.4, 1.5, -19.2), Color(1.0, 0.6, 0.25), 1.8, 7.0, false)
	_lamp(Vector3(2.6, 1.5, -19.2), Color(1.0, 0.6, 0.25), 1.8, 7.0, false)
	# sập gụ (daybed) + tủ chè
	_put(_group([Toon.part(Toon.box(Vector3(3.2, 0.25, 2.0)), Color(0.28, 0.15, 0.1), Vector3(0, 0.6, 0)),
		Toon.part(Toon.box(Vector3(3.0, 0.45, 1.8)), Color(0.22, 0.12, 0.08), Vector3(0, 0.25, 0))]), Vector3(6, 0, -11), 0.0, 1.5)
	_put(Toon.part(Toon.box(Vector3(2.4, 2.0, 0.8)), Color(0.3, 0.17, 0.1), Vector3(0, 1.0, 0)), Vector3(10.6, 0, -15), PI / 2, 0.9)
	# bếp (kitchen) corner with fire
	var hearth := _group([Toon.part(Toon.box(Vector3(1.6, 0.4, 1.2)), Color(0.4, 0.35, 0.33), Vector3(0, 0.2, 0))])
	for i in 3:
		hearth.add_child(Toon.part(Toon.cyl(0.15, 0.2, 0.35, 8), Color(0.3, 0.27, 0.27), Vector3(cos(i * TAU / 3) * 0.4, 0.55, sin(i * TAU / 3) * 0.4)))
	hearth.add_child(Toon.part(Toon.sphere(0.45), Color(0.15, 0.13, 0.13), Vector3(0, 0.95, 0), Vector3(1, 0.7, 1)))
	var fire := MeshInstance3D.new(); fire.mesh = Toon.cone(0.25, 0.5, 8); fire.material_override = Toon.glow(Color(1, 0.45, 0.1), 5.0)
	fire.position = Vector3(0, 0.6, 0); hearth.add_child(fire)
	var fl := OmniLight3D.new(); fl.light_color = Color(1, 0.45, 0.15); fl.light_energy = 2.5; fl.omni_range = 8.0
	fl.position = Vector3(0, 0.9, 0); fl.set_meta("e", 2.5); hearth.add_child(fl); _flames.append(fl)
	_put(hearth, Vector3(-8, 0, -17), 0.0, 1.0)
	_chum(Vector3(-10.5, 0, -12), 0.9); _chum(Vector3(-6, 0, -18.6), 0.7)
	_put(_group([Toon.part(Toon.cyl(0.6, 0.5, 0.25, 16), Color(0.7, 0.6, 0.4), Vector3(0, 0.12, 0))]), Vector3(-7.5, 0, -9), 0.0, 0.6)  # nia (winnowing basket)
	for p in [Vector3(-11.3, 0, -19.3), Vector3(11.3, 0, -8), Vector3(-4.5, 0, -14.5), Vector3(0, 0, -19.5), Vector3(11.3, 0, -19.3)]:
		_hole(1, p)

func _area_vuon() -> void:
	var r: Rect2 = RECTS[2]
	_ground(r, 2, Color(0.2, 0.36, 0.25), Color(0.14, 0.27, 0.2))
	for i in 9:
		_tree_banana(Vector3(randf_range(14, 28), 0, randf_range(-18, 8)))
	for z in range(-18, 10, 4):
		_bamboo(Vector3(29.2, 0, z), 5)
	# chuồng gà (chicken coop)
	_put(_group([Toon.part(Toon.box(Vector3(2.4, 1.4, 1.8)), Color(0.55, 0.42, 0.25), Vector3(0, 0.7, 0)),
		Toon.part(Toon.box(Vector3(2.8, 0.2, 2.2)), Color(0.35, 0.2, 0.15), Vector3(0, 1.5, 0))]), Vector3(16, 0, 6), 0.3, 1.4)
	_lamp(Vector3(20, 0, -6), Color(1.0, 0.65, 0.3))
	for p in [Vector3(13, 0, -18), Vector3(27, 0, -2), Vector3(18, 0, 8.5), Vector3(24, 0, -12), Vector3(14, 0, 2)]:
		_hole(2, p)

func _area_ao() -> void:
	var r: Rect2 = RECTS[3]
	_ground(r, 3, Color(0.25, 0.22, 0.2), Color(0.19, 0.17, 0.16))
	var pond0 := Rect2(-27, -14, 11, 14)
	_ground(pond0, 4, Color(0.08, 0.12, 0.25), Color(0.12, 0.2, 0.35), Color(), 0.03)
	var pond := _sr(pond0)
	obstacles.append([Vector3(pond.get_center().x, 0, pond.get_center().y), 5.6 * S])
	var pb := StaticBody3D.new(); pb.collision_layer = 1
	var pcs := CollisionShape3D.new(); var pbox := BoxShape3D.new(); pbox.size = Vector3(pond.size.x, 2, pond.size.y)
	pcs.shape = pbox; pb.add_child(pcs); pb.position = Vector3(pond.get_center().x, 1, pond.get_center().y); add_child(pb)
	for i in 7:   # lily pads
		add_child(Toon.part(Toon.cyl(0.45, 0.45, 0.03, 14), Color(0.2, 0.45, 0.25), _s(Vector3(randf_range(-26, -17), 0.06, randf_range(-13, -1))), Vector3.ONE, false))
	# giếng (well)
	_put(_group([Toon.part(Toon.cyl(0.9, 0.95, 0.9, 18), Color(0.55, 0.52, 0.5), Vector3(0, 0.45, 0)),
		Toon.part(Toon.cyl(0.7, 0.7, 0.05, 18), Color(0.02, 0.03, 0.06), Vector3(0, 0.91, 0), Vector3.ONE, false)]), Vector3(-14.5, 0, 5), 0.0, 1.0)
	for z in range(-18, 10, 4):
		_bamboo(Vector3(-29.3, 0, z), 5)
	_wisp(Vector3(-22, 1.6, -8)); _wisp(Vector3(-19, 1.3, -3))
	for p in [Vector3(-14, 0, -18), Vector3(-28, 0, 7), Vector3(-16, 0, 8), Vector3(-29, 0, -17)]:
		_hole(3, p)

func _area_dinh() -> void:
	var r: Rect2 = RECTS[4]
	_ground(r, 3, Color(0.3, 0.26, 0.22), Color(0.24, 0.2, 0.18))
	# cây đa: huge banyan with aerial roots
	var tree := Node3D.new()
	tree.add_child(Toon.part(Toon.cyl(1.2, 1.8, 6.0, 14), Color(0.32, 0.25, 0.2), Vector3(0, 3.0, 0)))
	for i in 10:
		var a := i * TAU / 10.0
		tree.add_child(Toon.part(Toon.cyl(0.08, 0.12, 5.0, 6), Color(0.3, 0.24, 0.2), Vector3(cos(a) * 3.0, 2.5, sin(a) * 3.0)))
	for i in 7:
		var a := i * TAU / 7.0
		tree.add_child(Toon.part(Toon.sphere(2.6), Color(0.13, 0.28, 0.2), Vector3(cos(a) * 2.5, 6.5 + randf(), sin(a) * 2.5), Vector3(1.2, 0.8, 1.2)))
	_put(tree, Vector3(-16, 0, 19), 0.0, 2.0)
	# đình: low wide roof with curled corners on wooden columns
	var dinh := Node3D.new()
	dinh.add_child(Toon.part(Toon.box(Vector3(12, 0.5, 6)), Color(0.45, 0.4, 0.38), Vector3(0, 0.25, 0)))
	for x in [-5.0, -2.5, 0.0, 2.5, 5.0]:
		for z in [-2.2, 2.2]:
			dinh.add_child(Toon.part(Toon.cyl(0.22, 0.22, 3.0, 10), Color(0.4, 0.15, 0.1), Vector3(x, 2.0, z)))
	var roof := Toon.part(Toon.cyl(0.0, 1.0, 1.0, 4), Color(0.5, 0.25, 0.2), Vector3(0, 4.6, 0), Vector3(10.0, 2.2, 5.2))
	roof.rotation.y = PI / 4; dinh.add_child(roof)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			dinh.add_child(Toon.part(Toon.cone(0.25, 0.9, 6), Color(0.5, 0.25, 0.2), Vector3(6.6 * sx, 4.2, 3.4 * sz)))
	_put(dinh, Vector3(12, 0, 19), 0.0, 0.0)
	for x in [-5.0, 0.0, 5.0]:
		obstacles.append([_s(Vector3(12 + x, 0, 19)), 0.4])
	_lamp(Vector3(4, 0, 15)); _lamp(Vector3(20, 0, 15)); _lamp(Vector3(-8, 0, 14), Color(1, 0.6, 0.3))
	for p in [Vector3(-28, 0, 12), Vector3(28, 0, 26), Vector3(0, 0, 26), Vector3(-22, 0, 26)]:
		_hole(4, p)

func _area_thama() -> void:
	var r: Rect2 = RECTS[5]
	_ground(r, 2, Color(0.16, 0.22, 0.24), Color(0.11, 0.16, 0.19))
	for i in 14:
		# grassy burial mounds (mộ đất) with a small headstone: simple and respectful
		var p := Vector3(randf_range(-27, 27), 0, randf_range(30, 42))
		var m := _group([Toon.part(Toon.sphere(1.0), Color(0.2, 0.3, 0.25), Vector3(0, 0.0, 0), Vector3(1.3, 0.55, 1.0)),
			Toon.part(Toon.box(Vector3(0.6, 0.8, 0.15)), Color(0.55, 0.55, 0.58), Vector3(0, 0.4, -1.0))])
		_put(m, p, randf_range(-0.3, 0.3), 1.0)
	for i in 6:
		_wisp(Vector3(randf_range(-26, 26), 1.5, randf_range(30, 42)), Color(0.5, 1.0, 0.9) if i % 2 == 0 else Color(0.6, 0.75, 1.0))
	for p in [Vector3(-27, 0, 43), Vector3(27, 0, 30), Vector3(0, 0, 43), Vector3(-10, 0, 31), Vector3(15, 0, 41)]:
		_hole(5, p)

# ================================================================ filler
## Scatter small props + extra holes so each region feels lived-in and has more mouse spawns.
func _scatter(i: int) -> void:
	var r: Rect2 = rects[i].grow(-1.5)
	var palettes := [
		[Color(0.55, 0.38, 0.28), Color(0.6, 0.5, 0.35)],          # sân: pots, straw
		[Color(0.4, 0.25, 0.18), Color(0.5, 0.42, 0.3)],           # nhà
		[Color(0.2, 0.42, 0.25), Color(0.3, 0.5, 0.28)],           # vườn
		[Color(0.25, 0.4, 0.3), Color(0.45, 0.45, 0.42)],          # ao
		[Color(0.35, 0.3, 0.25), Color(0.45, 0.4, 0.35)],          # đình
		[Color(0.2, 0.3, 0.27), Color(0.45, 0.47, 0.5)],           # tha ma
	]
	var pal: Array = palettes[i]
	var placed := 0
	var tries := 0
	while placed < 10 + int(r.get_area() / 60.0) and tries < 400:
		tries += 1
		var p := Vector3(randf_range(r.position.x, r.end.x), 0, randf_range(r.position.y, r.end.y))
		var ok := true
		for o in obstacles:
			if Vector2(p.x - o[0].x, p.z - o[0].z).length() < o[1] + 2.0:
				ok = false; break
		if not ok or p.length() < 4.0:
			continue
		placed += 1
		match randi() % 5:
			0:  # bush / tuft
				_put(_group([Toon.part(Toon.sphere(0.6), pal[0].lightened(randf() * 0.15), Vector3(0, 0.35, 0), Vector3(1.2, 0.8, 1.0)),
					Toon.part(Toon.sphere(0.4), pal[0].lightened(0.1), Vector3(0.5, 0.25, 0.2), Vector3(1, 0.8, 1))]), p, randf() * TAU, 0.7, true)
			1:  # small jar
				_put(_group([Toon.part(Toon.sphere(0.35), Color(0.42, 0.28, 0.2), Vector3(0, 0.32, 0)),
					Toon.part(Toon.cyl(0.2, 0.25, 0.15), Color(0.35, 0.24, 0.17), Vector3(0, 0.68, 0))]), p, 0.0, 0.4, true)
			2:  # stones
				_put(_group([Toon.part(Toon.sphere(0.35), pal[1], Vector3(0, 0.15, 0), Vector3(1.3, 0.6, 1.0)),
					Toon.part(Toon.sphere(0.22), pal[1].darkened(0.1), Vector3(0.45, 0.1, 0.25), Vector3(1.2, 0.6, 1.0))]), p, randf() * TAU, 0.5, true)
			3:  # firewood / straw bundle
				var g := Node3D.new()
				for k in 3:
					var c := Toon.part(Toon.cyl(0.12, 0.12, 1.4, 8), Color(0.5, 0.38, 0.25) if i != 0 else Color(0.85, 0.7, 0.35), Vector3(0, 0.14 + k * 0.2, (k - 1) * 0.22))
					c.rotation.z = PI / 2; g.add_child(c)
				_put(g, p, randf() * TAU, 0.7, true)
			_:  # flower pot / reed
				_put(_group([Toon.part(Toon.cyl(0.25, 0.18, 0.35, 10), Color(0.6, 0.35, 0.25), Vector3(0, 0.17, 0)),
					Toon.part(Toon.sphere(0.3), Color(0.25, 0.45, 0.28), Vector3(0, 0.55, 0)),
					Toon.part(Toon.sphere(0.08), Color(0.95, 0.75, 0.3) if i != 5 else Color(0.7, 0.85, 1.0), Vector3(0.1, 0.8, 0), Vector3.ONE, false)]), p, 0.0, 0.35, true)
	# extra holes along the region's edges
	for k in 4:
		var e := randi() % 4
		var hp := Vector3.ZERO
		match e:
			0: hp = Vector3(randf_range(r.position.x, r.end.x), 0, r.position.y)
			1: hp = Vector3(randf_range(r.position.x, r.end.x), 0, r.end.y)
			2: hp = Vector3(r.position.x, 0, randf_range(r.position.y, r.end.y))
			_: hp = Vector3(r.end.x, 0, randf_range(r.position.y, r.end.y))
		_hole(i, hp, true)
	# extra lamps in large regions
	if i >= 2:
		for k in 2:
			_lamp(Vector3(randf_range(r.position.x, r.end.x), 0, randf_range(r.position.y, r.end.y)) / Vector3(S, 1, S))
