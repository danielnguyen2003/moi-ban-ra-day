class_name Cat
extends CharacterBody3D
## Chibi cat built from primitives (original design). Player-controlled or AI kitten (auto-hunts).

signal pounced

@export var is_player := true
@export var fur := Color(0.62, 0.55, 0.47)       ## mèo mướp grey-brown
@export var stripe := Color(0.30, 0.24, 0.2)
@export var belly := Color(0.95, 0.9, 0.82)
@export var eye := Color(0.75, 1.0, 0.35)
@export var size := 1.0

var speed := 7.0
var catch_radius := 1.2
var pounce_dist := 4.0
var pounce_cd := 1.4
var swarm: MiceSwarm                 ## kittens query it for targets
var bounds: Callable                 ## func(Vector3) -> Vector3 clamp into walkable area

var _pounce_t := 0.0                 ## >0 while dashing
var _cool := 0.0
var _crouch := 0.0
var _dir := Vector3.FORWARD
var _phase := 0.0
var _squash := 0.0
var _rig: Node3D
var _body: Node3D
var _head: Node3D
var _legs: Array[Node3D] = []
var _tail: Array[Node3D] = []
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

func is_pouncing() -> bool:
	return _pounce_t > 0.0

func effective_catch_radius() -> float:
	return catch_radius * (1.35 if is_pouncing() else 1.0) * size

func cooldown_ratio() -> float:
	return clampf(_cool / pounce_cd, 0.0, 1.0)

# ------------------------------------------------------------------ model
func _build() -> void:
	_rig = Node3D.new(); add_child(_rig)
	_rig.scale = Vector3.ONE * size
	_body = Node3D.new(); _body.position.y = 0.55; _rig.add_child(_body)
	var tabby := {"stripes": 14.0, "stripe_color": stripe, "stripe_axis": Vector3(0, 0, 1)}
	_body.add_child(Toon.part(Toon.sphere(0.5), fur, Vector3.ZERO, Vector3(1.0, 0.85, 1.35), true, tabby))
	_body.add_child(Toon.part(Toon.sphere(0.36), belly, Vector3(0, -0.12, -0.3), Vector3(1.0, 0.8, 1.0), false))
	# Head: oversized for chibi proportions.
	_head = Node3D.new(); _head.position = Vector3(0, 0.55, -0.62); _body.add_child(_head)
	var head_tabby := {"stripes": 22.0, "stripe_color": stripe, "stripe_axis": Vector3(1, 0, 0)}
	_head.add_child(Toon.part(Toon.sphere(0.58), fur, Vector3.ZERO, Vector3(1.08, 0.95, 1.0), true, head_tabby))
	_head.add_child(Toon.part(Toon.sphere(0.3), belly, Vector3(0, -0.2, -0.4), Vector3(1.2, 0.75, 0.8), false))
	for sx in [-1.0, 1.0]:
		var ear := Node3D.new()
		ear.position = Vector3(0.33 * sx, 0.45, -0.02)
		ear.rotation = Vector3(-0.15, 0.0, -0.35 * sx)
		_head.add_child(ear)
		ear.add_child(Toon.part(Toon.cone(0.22, 0.42, 4), fur, Vector3(0, 0.18, 0), Vector3(1, 1, 0.55)))
		ear.add_child(Toon.part(Toon.cone(0.13, 0.28, 4), Color(0.95, 0.6, 0.65), Vector3(0, 0.15, -0.05), Vector3(1, 1, 0.4), false))
		# Big glowing eyes: the cute-spooky signature at night.
		var e := Node3D.new(); e.position = Vector3(0.24 * sx, 0.05, -0.5); _head.add_child(e)
		e.add_child(Toon.part(Toon.sphere(0.17), Color(0.05, 0.04, 0.08), Vector3.ZERO, Vector3(1, 1.15, 0.5), false))
		var iris := MeshInstance3D.new(); iris.mesh = Toon.sphere(0.14)
		iris.material_override = Toon.glow(eye, 2.2); iris.scale = Vector3(1, 1.15, 0.45); iris.position.z = -0.03
		e.add_child(iris)
		e.add_child(Toon.part(Toon.box(Vector3(0.045, 0.22, 0.02)), Color(0.02, 0.02, 0.03), Vector3(0, 0, -0.1), Vector3.ONE, false))
		var hl := MeshInstance3D.new(); hl.mesh = Toon.sphere(0.045); hl.material_override = Toon.glow(Color.WHITE, 4.0)
		hl.position = Vector3(0.05 * sx, 0.07, -0.11); e.add_child(hl)
		for i in 3:   # whiskers
			var w := Toon.part(Toon.box(Vector3(0.42, 0.012, 0.012)), Color(0.95, 0.95, 0.95), Vector3(0.42 * sx, -0.2 + 0.05 * i, -0.45), Vector3.ONE, false)
			w.rotation.z = (0.18 - 0.12 * i) * sx
			_head.add_child(w)
	_head.add_child(Toon.part(Toon.sphere(0.06), Color(0.95, 0.5, 0.6), Vector3(0, -0.12, -0.6), Vector3(1.3, 0.9, 1), false))
	# Legs (pivot at hip), short and stubby.
	for p in [Vector3(-0.28, 0.0, -0.38), Vector3(0.28, 0.0, -0.38), Vector3(-0.28, 0.0, 0.38), Vector3(0.28, 0.0, 0.38)]:
		var hip := Node3D.new(); hip.position = p + Vector3(0, -0.15, 0); _body.add_child(hip)
		hip.add_child(Toon.part(Toon.capsule(0.13, 0.5), fur, Vector3(0, -0.22, 0)))
		hip.add_child(Toon.part(Toon.sphere(0.14), belly, Vector3(0, -0.45, -0.04), Vector3(1, 0.7, 1.2)))
		_legs.append(hip)
	# Tail: chain of beads, each child of the previous so a sine wave curls it.
	var parent: Node3D = _body
	var off := Vector3(0, 0.15, 0.62)
	for i in 7:
		var seg := Node3D.new(); seg.position = off; parent.add_child(seg)
		var r := 0.12 - i * 0.008
		seg.add_child(Toon.part(Toon.sphere(r), stripe if i % 2 == 1 or i == 6 else fur, Vector3.ZERO, Vector3.ONE, i == 0))
		_tail.append(seg)
		parent = seg
		off = Vector3(0, 0.12, 0.13)

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
	_cool = maxf(0.0, _cool - dt)
	if move.length() > 0.05:
		_dir = _dir.slerp(move.normalized(), 1.0 - exp(-14.0 * dt)).normalized()
	if _pounce_t > 0.0:
		_pounce_t -= dt
		var dash := pounce_dist / 0.22
		velocity = _dir * dash
		if _pounce_t <= 0.0:
			_squash = -0.35   # landing squash
	else:
		var target := move.limit_length(1.0) * speed
		velocity = velocity.lerp(target, 1.0 - exp(-12.0 * dt))
	velocity.y = 0.0
	move_and_slide()
	if bounds.is_valid():
		global_position = bounds.call(global_position)
	_animate(dt)

func try_pounce() -> void:
	if _cool > 0.0 or _pounce_t > 0.0:
		return
	_pounce_t = 0.22
	_cool = pounce_cd
	_squash = 0.4
	pounced.emit()

func _ai(dt: float) -> Vector3:
	# Kitten: chase the nearest mouse, pounce when close; wander otherwise.
	_ai_t -= dt
	if swarm:
		var t = swarm.nearest(global_position, 18.0)
		if t != null:
			var to: Vector3 = t - global_position; to.y = 0
			if to.length() < pounce_dist * 0.8 and _cool <= 0.0:
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
	var run01 := clampf(sp / maxf(speed, 0.1), 0.0, 1.5)
	_phase += dt * (3.0 + sp * 1.6)
	_rig.rotation.y = lerp_angle(_rig.rotation.y, atan2(-_dir.x, -_dir.z), 1.0 - exp(-16.0 * dt))
	# legs: diagonal pairs (trot), amplitude by speed
	for i in _legs.size():
		var off := 0.0 if i in [0, 3] else PI
		_legs[i].rotation.x = sin(_phase + off) * 0.7 * minf(run01, 1.0)
	# body bob + squash/stretch
	_squash = move_toward(_squash, 0.0, dt * 2.2)
	var bob := absf(sin(_phase)) * 0.08 * minf(run01, 1.0)
	var breathe := sin(Time.get_ticks_msec() * 0.003) * 0.02 * (1.0 - minf(run01, 1.0))
	var s := 1.0 + _squash
	if is_pouncing():
		s = 1.0 - 0.25   # stretched long and low while flying
		_body.scale = Vector3(0.9, 0.8, 1.35)
	else:
		_body.scale = Vector3(1.0 / sqrt(s) + breathe, s + breathe, 1.0 / sqrt(s))
	_body.position.y = 0.55 + bob
	_head.rotation.x = -0.08 * minf(run01, 1.0) + sin(Time.get_ticks_msec() * 0.002) * 0.04
	_head.rotation.z = sin(Time.get_ticks_msec() * 0.0013) * 0.06 * (1.0 - minf(run01, 1.0))
	var t := Time.get_ticks_msec() * 0.004
	for i in _tail.size():
		_tail[i].rotation.x = -0.25 + sin(t + i * 0.6) * 0.12
		_tail[i].rotation.y = sin(t * 1.3 + i * 0.5) * (0.18 + 0.1 * run01)
