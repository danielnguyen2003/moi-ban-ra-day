class_name RatKing
extends Node3D
## Chuột Chúa: a giant crowned rat. Walks at the cat, telegraphs a charge, summons a pack.

signal died(at: Vector3)
signal hp_changed(ratio: float)

var game
var max_hp := 1200.0
var hp := 1200.0
var speed := 3.0
var _state := "walk"
var _t := 3.0
var _summon_t := 6.0
var _charge_dir := Vector3.ZERO
var _flash := 0.0
var _rig: Node3D
var _body: MeshInstance3D
var _warn: MeshInstance3D
var _legs: Array[Node3D] = []
var _phase := 0.0
var dead := false

func setup(g, hp_: float) -> void:
	game = g
	max_hp = hp_; hp = hp_
	_build()

func _build() -> void:
	_rig = Node3D.new(); add_child(_rig)
	_rig.scale = Vector3.ONE * 3.2
	var fur := Color(0.36, 0.3, 0.32)
	_body = Toon.part(Toon.sphere(0.5), fur, Vector3(0, 0.55, 0.1), Vector3(1.0, 0.85, 1.35))
	_rig.add_child(_body)
	_rig.add_child(Toon.part(Toon.sphere(0.36), Color(0.75, 0.65, 0.62), Vector3(0, 0.45, -0.25), Vector3(1, 0.8, 1), false))
	var head := Node3D.new(); head.position = Vector3(0, 0.85, -0.55); _rig.add_child(head)
	head.add_child(Toon.part(Toon.sphere(0.38), fur, Vector3.ZERO, Vector3(1, 0.9, 1.2)))
	head.add_child(Toon.part(Toon.sphere(0.09), Color(0.95, 0.5, 0.6), Vector3(0, -0.05, -0.47)))
	for sx in [-1.0, 1.0]:
		head.add_child(Toon.part(Toon.sphere(0.2), fur, Vector3(0.28 * sx, 0.32, 0.05), Vector3(1, 1, 0.3)))
		head.add_child(Toon.part(Toon.sphere(0.13), Color(0.95, 0.6, 0.65), Vector3(0.28 * sx, 0.32, 0.0), Vector3(1, 1, 0.2), false))
		var e := MeshInstance3D.new(); e.mesh = Toon.sphere(0.07); e.material_override = Toon.glow(Color(1.0, 0.2, 0.1), 5.0)
		e.position = Vector3(0.15 * sx, 0.1, -0.33); head.add_child(e)
		# buck teeth
	head.add_child(Toon.part(Toon.box(Vector3(0.1, 0.1, 0.03)), Color(1, 0.97, 0.85), Vector3(0, -0.2, -0.43), Vector3.ONE, false))
	# crown (vương miện) of gold spikes
	var crown := Node3D.new(); crown.position = Vector3(0, 0.38, 0.0); head.add_child(crown)
	crown.add_child(Toon.part(Toon.cyl(0.24, 0.26, 0.1, 12), Color(1.0, 0.8, 0.25), Vector3.ZERO))
	for k in 5:
		var a := k * TAU / 5.0
		crown.add_child(Toon.part(Toon.cone(0.06, 0.18, 6), Color(1.0, 0.8, 0.25), Vector3(cos(a) * 0.22, 0.12, sin(a) * 0.22)))
	var gem := MeshInstance3D.new(); gem.mesh = Toon.sphere(0.05); gem.material_override = Toon.glow(Color(0.3, 0.9, 1.0), 4.0)
	gem.position = Vector3(0, 0.02, -0.25); crown.add_child(gem)
	# cape
	_rig.add_child(Toon.part(Toon.box(Vector3(0.9, 0.05, 0.9)), Color(0.6, 0.1, 0.15), Vector3(0, 0.95, 0.35), Vector3.ONE, true))
	for p in [Vector3(-0.3, 0, -0.35), Vector3(0.3, 0, -0.35), Vector3(-0.3, 0, 0.45), Vector3(0.3, 0, 0.45)]:
		var hip := Node3D.new(); hip.position = p + Vector3(0, 0.4, 0); _rig.add_child(hip)
		hip.add_child(Toon.part(Toon.capsule(0.1, 0.4), fur, Vector3(0, -0.2, 0)))
		_legs.append(hip)
	var tail_prev: Node3D = _rig
	for k in 6:
		var seg := Toon.part(Toon.sphere(0.06), Color(0.85, 0.55, 0.6), Vector3(0, 0.45 - k * 0.04, 0.8 + k * 0.15) if k == 0 else Vector3(0, 0.02, 0.15), Vector3.ONE, false)
		tail_prev.add_child(seg); tail_prev = seg
	# charge telegraph
	_warn = MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(2.2, 0.05, 14.0); _warn.mesh = bm
	var wm := StandardMaterial3D.new(); wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; wm.albedo_color = Color(1, 0.15, 0.1, 0.35)
	_warn.material_override = wm; _warn.visible = false
	add_child(_warn)

func try_hit(center: Vector3, r: float, dmg: float) -> bool:
	if dead:
		return false
	var d := Vector2(center.x - global_position.x, center.z - global_position.z).length()
	if d < r + 1.6:
		hp -= dmg
		_flash = 1.0
		hp_changed.emit(hp / max_hp)
		if hp <= 0.0:
			dead = true
			died.emit(global_position)
			queue_free()
		return true
	return false

func _physics_process(dt: float) -> void:
	if dead or game == null or game.player == null or get_tree().paused:
		return
	var c: Vector3 = game.player.global_position
	var to := c - global_position; to.y = 0
	_t -= dt
	_summon_t -= dt
	_flash = maxf(0.0, _flash - dt * 5.0)
	_body.scale = Vector3(1.0, 0.85, 1.35) * (1.0 + 0.12 * _flash)
	match _state:
		"walk":
			global_position += to.normalized() * speed * dt
			_face(to)
			if _t <= 0.0 and to.length() < 16.0:
				_state = "aim"; _t = 0.9
				_charge_dir = to.normalized()
				_warn.visible = true
				game.sfx.play("whoosh", 0.0, 0.5)
		"aim":
			_face(_charge_dir)
			_warn.global_position = global_position + _charge_dir * 7.0 + Vector3(0, 0.05, 0)
			_warn.look_at(_warn.global_position + _charge_dir, Vector3.UP)
			_rig.position.y = -0.2   # crouch
			if _t <= 0.0:
				_state = "charge"; _t = 0.6; _warn.visible = false; _rig.position.y = 0.0
		"charge":
			global_position += _charge_dir * 22.0 * dt
			if _t <= 0.0:
				_state = "walk"; _t = randf_range(2.5, 4.0)
				game.shake(0.3)
	global_position = game.village.clamp_inside(global_position)
	if _summon_t <= 0.0:
		_summon_t = 7.0
		for k in 10:
			var a := k * TAU / 10.0
			game.swarm.spawn(MiceSwarm.Kind.CONG, global_position + Vector3(cos(a), 0, sin(a)) * 2.5)
	if to.length() < 2.2:
		game.on_bite(2)
	_phase += dt * (8.0 if _state != "aim" else 0.0) * (2.5 if _state == "charge" else 1.0)
	for i in _legs.size():
		_legs[i].rotation.x = sin(_phase + (0.0 if i in [0, 3] else PI)) * 0.6

func _face(dir: Vector3) -> void:
	if dir.length() > 0.01:
		_rig.rotation.y = lerp_angle(_rig.rotation.y, atan2(-dir.x, -dir.z), 0.2)
