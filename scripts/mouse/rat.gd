class_name Rat
extends CharacterBody3D
## Player: a house rat. Walks, runs, jumps, climbs rough surfaces, hides, carries small items.

const MODEL_PATH := "res://assets/models/polyhaven/street_rat/street_rat.gltf"
const MODEL_YAW := PI          ## Rotate the imported model so its nose points to -Z (Godot forward).

@export var walk_speed := 3.6
@export var run_speed := 8.8
@export var accel := 30.0
@export var gravity := 60.0
@export var jump_velocity := 14.0
@export var climb_speed := 3.2

var camera_rig: RatCamera
var exposure := 0.0
var hide_spots := 0
var carrying: Node3D = null
var climbing := false
var _climb_normal := Vector3.ZERO
var _model: Node3D
var _step_t := 0.0
var _exp_t := 0.0
var _anim_t := 0.0
var _was_on_floor := true
var _nearby_pickups: Array[Node] = []

func _ready() -> void:
	add_to_group("player")
	collision_layer = GameState.L_MOUSE
	collision_mask = GameState.L_WORLD
	floor_max_angle = deg_to_rad(50)
	floor_snap_length = 0.3
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.17
	cap.height = 1.1
	cs.shape = cap
	cs.rotation.x = PI / 2
	cs.position.y = 0.18
	add_child(cs)
	_model = Node3D.new()
	add_child(_model)
	var ps := load(MODEL_PATH) as PackedScene
	if ps:
		var m := ps.instantiate() as Node3D
		m.scale = Vector3.ONE * GameState.WORLD_SCALE
		m.rotation.y = MODEL_YAW
		_model.add_child(m)
	else:
		push_warning("rat model missing; using placeholder")
		var mi := MeshInstance3D.new()
		var cm := CapsuleMesh.new(); cm.radius = 0.17; cm.height = 1.1
		mi.mesh = cm; mi.rotation.x = PI / 2; mi.position.y = 0.18
		_model.add_child(mi)
	# Sensor for pickups / hide spots.
	var sensor := Area3D.new()
	sensor.collision_layer = 0
	sensor.collision_mask = GameState.L_HIDE
	var ss := CollisionShape3D.new(); var sph := SphereShape3D.new(); sph.radius = 0.9
	ss.shape = sph; ss.position.y = 0.2
	sensor.add_child(ss)
	add_child(sensor)
	sensor.area_entered.connect(_on_area_entered)
	sensor.area_exited.connect(_on_area_exited)
	camera_rig = RatCamera.new()
	camera_rig.target = self
	add_child.call_deferred(camera_rig)

func is_hidden() -> bool:
	return hide_spots > 0 and Vector2(velocity.x, velocity.z).length() < 1.0

func in_sanctuary() -> bool:
	for z in get_tree().get_nodes_in_group("incense_zone"):
		if z.has_method("contains") and z.contains(global_position):
			return true
	return false

func _physics_process(dt: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var running := Input.is_action_pressed("run")
	var speed := (run_speed if running else walk_speed) * (0.7 if carrying else 1.0)
	if climbing:
		_climb(dt, input)
	else:
		_ground(dt, input, speed)
	var pre_vel := velocity
	move_and_slide()
	if not climbing:
		_try_step_up(pre_vel)
	_check_start_climb(input)
	_footsteps(dt)
	_animate(dt)
	_exp_t -= dt
	if _exp_t <= 0.0:
		_exp_t = 0.15
		exposure = ExposureSampler.sample(get_world_3d(), global_position, get_tree(), [get_rid()])
	if Input.is_action_just_pressed("interact"):
		_interact()

func _ground(dt: float, input: Vector2, speed: float) -> void:
	var basis_y := Basis(Vector3.UP, camera_rig.yaw if camera_rig else 0.0)
	var dir := basis_y * Vector3(input.x, 0, input.y)
	var hv := Vector3(velocity.x, 0, velocity.z).move_toward(dir * speed, accel * dt)
	velocity.x = hv.x
	velocity.z = hv.z
	if not is_on_floor():
		velocity.y -= gravity * dt
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity
	if dir.length() > 0.1:
		var target_yaw := atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-12.0 * dt))
	up_direction = Vector3.UP
	if is_on_floor() and not _was_on_floor:
		NoiseBus.emit_noise(global_position, 6.0 * _surface_mult(), self)
	_was_on_floor = is_on_floor()

const STEP_HEIGHT := 0.75   ## ~7 cm: thresholds of porches and brick edges

## A rat pops up over low ledges without jumping.
func _try_step_up(pre_vel: Vector3) -> void:
	var hv := Vector3(pre_vel.x, 0, pre_vel.z)
	if not is_on_floor() or not is_on_wall() or hv.length() < 0.5:
		return
	var fwd := hv.normalized() * 0.25
	var t := global_transform
	if test_move(t, Vector3.UP * STEP_HEIGHT):
		return  # no headroom
	t.origin += Vector3.UP * STEP_HEIGHT
	if test_move(t, fwd):
		return  # still blocked: it's a real wall
	t.origin += fwd
	var col := KinematicCollision3D.new()
	if test_move(t, Vector3.DOWN * STEP_HEIGHT, col):
		global_position = t.origin + col.get_travel()

func _check_start_climb(input: Vector2) -> void:
	if climbing or input.y > -0.3:
		return
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var col := c.get_collider() as CollisionObject3D
		if col and (col.collision_layer & GameState.L_CLIMB) != 0 and absf(c.get_normal().y) < 0.4:
			climbing = true
			_climb_normal = c.get_normal()
			velocity = Vector3.ZERO
			return

func _climb(dt: float, input: Vector2) -> void:
	var tangent := _climb_normal.cross(Vector3.UP).normalized()
	velocity = (Vector3.UP * -input.y + tangent * -input.x) * climb_speed - _climb_normal * 1.5
	# Face up the wall: model's forward (-Z) points up, belly against the wall.
	var b := Basis.looking_at(Vector3.UP, _climb_normal)
	global_basis = global_basis.slerp(b, 1.0 - exp(-10.0 * dt))
	if Input.is_action_just_pressed("jump"):
		_stop_climb()
		velocity = _climb_normal * 6.0 + Vector3.UP * 6.0
		return
	# Still touching a climbable wall?
	var q := PhysicsRayQueryParameters3D.create(global_position + _climb_normal * 0.1, global_position - _climb_normal * 0.8, GameState.L_CLIMB)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		# Reached the top edge: hop over onto the surface.
		_stop_climb()
		velocity = Vector3.UP * 7.0 - _climb_normal * 4.0
	else:
		_climb_normal = _climb_normal.lerp(hit.normal, 0.3).normalized()
	if is_on_floor() and input.y > 0.3:
		_stop_climb()

func _stop_climb() -> void:
	climbing = false
	var yaw := rotation.y
	global_basis = Basis(Vector3.UP, yaw)

func _surface_mult() -> float:
	var col: Object = null
	if is_on_floor():
		for i in get_slide_collision_count():
			var c := get_slide_collision(i)
			if c.get_normal().y > 0.5:
				col = c.get_collider()
				break
	if col and col.has_meta("snd"):
		return {"straw": 1.6, "wood": 1.25, "earth": 0.6, "shard": 2.2, "brick": 0.9}.get(col.get_meta("snd"), 1.0)
	return 1.0

func _footsteps(dt: float) -> void:
	var sp := velocity.length()
	if sp < 0.5:
		return
	_step_t -= dt * sp
	if _step_t <= 0.0:
		_step_t = 1.2
		var loud := (2.5 if sp < 5.0 else 9.0) * _surface_mult()
		NoiseBus.emit_noise(global_position, loud, self)

func _animate(dt: float) -> void:
	# M1 placeholder motion until the rig lands: bound-gait bob and pitch.
	var sp := Vector2(velocity.x, velocity.z).length() if not climbing else velocity.length()
	_anim_t += dt * (4.0 + sp * 2.2)
	var amp := clampf(sp / run_speed, 0.0, 1.0)
	_model.position.y = absf(sin(_anim_t)) * 0.08 * amp
	_model.rotation.x = sin(_anim_t * 2.0) * 0.08 * amp
	if sp < 0.3:  # idle sniff
		_model.rotation.x = sin(Time.get_ticks_msec() * 0.012) * 0.02

func _on_area_entered(a: Area3D) -> void:
	if a.is_in_group("hide_spot"):
		hide_spots += 1
	if a.is_in_group("pickup"):
		_nearby_pickups.append(a)

func _on_area_exited(a: Area3D) -> void:
	if a.is_in_group("hide_spot"):
		hide_spots = maxi(0, hide_spots - 1)
	_nearby_pickups.erase(a)

## What pressing E would do right now (for the HUD prompt). Empty = nothing.
func interact_hint() -> String:
	if carrying == null and not _nearby_pickups.is_empty():
		return "[E] Ngậm %s" % _nearby_pickups[0].get_meta("label", "đồ vật")
	if carrying:
		for d in get_tree().get_nodes_in_group("dropzone"):
			if d.global_position.distance_to(global_position) < 3.0:
				return "[E] Đặt %s vào bát hương" % carrying.get_meta("label", "đồ vật")
		return "[E] Nhả %s" % carrying.get_meta("label", "đồ vật")
	return ""

func _interact() -> void:
	if carrying == null and not _nearby_pickups.is_empty():
		var p := _nearby_pickups[0] as Node3D
		carrying = p
		_nearby_pickups.erase(p)
		p.reparent(self)
		p.position = Vector3(0, 0.25, -0.75)
		p.rotation = Vector3.ZERO
		GameState.collect(p.get_meta("item_id", p.name))
		GameState.objective_changed.emit("Mang %s tới bát hương trên bàn thờ." % p.get_meta("label", "đồ vật"))
		NoiseBus.emit_noise(global_position, 3.0, self)
	elif carrying:
		for d in get_tree().get_nodes_in_group("dropzone"):
			if d.global_position.distance_to(global_position) < 3.0 and d.has_method("deliver"):
				d.deliver(carrying)
				carrying = null
				return
		carrying.reparent(get_parent())
		carrying.global_position = global_position + Vector3(0, 0.1, 0)
		carrying = null

func respawn(at: Transform3D) -> void:
	climbing = false
	velocity = Vector3.ZERO
	global_transform = at
