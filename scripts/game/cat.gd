class_name Cat
extends CharacterBody3D
## Chibi cat built from primitives (original design). Player-controlled or AI kitten (auto-hunts).
## Animation: trot cycle, anticipation crouch, leap arc, landing squash + dust, lean into turns,
## head tracks the nearest mouse, blinking, ear twitches, idle sit-and-groom.

signal pounced
signal landed(at: Vector3)

@export var is_player := true
@export var fur := Color(0.62, 0.55, 0.47)       ## mèo mướp grey-brown
@export var stripe := Color(0.30, 0.24, 0.2)
@export var belly := Color(0.95, 0.9, 0.82)
@export var eye := Color(0.75, 1.0, 0.35)
@export var size := 1.0
var striped := true
var hat := ""
var patches := Color(0, 0, 0, 0)
var points := false

var speed := 7.0
var catch_radius := 1.2
var pounce_dist := 4.0
var pounce_cd := 1.4
var max_charges := 1
var swarm: MiceSwarm
var bounds: Callable

var _charges := 1
var _recharge := 0.0
var _windup := 0.0                   ## >0: crouching before the leap
var _pounce_t := 0.0                 ## >0 while flying
const WINDUP := 0.07
const FLIGHT := 0.24
var _dir := Vector3.BACK             ## start facing the camera
var _phase := 0.0
var _squash := 0.0
var _lean := 0.0
var _still_t := 0.0
var _blink_t := 2.0
var _ear_t := 1.0
var _rig: Node3D
var _body: Node3D
var _head: Node3D
var _legs: Array[Node3D] = []
var _tail: Array[Node3D] = []
var _eyes: Array[Node3D] = []
var _ears: Array[Node3D] = []
var _ai_target := Vector3.ZERO
var _ai_t := 0.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new(); sh.radius = 0.55 * size
	cs.shape = sh; cs.position.y = 0.55 * size
	add_child(cs)
	_build()

func apply_skin(id: String) -> void:
	var s: Dictionary = Upgrades.SKINS.get(id, Upgrades.SKINS["muop"])
	fur = s.fur; stripe = s.stripe; belly = s.belly; eye = s.eye
	striped = s.stripes; hat = s.hat
	patches = s.get("patches", Color(0, 0, 0, 0)); points = s.get("points", false)
	if _rig:
		_rig.queue_free()
		_legs.clear(); _tail.clear(); _eyes.clear(); _ears.clear()
	_build()

func is_pouncing() -> bool:
	return _pounce_t > 0.0

func effective_catch_radius() -> float:
	return catch_radius * (1.35 if is_pouncing() else 1.0) * size

func cooldown_ratio() -> float:
	if _charges > 0:
		return 0.0
	return clampf(_recharge / pounce_cd, 0.0, 1.0)

func charges_left() -> int:
	return _charges

# ------------------------------------------------------------------ model
func _build() -> void:
	_rig = Node3D.new(); add_child(_rig)
	_rig.scale = Vector3.ONE * size
	_body = Node3D.new(); _body.position.y = 0.55; _rig.add_child(_body)
	var tabby := {"stripes": 14.0 if striped else 0.0, "stripe_color": stripe, "stripe_axis": Vector3(0, 0, 1)}
	_body.add_child(Toon.part(Toon.sphere(0.5), fur, Vector3.ZERO, Vector3(1.0, 0.85, 1.35), true, tabby))
	_body.add_child(Toon.part(Toon.sphere(0.36), belly, Vector3(0, -0.12, -0.3), Vector3(1.0, 0.8, 1.0), false))
	if patches.a > 0.0:   # tam thể: orange + black patches
		for pp in [[Vector3(0.25, 0.25, 0.2), stripe], [Vector3(-0.3, 0.2, -0.15), patches], [Vector3(0.05, 0.32, 0.45), patches]]:
			_body.add_child(Toon.part(Toon.sphere(0.25), pp[1], pp[0], Vector3(1.2, 0.5, 1.2), false))
	_head = Node3D.new(); _head.position = Vector3(0, 0.55, -0.62); _body.add_child(_head)
	var head_tabby := {"stripes": 22.0 if striped else 0.0, "stripe_color": stripe, "stripe_axis": Vector3(1, 0, 0)}
	_head.add_child(Toon.part(Toon.sphere(0.58), fur, Vector3.ZERO, Vector3(1.08, 0.95, 1.0), true, head_tabby))
	_head.add_child(Toon.part(Toon.sphere(0.3), stripe if points else belly, Vector3(0, -0.2, -0.4), Vector3(1.2, 0.75, 0.8), false))
	if patches.a > 0.0:
		_head.add_child(Toon.part(Toon.sphere(0.3), stripe, Vector3(0.28, 0.25, -0.2), Vector3(1, 0.7, 1), false))
	for sx in [-1.0, 1.0]:
		var ear := Node3D.new()
		ear.position = Vector3(0.33 * sx, 0.45, -0.02)
		ear.rotation = Vector3(-0.15, 0.0, -0.35 * sx)
		_head.add_child(ear); _ears.append(ear)
		ear.add_child(Toon.part(Toon.cone(0.22, 0.42, 4), stripe if points else fur, Vector3(0, 0.18, 0), Vector3(1, 1, 0.55)))
		ear.add_child(Toon.part(Toon.cone(0.13, 0.28, 4), Color(0.95, 0.6, 0.65), Vector3(0, 0.15, -0.05), Vector3(1, 1, 0.4), false))
		var e := Node3D.new(); e.position = Vector3(0.24 * sx, 0.05, -0.5); _head.add_child(e); _eyes.append(e)
		e.add_child(Toon.part(Toon.sphere(0.17), Color(0.05, 0.04, 0.08), Vector3.ZERO, Vector3(1, 1.15, 0.5), false))
		var iris := MeshInstance3D.new(); iris.mesh = Toon.sphere(0.14)
		iris.material_override = Toon.glow(eye, 2.2); iris.scale = Vector3(1, 1.15, 0.45); iris.position.z = -0.03
		e.add_child(iris)
		e.add_child(Toon.part(Toon.box(Vector3(0.045, 0.22, 0.02)), Color(0.02, 0.02, 0.03), Vector3(0, 0, -0.1), Vector3.ONE, false))
		var hl := MeshInstance3D.new(); hl.mesh = Toon.sphere(0.045); hl.material_override = Toon.glow(Color.WHITE, 4.0)
		hl.position = Vector3(0.05 * sx, 0.07, -0.11); e.add_child(hl)
		for i in 3:
			var w := Toon.part(Toon.box(Vector3(0.42, 0.012, 0.012)), Color(0.95, 0.95, 0.95), Vector3(0.42 * sx, -0.2 + 0.05 * i, -0.45), Vector3.ONE, false)
			w.rotation.z = (0.18 - 0.12 * i) * sx
			_head.add_child(w)
		# blush
		_head.add_child(Toon.part(Toon.sphere(0.08), Color(1.0, 0.6, 0.65), Vector3(0.36 * sx, -0.15, -0.42), Vector3(1.2, 0.6, 0.4), false))
	_head.add_child(Toon.part(Toon.sphere(0.06), Color(0.95, 0.5, 0.6), Vector3(0, -0.12, -0.6), Vector3(1.3, 0.9, 1), false))
	_add_hat()
	for p in [Vector3(-0.28, 0.0, -0.38), Vector3(0.28, 0.0, -0.38), Vector3(-0.28, 0.0, 0.38), Vector3(0.28, 0.0, 0.38)]:
		var hip := Node3D.new(); hip.position = p + Vector3(0, -0.15, 0); _body.add_child(hip)
		hip.add_child(Toon.part(Toon.capsule(0.13, 0.5), stripe if points else fur, Vector3(0, -0.22, 0)))
		hip.add_child(Toon.part(Toon.sphere(0.14), belly, Vector3(0, -0.45, -0.04), Vector3(1, 0.7, 1.2)))
		_legs.append(hip)
	var parent: Node3D = _body
	var off := Vector3(0, 0.15, 0.62)
	for i in 7:
		var seg := Node3D.new(); seg.position = off; parent.add_child(seg)
		var r := 0.12 - i * 0.008
		var col := stripe if (points or (striped and (i % 2 == 1 or i == 6))) else fur
		seg.add_child(Toon.part(Toon.sphere(r), col, Vector3.ZERO, Vector3.ONE, i == 0))
		_tail.append(seg)
		parent = seg
		off = Vector3(0, 0.12, 0.13)

func _add_hat() -> void:
	match hat:
		"nonla":   # conical palm-leaf hat with a chin strap
			var h := Toon.part(Toon.cone(0.85, 0.5, 20), Color(0.92, 0.82, 0.55), Vector3(0, 0.72, 0.02), Vector3.ONE, true, {"stripes": 30.0, "stripe_color": Color(0.8, 0.68, 0.42), "stripe_axis": Vector3(0, 1, 0)})
			h.rotation.x = -0.12
			_head.add_child(h)
			_head.add_child(Toon.part(Toon.cyl(0.5, 0.5, 0.02, 20), Color(0.85, 0.3, 0.35), Vector3(0, -0.15, 0.0), Vector3(1, 1, 1.05), false))
		"scarf":   # khăn rằn: black-and-white checked neck scarf
			var sc := Toon.part(Toon.cyl(0.42, 0.45, 0.2, 20), Color(0.12, 0.12, 0.14), Vector3(0, 0.25, -0.45), Vector3(1, 1, 1), true, {"stripes": 60.0, "stripe_color": Color(0.95, 0.95, 0.95), "stripe_axis": Vector3(1, 0, 1)})
			sc.rotation.x = 0.5
			_body.add_child(sc)
			_body.add_child(Toon.part(Toon.box(Vector3(0.22, 0.35, 0.05)), Color(0.12, 0.12, 0.14), Vector3(0.2, 0.0, -0.75), Vector3.ONE, true, {"stripes": 60.0, "stripe_color": Color(0.95, 0.95, 0.95), "stripe_axis": Vector3(1, 1, 0)}))
		"flower":  # hoa sen tucked by the left ear
			var f := Node3D.new(); f.position = Vector3(-0.42, 0.42, -0.15); _head.add_child(f)
			for k in 6:
				var a := k * TAU / 6.0
				f.add_child(Toon.part(Toon.sphere(0.1), Color(1.0, 0.7, 0.8), Vector3(cos(a) * 0.12, sin(a) * 0.12, 0), Vector3(1, 1, 0.5), false))
			f.add_child(Toon.part(Toon.sphere(0.07), Color(1.0, 0.9, 0.4), Vector3.ZERO, Vector3.ONE, false))

# ------------------------------------------------------------------ control
func _physics_process(dt: float) -> void:
	var move := Vector3.ZERO
	if is_player:
		var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		move = Vector3(v.x, 0, v.y)
		if Input.is_action_just_pressed("pounce"):
			try_pounce()
	else:
		move = _ai(dt)
	if _charges < max_charges:
		_recharge += dt
		if _recharge >= pounce_cd:
			_recharge = 0.0
			_charges += 1
	var prev_dir := _dir
	if move.length() > 0.05 and _windup <= 0.0 and _pounce_t <= 0.0:
		_dir = _dir.slerp(move.normalized(), 1.0 - exp(-14.0 * dt)).normalized()
	_lean = lerpf(_lean, clampf(prev_dir.signed_angle_to(_dir, Vector3.UP) / maxf(dt, 0.001) * 0.05, -0.35, 0.35), 1.0 - exp(-10.0 * dt))
	if _windup > 0.0:
		_windup -= dt
		velocity = velocity.lerp(Vector3.ZERO, 0.5)
		if _windup <= 0.0:
			_pounce_t = FLIGHT
			pounced.emit()
	elif _pounce_t > 0.0:
		_pounce_t -= dt
		velocity = _dir * (pounce_dist / FLIGHT)
		if _pounce_t <= 0.0:
			_squash = -0.4
			landed.emit(global_position)
	else:
		var target := move.limit_length(1.0) * speed
		velocity = velocity.lerp(target, 1.0 - exp(-12.0 * dt))
	velocity.y = 0.0
	move_and_slide()
	if bounds.is_valid():
		global_position = bounds.call(global_position)
	_animate(dt)

func try_pounce() -> void:
	if _charges <= 0 or _windup > 0.0 or _pounce_t > 0.0:
		return
	_charges -= 1
	_windup = WINDUP
	_squash = 0.0

func _ai(dt: float) -> Vector3:
	_ai_t -= dt
	if swarm:
		var t = swarm.nearest(global_position, 22.0)
		if t != null:
			var to: Vector3 = t - global_position; to.y = 0
			if to.length() < pounce_dist * 0.8 and _charges > 0:
				_dir = to.normalized(); try_pounce()
			return to.normalized()
	if _ai_t <= 0.0:
		_ai_t = randf_range(1.0, 2.5)
		_ai_target = global_position + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
	var w := _ai_target - global_position; w.y = 0
	return w.normalized() * 0.5 if w.length() > 0.5 else Vector3.ZERO

# ------------------------------------------------------------------ animation
func _animate(dt: float) -> void:
	var sp := Vector2(velocity.x, velocity.z).length()
	var run01 := clampf(sp / maxf(speed, 0.1), 0.0, 1.0)
	var now := Time.get_ticks_msec() * 0.001
	_phase += dt * (3.0 + sp * 1.6)
	_rig.rotation.y = lerp_angle(_rig.rotation.y, atan2(-_dir.x, -_dir.z), 1.0 - exp(-16.0 * dt))
	_rig.rotation.z = -_lean * run01
	_still_t = _still_t + dt if sp < 0.3 and not is_pouncing() else 0.0
	var sit := clampf((_still_t - 2.5) * 2.0, 0.0, 1.0)
	# legs: trot by diagonal pairs; tuck while flying; fold back legs when sitting
	for i in _legs.size():
		var off := 0.0 if i in [0, 3] else PI
		var a := sin(_phase + off) * 0.75 * run01
		if is_pouncing():
			a = -0.9 if i < 2 else 0.9      # front reach forward, back legs extend
		elif sit > 0.0 and i >= 2:
			a = lerpf(a, -1.2, sit)
		_legs[i].rotation.x = a
	# grooming paw when sitting
	if sit > 0.9:
		_legs[0].rotation.x = -1.4 + sin(now * 7.0) * 0.3
	# body: bob, squash & stretch, anticipation crouch, flight arc
	_squash = move_toward(_squash, 0.0, dt * 2.2)
	var bob := absf(sin(_phase)) * 0.09 * run01
	var breathe := sin(now * 3.0) * 0.02 * (1.0 - run01)
	var y := 0.55 + bob
	if _windup > 0.0:
		_body.scale = Vector3(1.15, 0.72, 1.05)
		y = 0.42
	elif is_pouncing():
		var k := 1.0 - _pounce_t / FLIGHT
		_body.scale = Vector3(0.88, 0.85, 1.4)
		y = 0.55 + sin(k * PI) * 0.9    # leap arc
		_body.rotation.x = lerpf(-0.35, 0.35, k)
	else:
		var s := 1.0 + _squash
		_body.scale = Vector3(1.0 / sqrt(s) + breathe, s + breathe, 1.0 / sqrt(s))
		_body.rotation.x = lerpf(_body.rotation.x, -0.35 * sit, 1.0 - exp(-8.0 * dt))
	_body.position.y = y - 0.1 * sit
	# head: track nearest mouse (or bob), tilt when idle
	var look_y := 0.0
	if swarm and not is_pouncing():
		var t = swarm.nearest(global_position, 9.0)
		if t != null:
			var to: Vector3 = t - global_position
			var local := _rig.global_transform.basis.inverse() * to
			look_y = clampf(atan2(-local.x, -local.z), -0.9, 0.9)
	_head.rotation.y = lerp_angle(_head.rotation.y, look_y, 1.0 - exp(-8.0 * dt))
	_head.rotation.x = -0.08 * run01 + sin(now * 2.0) * 0.04 + (sin(now * 7.0) * 0.12 if sit > 0.9 else 0.0)
	_head.rotation.z = sin(now * 1.3) * 0.08 * (1.0 - run01)
	# blink
	_blink_t -= dt
	var lid := 1.0
	if _blink_t < 0.12:
		lid = 0.12
		if _blink_t <= 0.0:
			_blink_t = randf_range(2.0, 4.5)
	for e in _eyes:
		e.scale.y = lerpf(e.scale.y, lid, 0.6)
	# ear twitch
	_ear_t -= dt
	if _ear_t <= 0.0:
		_ear_t = randf_range(1.2, 3.5)
		var which: Node3D = _ears[randi() % _ears.size()] if not _ears.is_empty() else null
		if which:
			var base_z: float = which.rotation.z
			var tw := which.create_tween()
			tw.tween_property(which, "rotation:z", base_z * 1.6, 0.06)
			tw.tween_property(which, "rotation:z", base_z, 0.12)
	# tail: lazy curl idle, stiff and high when running/flying
	for i in _tail.size():
		var up := -0.25 - 0.25 * run01 - (0.3 if is_pouncing() else 0.0)
		_tail[i].rotation.x = up + sin(now * 4.0 + i * 0.6) * 0.12
		_tail[i].rotation.y = sin(now * 5.2 + i * 0.5) * (0.18 + 0.1 * run01)
