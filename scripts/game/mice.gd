class_name MiceSwarm
extends Node3D
## All mice in one MultiMesh. Prey kinds flee, hostile kinds chase and bite the cat.
## Damage is dealt through damage_in(); kills are reported with `killed`.

signal killed(pos: Vector3, kind: int)
signal bite(dmg: int)

enum Kind { NHAT, CONG, VANG, MA, CHU }
const KIND_IDS := {"nhat": Kind.NHAT, "cong": Kind.CONG, "vang": Kind.VANG, "ma": Kind.MA, "chu": Kind.CHU}
const KINDS := {
	Kind.NHAT: {"color": Color(0.78, 0.74, 0.72), "scale": 1.35, "hp": 10.0, "speed": 5.6, "mode": "flee",  "xp": 1.0, "fish": 1.0},
	Kind.CONG: {"color": Color(0.5, 0.42, 0.37),  "scale": 1.9,  "hp": 32.0, "speed": 4.2, "mode": "chase", "xp": 2.0, "fish": 2.0, "bite": 1},
	Kind.VANG: {"color": Color(1.0, 0.8, 0.25),   "scale": 1.3,  "hp": 18.0, "speed": 8.0, "mode": "flee",  "xp": 8.0, "fish": 15.0},
	Kind.MA:   {"color": Color(0.55, 0.95, 1.0),  "scale": 1.45, "hp": 26.0, "speed": 5.0, "mode": "chase", "xp": 3.0, "fish": 4.0, "bite": 1, "ghost": true},
	Kind.CHU:  {"color": Color(0.55, 0.45, 0.6),  "scale": 1.6,  "hp": 45.0, "speed": 3.2, "mode": "chase", "xp": 3.0, "fish": 3.0, "bite": 1},
}
const CAP := 1500
const SHADER := preload("res://scripts/shaders/mouse_swarm.gdshader")

var pos := PackedVector3Array()
var vel := PackedVector3Array()
var kind := PackedInt32Array()
var hp := PackedFloat32Array()
var phase := PackedFloat32Array()
var scared := PackedFloat32Array()
var spawn_in := PackedFloat32Array()
var flash := PackedFloat32Array()

var player: Node3D
var holes: Array[Vector3] = []
var obstacles: Array = []
var inside: Callable
var hp_mult := 1.0
var frozen := false
var _mm: MultiMesh
var _mmi: MultiMeshInstance3D
var _grid := {}

func _ready() -> void:
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.use_custom_data = true
	_mm.mesh = _build_mesh()
	_mm.instance_count = CAP
	_mm.visible_instance_count = 0
	_mmi = MultiMeshInstance3D.new()
	_mmi.multimesh = _mm
	_mmi.custom_aabb = AABB(Vector3(-300, -5, -300), Vector3(600, 20, 600))
	var m := ShaderMaterial.new(); m.shader = SHADER
	_mmi.material_override = m
	add_child(_mmi)

func count() -> int:
	return pos.size()

func clear() -> void:
	pos.clear(); vel.clear(); kind.clear(); hp.clear(); phase.clear(); scared.clear(); spawn_in.clear(); flash.clear()
	_mm.visible_instance_count = 0

func spawn(k: int, at: Vector3) -> void:
	if pos.size() >= CAP:
		return
	pos.append(Vector3(at.x, 0, at.z)); vel.append(Vector3.ZERO)
	kind.append(k); hp.append(float(KINDS[k].hp) * hp_mult); phase.append(randf())
	scared.append(0.0); spawn_in.append(0.35); flash.append(0.0)

func spawn_at_random_hole(k: int) -> void:
	if holes.is_empty():
		return
	var h: Vector3 = holes[randi() % holes.size()]
	spawn(k, h + Vector3(randf_range(-0.4, 0.4), 0, randf_range(-0.4, 0.4)))

func nearest(p: Vector3, max_d: float):
	var best := max_d * max_d
	var out = null
	for i in pos.size():
		var d := p.distance_squared_to(pos[i])
		if d < best:
			best = d; out = pos[i]
	return out

## Several nearest positions (for multi-target weapons).
func nearest_n(p: Vector3, max_d: float, n: int) -> Array:
	var cands := []
	var md := max_d * max_d
	for i in pos.size():
		var d := p.distance_squared_to(pos[i])
		if d < md:
			cands.append([d, pos[i]])
	cands.sort_custom(func(a, b): return a[0] < b[0])
	return cands.slice(0, n).map(func(c): return c[1])

## Damage every mouse within r of center (optionally only within an arc around dir).
## Returns number killed. Knockback pushes survivors away from `center`.
func damage_in(center: Vector3, r: float, dmg: float, dir := Vector3.ZERO, arc := TAU, knock := 2.0) -> int:
	var kills := 0
	var i := 0
	var cos_half := cos(arc * 0.5)
	while i < pos.size():
		var off := pos[i] - center; off.y = 0
		var rr := r + 0.2 * float(KINDS[kind[i]].scale)
		if spawn_in[i] <= 0.0 and off.length_squared() < rr * rr:
			if arc < TAU - 0.01 and dir != Vector3.ZERO and off.length() > 0.3:
				if off.normalized().dot(dir) < cos_half:
					i += 1; continue
			hp[i] -= dmg
			flash[i] = 1.0
			if hp[i] <= 0.0:
				killed.emit(pos[i], kind[i])
				_remove(i)
				kills += 1
				continue
			if off.length() > 0.01:
				vel[i] += off.normalized() * knock * 3.0
		i += 1
	return kills

func _physics_process(dt: float) -> void:
	if frozen:
		_draw(); return
	_build_grid()
	var bite_dmg := 0
	for i in pos.size():
		bite_dmg = maxi(bite_dmg, _step(i, dt))
	if bite_dmg > 0:
		bite.emit(bite_dmg)
	_draw()

func _build_grid() -> void:
	_grid.clear()
	for i in pos.size():
		var key := Vector2i(floori(pos[i].x / 1.2), floori(pos[i].z / 1.2))
		if _grid.has(key):
			_grid[key].append(i)
		else:
			_grid[key] = [i]

func _step(i: int, dt: float) -> int:
	var k: int = kind[i]
	var d: Dictionary = KINDS[k]
	var p := pos[i]
	if spawn_in[i] > 0.0:
		spawn_in[i] -= dt
	flash[i] = maxf(0.0, flash[i] - dt * 6.0)
	var to_p := Vector3.ZERO
	var dist := 999.0
	if player:
		to_p = player.global_position - p; to_p.y = 0
		dist = to_p.length()
	var want := Vector3.ZERO
	var sp: float = d.speed
	if d.mode == "chase":
		want = to_p.normalized() if dist > 0.01 else Vector3.ZERO
		scared[i] = 0.0
	else:
		var threat := clampf(1.0 - dist / 7.0, 0.0, 1.0)
		scared[i] = move_toward(scared[i], threat, dt * 3.0)
		phase[i] = fmod(phase[i] + dt * 0.37, 1.0)
		var wander := Vector3(sin(phase[i] * 31.0 + i), 0, cos(phase[i] * 23.0 + i * 1.7))
		want = (-to_p.normalized() * threat * 2.0 + wander * (1.0 - threat)).normalized()
		sp = lerpf(1.6, d.speed, scared[i])
	# separation from neighbours (grid lookup)
	var sep := Vector3.ZERO
	var key := Vector2i(floori(p.x / 1.2), floori(p.z / 1.2))
	for ox in [-1, 0, 1]:
		for oz in [-1, 0, 1]:
			var cell = _grid.get(key + Vector2i(ox, oz))
			if cell == null:
				continue
			for j in cell:
				if j == i:
					continue
				var o: Vector3 = p - pos[j]
				var l2 := o.x * o.x + o.z * o.z
				if l2 < 0.5 and l2 > 0.0001:
					sep += o / sqrt(l2) * (0.71 - sqrt(l2))
	var v := vel[i]
	v = v.lerp(want * sp + sep * 6.0, 1.0 - exp(-6.0 * dt))
	v.y = 0
	var np := p + v * dt
	if not d.get("ghost", false):
		for o in obstacles:
			var c: Vector3 = o[0]; var rr: float = o[1] + 0.25
			var off := np - c; off.y = 0
			if off.length_squared() < rr * rr:
				np = c + off.normalized() * rr
		if inside.is_valid() and not inside.call(np):
			v = -v * 0.8
			np = p
	np.y = 0.0
	pos[i] = np
	vel[i] = v
	if d.has("bite") and dist < 0.9 + 0.2 * float(d.scale) and spawn_in[i] <= 0.0:
		return int(d.bite)
	return 0

func _remove(i: int) -> void:
	var last := pos.size() - 1
	pos[i] = pos[last]; pos.resize(last)
	vel[i] = vel[last]; vel.resize(last)
	kind[i] = kind[last]; kind.resize(last)
	hp[i] = hp[last]; hp.resize(last)
	phase[i] = phase[last]; phase.resize(last)
	scared[i] = scared[last]; scared.resize(last)
	spawn_in[i] = spawn_in[last]; spawn_in.resize(last)
	flash[i] = flash[last]; flash.resize(last)

func _draw() -> void:
	var n := pos.size()
	_mm.visible_instance_count = n
	for i in n:
		var d: Dictionary = KINDS[kind[i]]
		var v := vel[i]
		var yaw := atan2(-v.x, -v.z) if v.length() > 0.05 else 0.0
		var s: float = d.scale * (1.0 - clampf(spawn_in[i] / 0.35, 0.0, 1.0)) * (1.0 + 0.25 * flash[i])
		var b := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * maxf(s, 0.01))
		_mm.set_instance_transform(i, Transform3D(b, pos[i]))
		var c: Color = d.color
		_mm.set_instance_color(i, c.lerp(Color(1, 1, 1), flash[i] * 0.8))
		var sp01 := clampf(v.length() / float(d.speed), 0.0, 1.0)
		var angry := 1.0 if d.mode == "chase" else 0.0
		_mm.set_instance_custom_data(i, Color(fmod(i * 0.618, 1.0), sp01, maxf(scared[i], flash[i]), (1.0 if d.get("ghost", false) else 0.0) + angry * 2.0))

func _build_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_sphere(st, Vector3(0, 0.2, 0.02), Vector3(0.22, 0.19, 0.3), 0.0)
	_add_sphere(st, Vector3(0, 0.27, -0.27), Vector3(0.16, 0.15, 0.17), 0.0)
	_add_sphere(st, Vector3(0, 0.25, -0.44), Vector3(0.04, 0.04, 0.04), 0.5)
	for sx in [-1.0, 1.0]:
		_add_sphere(st, Vector3(0.12 * sx, 0.42, -0.23), Vector3(0.1, 0.1, 0.03), 0.0)
		_add_sphere(st, Vector3(0.12 * sx, 0.42, -0.245), Vector3(0.065, 0.065, 0.02), 0.5)
		_add_sphere(st, Vector3(0.075 * sx, 0.31, -0.4), Vector3(0.04, 0.05, 0.03), 1.0)
	for j in 6:
		var z := 0.32 + j * 0.09
		_add_sphere(st, Vector3(0, 0.12 + j * 0.02, z), Vector3(0.03, 0.03, 0.06), 0.5)
	st.generate_normals()
	return st.commit()

func _add_sphere(st: SurfaceTool, c: Vector3, r: Vector3, mat_id: float) -> void:
	var rings := 8; var segs := 12
	for y in rings:
		for x in segs:
			var q := []
			for o in [[0, 0], [1, 0], [1, 1], [0, 1]]:
				var th := PI * float(y + o[1]) / rings
				var ph := TAU * float(x + o[0]) / segs
				q.append(c + Vector3(sin(th) * cos(ph) * r.x, cos(th) * r.y, sin(th) * sin(ph) * r.z))
			for tri in [[0, 1, 2], [0, 2, 3]]:
				for t in tri:
					st.set_uv(Vector2(mat_id, 0))
					st.add_vertex(q[t])
