class_name MiceSwarm
extends Node3D
## All mice in one MultiMesh. Simple steering in GDScript: wander, flee cats, stay inside the
## unlocked map, slide around round obstacles. Catching is resolved here and reported by signal.

signal caught(pos: Vector3, kind: int, by_player: bool)

enum Kind { NHAT, CONG, VANG, MA }
const KINDS := {
	Kind.NHAT: {"color": Color(0.78, 0.74, 0.72), "scale": 1.35,  "flee": 6.0,  "wander": 1.6, "hp": 1, "fish": 1.0},
	Kind.CONG: {"color": Color(0.5, 0.42, 0.37), "scale": 1.9, "flee": 4.6,  "wander": 1.1, "hp": 2, "fish": 4.0},
	Kind.VANG: {"color": Color(1.0, 0.8, 0.25),   "scale": 1.3, "flee": 8.5,  "wander": 2.4, "hp": 1, "fish": 25.0},
	Kind.MA:   {"color": Color(0.55, 0.95, 1.0),  "scale": 1.45,  "flee": 6.5,  "wander": 2.0, "hp": 1, "fish": 60.0},
}
const CAP := 1500
const SHADER := preload("res://scripts/shaders/mouse_swarm.gdshader")

var pos := PackedVector3Array()
var vel := PackedVector3Array()
var kind := PackedInt32Array()
var hp := PackedInt32Array()
var phase := PackedFloat32Array()
var scared := PackedFloat32Array()
var spawn_in := PackedFloat32Array()     ## >0: still emerging from the hole (pop-in)
var grace := PackedFloat32Array()        ## >0: just got hit, can't be hit again yet

var cats: Array[Cat] = []
var player: Cat
var holes: Array[Vector3] = []
var obstacles: Array = []                ## [Vector3 center, float radius]
var inside: Callable                     ## func(Vector3) -> bool
var magnet := 0.0
var _mm: MultiMesh
var _mmi: MultiMeshInstance3D

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
	_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_mmi.custom_aabb = AABB(Vector3(-200, -5, -200), Vector3(400, 20, 400))
	var m := ShaderMaterial.new(); m.shader = SHADER
	_mmi.material_override = m
	add_child(_mmi)

func count() -> int:
	return pos.size()

func clear() -> void:
	# Packed arrays are value types: operate on the members directly, never via a temp list.
	pos.clear(); vel.clear(); kind.clear(); hp.clear(); phase.clear(); scared.clear(); spawn_in.clear(); grace.clear()
	_mm.visible_instance_count = 0

func spawn(k: int, at: Vector3) -> void:
	if pos.size() >= CAP:
		return
	pos.append(at); vel.append(Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * 2.0)
	kind.append(k); hp.append(KINDS[k].hp); phase.append(randf()); scared.append(0.0); spawn_in.append(0.35); grace.append(0.0)

func spawn_at_random_hole(k: int) -> void:
	if holes.is_empty():
		return
	var h: Vector3 = holes[randi() % holes.size()]
	spawn(k, h + Vector3(randf_range(-0.4, 0.4), 0, randf_range(-0.4, 0.4)))

## Nearest mouse position within max_d of p, or null.
func nearest(p: Vector3, max_d: float):
	var best := max_d * max_d
	var out = null
	for i in pos.size():
		var d := p.distance_squared_to(pos[i])
		if d < best:
			best = d; out = pos[i]
	return out

func _physics_process(dt: float) -> void:
	var i := 0
	while i < pos.size():
		if _step(i, dt):
			_remove(i)
		else:
			i += 1
	_draw()

## Returns true if the mouse got caught this frame.
func _step(i: int, dt: float) -> bool:
	var k: int = kind[i]
	var d: Dictionary = KINDS[k]
	var p := pos[i]
	if spawn_in[i] > 0.0:
		spawn_in[i] -= dt
	if grace[i] > 0.0:
		grace[i] -= dt
	# --- catching ---
	for c in cats:
		var r: float = c.effective_catch_radius() + 0.25 * float(d.scale)
		if Vector2(p.x - c.global_position.x, p.z - c.global_position.z).length() < r and spawn_in[i] <= 0.0 and grace[i] <= 0.0:
			hp[i] -= 1
			if hp[i] <= 0:
				caught.emit(p, k, c == player)
				return true
			# tough rat: knocked back, very scared
			vel[i] = (p - c.global_position).normalized() * d.flee * 1.6
			scared[i] = 1.0
			grace[i] = 0.4
			return false
	# --- steering ---
	var steer := Vector3.ZERO
	var threat := 0.0
	for c in cats:
		var away := p - c.global_position; away.y = 0
		var dist := away.length()
		if dist < 6.5:
			steer += away.normalized() * (6.5 - dist) / 6.5 * 3.0
			threat = maxf(threat, 1.0 - dist / 6.5)
	if magnet > 0.0 and player:
		var to := player.global_position - p; to.y = 0
		if to.length() < magnet:
			steer += to.normalized() * 2.5
	scared[i] = move_toward(scared[i], threat, dt * 3.0)
	# wander jitter
	phase[i] = fmod(phase[i] + dt * 0.37, 1.0)
	var wander_dir := Vector3(sin(phase[i] * 31.0 + i), 0, cos(phase[i] * 23.0 + i * 1.7))
	var v := vel[i]
	var max_sp: float = lerpf(d.wander, d.flee, scared[i])
	v += (steer * 6.0 + wander_dir * 1.5) * dt * 4.0
	v.y = 0
	v = v.limit_length(max_sp)
	var np := p + v * dt
	# obstacles: slide around circles
	for o in obstacles:
		var c: Vector3 = o[0]; var rr: float = o[1] + 0.25
		var off := np - c; off.y = 0
		if off.length() < rr:
			np = c + off.normalized() * rr
			np.y = 0
	if k != Kind.MA and inside.is_valid() and not inside.call(np):
		v = -v * 0.8          # bounce off the edge of the unlocked map
		np = p
	np.y = 0.0
	pos[i] = np
	vel[i] = v
	return false

func _remove(i: int) -> void:
	# swap-remove; Packed arrays are value types so each one is touched explicitly
	var last := pos.size() - 1
	pos[i] = pos[last]; pos.resize(last)
	vel[i] = vel[last]; vel.resize(last)
	kind[i] = kind[last]; kind.resize(last)
	hp[i] = hp[last]; hp.resize(last)
	phase[i] = phase[last]; phase.resize(last)
	scared[i] = scared[last]; scared.resize(last)
	spawn_in[i] = spawn_in[last]; spawn_in.resize(last)
	grace[i] = grace[last]; grace.resize(last)

func _draw() -> void:
	var n := pos.size()
	_mm.visible_instance_count = n
	for i in n:
		var d: Dictionary = KINDS[kind[i]]
		var v := vel[i]
		var yaw := atan2(-v.x, -v.z) if v.length() > 0.05 else 0.0
		var s: float = d.scale * (1.0 - clampf(spawn_in[i] / 0.35, 0.0, 1.0))
		var b := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * maxf(s, 0.01))
		_mm.set_instance_transform(i, Transform3D(b, pos[i]))
		_mm.set_instance_color(i, d.color)
		var sp01 := clampf(v.length() / d.flee, 0.0, 1.0)
		_mm.set_instance_custom_data(i, Color(fmod(i * 0.618, 1.0), sp01, scared[i], 1.0 if kind[i] == Kind.MA else 0.0))

func _build_mesh() -> ArrayMesh:
	# UV.x marks material: 0 fur (tinted by instance color), 0.5 pink, 1 black eye.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_sphere(st, Vector3(0, 0.2, 0.02), Vector3(0.22, 0.19, 0.3), 0.0)      # body
	_add_sphere(st, Vector3(0, 0.27, -0.27), Vector3(0.16, 0.15, 0.17), 0.0)  # head
	_add_sphere(st, Vector3(0, 0.25, -0.44), Vector3(0.04, 0.04, 0.04), 0.5)  # nose
	for sx in [-1.0, 1.0]:
		_add_sphere(st, Vector3(0.12 * sx, 0.42, -0.23), Vector3(0.1, 0.1, 0.03), 0.0)   # ear
		_add_sphere(st, Vector3(0.12 * sx, 0.42, -0.245), Vector3(0.065, 0.065, 0.02), 0.5)
		_add_sphere(st, Vector3(0.075 * sx, 0.31, -0.4), Vector3(0.04, 0.05, 0.03), 1.0)  # eye
	for j in 6:   # tail
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
