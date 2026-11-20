class_name MiceSwarm
extends Node3D
## All mice, drawn with one MultiMesh per kind (MouseArt meshes, mouse_swarm shader).
## Prey kinds flee, hostile kinds chase and bite. Damage goes through damage_in(); kills are
## reported with `killed` (special deaths - splitting, lantern blasts - are handled by the game).

signal killed(pos: Vector3, kind: int)
signal bite(dmg: int)

enum Kind { NHAT, CONG, VANG, MA, CHU, LINH, NHAY, BEO, DOI, DEN, TUONG }
const KIND_IDS := {"nhat": Kind.NHAT, "cong": Kind.CONG, "vang": Kind.VANG, "ma": Kind.MA, "chu": Kind.CHU,
	"linh": Kind.LINH, "nhay": Kind.NHAY, "beo": Kind.BEO, "doi": Kind.DOI, "den": Kind.DEN, "tuong": Kind.TUONG}
## from = minute it starts appearing, w = spawn weight, stage = first stage index where it appears.
const KINDS := {
	Kind.NHAT:  {"name": "Chuột nhắt", "color": Color(0.76, 0.72, 0.7),  "scale": 1.3, "hp": 10.0,  "speed": 5.6, "mode": "flee",  "xp": 2.0,  "fish": 1.0,  "from": 0.0, "w": 10.0, "stage": 0},
	Kind.CONG:  {"name": "Chuột cống", "color": Color(0.42, 0.34, 0.29), "scale": 1.6, "hp": 32.0,  "speed": 4.3, "mode": "chase", "xp": 4.0,  "fish": 2.0,  "from": 1.0, "w": 3.2,  "stage": 0, "bite": 1},
	Kind.VANG:  {"name": "Chuột vàng", "color": Color(1.0, 0.8, 0.28),   "scale": 1.25,"hp": 18.0,  "speed": 8.0, "mode": "flee",  "xp": 15.0, "fish": 15.0, "from": 0.0, "w": 0.25, "stage": 0},
	Kind.MA:    {"name": "Chuột ma",   "color": Color(0.55, 0.95, 1.0),  "scale": 1.4, "hp": 26.0,  "speed": 5.2, "mode": "chase", "xp": 5.0,  "fish": 4.0,  "from": 2.5, "w": 2.5,  "stage": 2, "bite": 1, "ghost": true, "hover": 1.0},
	Kind.CHU:   {"name": "Chuột chù",  "color": Color(0.5, 0.42, 0.55),  "scale": 1.5, "hp": 45.0,  "speed": 3.3, "mode": "chase", "xp": 5.0,  "fish": 3.0,  "from": 1.5, "w": 3.0,  "stage": 1, "bite": 1},
	Kind.LINH:  {"name": "Chuột lính", "color": Color(0.75, 0.55, 0.25), "scale": 1.55,"hp": 40.0,  "speed": 3.8, "mode": "chase", "xp": 6.0,  "fish": 3.0,  "from": 2.75, "w": 2.5,  "stage": 0, "bite": 1, "armor": 0.5},
	Kind.NHAY:  {"name": "Chuột nhảy", "color": Color(0.85, 0.6, 0.38),  "scale": 1.35,"hp": 20.0,  "speed": 4.8, "mode": "chase", "xp": 4.0,  "fish": 2.0,  "from": 2.0, "w": 2.5,  "stage": 0, "bite": 1, "leap": true},
	Kind.BEO:   {"name": "Chuột béo",  "color": Color(0.88, 0.7, 0.72),  "scale": 1.6, "hp": 70.0,  "speed": 2.8, "mode": "chase", "xp": 8.0,  "fish": 4.0,  "from": 2.5, "w": 1.6,  "stage": 0, "bite": 1, "split": 3},
	Kind.DOI:   {"name": "Chuột dơi",  "color": Color(0.28, 0.24, 0.32), "scale": 1.3, "hp": 16.0,  "speed": 7.0, "mode": "chase", "xp": 4.0,  "fish": 3.0,  "from": 3.0, "w": 3.0,  "stage": 1, "bite": 1, "fly": true, "hover": 1.6},
	Kind.DEN:   {"name": "Chuột đèn lồng", "color": Color(1.0, 0.3, 0.2), "scale": 1.35,"hp": 14.0, "speed": 3.5, "mode": "flee",  "xp": 3.0,  "fish": 2.0,  "from": 0.5, "w": 0.8,  "stage": 0, "blast": true},
	Kind.TUONG: {"name": "Chuột Tướng","color": Color(0.85, 0.15, 0.12), "scale": 2.6, "hp": 420.0, "speed": 3.4, "mode": "chase", "xp": 40.0, "fish": 30.0, "from": 99.0,"w": 0.0,  "stage": 0, "bite": 2, "armor": 0.2, "elite": true},
}
const CAP := 1600
const SHADER := preload("res://scripts/shaders/mouse_swarm.gdshader")

var pos := PackedVector3Array()
var vel := PackedVector3Array()
var kind := PackedInt32Array()
var hp := PackedFloat32Array()
var phase := PackedFloat32Array()
var scared := PackedFloat32Array()
var spawn_in := PackedFloat32Array()
var flash := PackedFloat32Array()
var act := PackedFloat32Array()        ## per-mouse action timer (leap / lunge)

var player: Node3D
var holes: Array[Vector3] = []
var obstacles: Array = []
var inside: Callable
var hp_mult := 1.0
var frozen := false
var _mms := {}                           ## kind -> MultiMesh
var _grid := {}
var _counts := {}

func _ready() -> void:
	for k in KINDS:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = MouseArt.build(k)
		mm.instance_count = CAP if k == Kind.NHAT else CAP / 2
		mm.visible_instance_count = 0
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.custom_aabb = AABB(Vector3(-400, -5, -400), Vector3(800, 20, 800))
		var m := ShaderMaterial.new(); m.shader = SHADER
		m.set_shader_parameter("hover", float(KINDS[k].get("hover", 0.0)))
		mi.material_override = m
		add_child(mi)
		_mms[k] = mm

func count() -> int:
	return pos.size()

func clear() -> void:
	pos.clear(); vel.clear(); kind.clear(); hp.clear(); phase.clear(); scared.clear(); spawn_in.clear(); flash.clear(); act.clear()
	for k in _mms: _mms[k].visible_instance_count = 0

func spawn(k: int, at: Vector3, hp_scale := 1.0) -> void:
	if pos.size() >= CAP:
		return
	pos.append(Vector3(at.x, 0, at.z)); vel.append(Vector3.ZERO)
	kind.append(k); hp.append(float(KINDS[k].hp) * hp_mult * hp_scale); phase.append(randf())
	scared.append(0.0); spawn_in.append(0.35); flash.append(0.0); act.append(randf_range(1.0, 3.0))

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

func nearest_n(p: Vector3, max_d: float, n: int) -> Array:
	var cands := []
	var md := max_d * max_d
	for i in pos.size():
		var d := p.distance_squared_to(pos[i])
		if d < md:
			cands.append([d, pos[i]])
	cands.sort_custom(func(a, b): return a[0] < b[0])
	return cands.slice(0, n).map(func(c): return c[1])

func damage_in(center: Vector3, r: float, dmg: float, dir := Vector3.ZERO, arc := TAU, knock := 2.0) -> int:
	var kills := 0
	var i := 0
	var cos_half := cos(arc * 0.5)
	while i < pos.size():
		var off := pos[i] - center; off.y = 0
		var d: Dictionary = KINDS[kind[i]]
		var rr := r + 0.2 * float(d.scale)
		if spawn_in[i] <= 0.0 and off.length_squared() < rr * rr:
			if arc < TAU - 0.01 and dir != Vector3.ZERO and off.length() > 0.3:
				if off.normalized().dot(dir) < cos_half:
					i += 1; continue
			hp[i] -= dmg * (1.0 - float(d.get("armor", 0.0)))
			flash[i] = 1.0
			if hp[i] <= 0.0:
				var p := pos[i]; var k := kind[i]
				_remove(i)
				killed.emit(p, k)
				kills += 1
				continue
			if off.length() > 0.01 and not d.has("elite"):
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
		if _grid.has(key): _grid[key].append(i)
		else: _grid[key] = [i]

func _step(i: int, dt: float) -> int:
	var k: int = kind[i]
	var d: Dictionary = KINDS[k]
	var p := pos[i]
	if spawn_in[i] > 0.0:
		spawn_in[i] -= dt
	flash[i] = maxf(0.0, flash[i] - dt * 6.0)
	act[i] -= dt
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
		if d.get("leap", false) and act[i] <= 0.0 and dist < 5.5:
			act[i] = 3.0
			vel[i] = to_p.normalized() * 11.0     # chuột nhảy pounces
		elif k == Kind.CONG and act[i] <= 0.0 and dist < 3.0:
			act[i] = 2.5
			vel[i] = to_p.normalized() * 7.0      # lunge
		if d.get("fly", false):
			want = (want + Vector3(sin(phase[i] * 40.0 + i), 0, cos(phase[i] * 33.0)) * 0.6).normalized()
			phase[i] = fmod(phase[i] + dt * 0.2, 1.0)
	else:
		var threat := clampf(1.0 - dist / 7.0, 0.0, 1.0)
		scared[i] = move_toward(scared[i], threat, dt * 3.0)
		phase[i] = fmod(phase[i] + dt * 0.37, 1.0)
		var wander := Vector3(sin(phase[i] * 31.0 + i), 0, cos(phase[i] * 23.0 + i * 1.7))
		want = (-to_p.normalized() * threat * 2.0 + wander * (1.0 - threat)).normalized()
		sp = lerpf(1.6, d.speed, scared[i])
	var sep := Vector3.ZERO
	var key := Vector2i(floori(p.x / 1.2), floori(p.z / 1.2))
	for ox in [-1, 0, 1]:
		for oz in [-1, 0, 1]:
			var cell = _grid.get(key + Vector2i(ox, oz))
			if cell == null:
				continue
			for j in cell:
				if j == i: continue
				var o: Vector3 = p - pos[j]
				var l2 := o.x * o.x + o.z * o.z
				var min_d := 0.35 * (float(d.scale) + float(KINDS[kind[j]].scale)) * 0.5
				if l2 < min_d * min_d and l2 > 0.0001:
					sep += o / sqrt(l2) * (min_d - sqrt(l2))
	var v := vel[i]
	v = v.lerp(want * sp + sep * 6.0, 1.0 - exp(-(2.5 if act[i] > 2.0 else 6.0) * dt))
	v.y = 0
	var np := p + v * dt
	var phasing: bool = d.get("ghost", false) or d.get("fly", false)
	if not phasing:
		for o in obstacles:
			var c: Vector3 = o[0]; var rr: float = o[1] + 0.25
			var off := np - c; off.y = 0
			if off.length_squared() < rr * rr:
				np = c + off.normalized() * rr
	if inside.is_valid() and not inside.call(np) and not d.get("fly", false):
		v = -v * 0.8
		np = p
	np.y = 0.0
	pos[i] = np
	vel[i] = v
	if d.has("bite") and dist < 0.75 + 0.22 * float(d.scale) and spawn_in[i] <= 0.0:
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
	act[i] = act[last]; act.resize(last)

func _draw() -> void:
	for k in _mms: _counts[k] = 0
	for i in pos.size():
		var k: int = kind[i]
		var mm: MultiMesh = _mms[k]
		var n: int = _counts[k]
		if n >= mm.instance_count:
			continue
		var d: Dictionary = KINDS[k]
		var v := vel[i]
		var yaw := atan2(-v.x, -v.z) if v.length() > 0.05 else 0.0
		var s: float = d.scale * (1.0 - clampf(spawn_in[i] / 0.35, 0.0, 1.0)) * (1.0 + 0.2 * flash[i])
		var b := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * maxf(s, 0.01))
		if act[i] > 2.2 and d.get("leap", false):
			b = b.rotated(b.x.normalized(), 0.4)      # nose up mid-leap
		mm.set_instance_transform(n, Transform3D(b, pos[i]))
		var sp01 := clampf(v.length() / float(d.speed), 0.0, 1.0)
		mm.set_instance_custom_data(n, Color(fmod(i * 0.618, 1.0), sp01, flash[i], scared[i]))
		_counts[k] = n + 1
	for k in _mms:
		_mms[k].visible_instance_count = _counts[k]

## A static copy of one kind's mesh (for death flips and the bestiary).
func mesh_of(k: int) -> Mesh:
	return _mms[k].mesh

func material_of(k: int) -> Material:
	for c in get_children():
		if c is MultiMeshInstance3D and c.multimesh == _mms[k]:
			return c.material_override
	return null
