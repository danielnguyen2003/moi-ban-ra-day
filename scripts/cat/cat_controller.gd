class_name CatController
extends CharacterBody3D
## The cat that is no longer a cat. Body + senses + navigation; decisions come from CatBrain.

const MODEL_PATH := "res://assets/models/sketchfab/cat_walk_orange/cat_muop.glb"
const BODY_LENGTH := 4.6        ## 46 cm nose-to-rump at WORLD_SCALE 10
@export var model_yaw := 0.0
@export var view_range := 42.0
@export var view_half_angle := 65.0
@export var catch_distance := 2.3

var brain := CatBrain.new()
var rat: Rat
var agent: NavigationAgent3D
var gravity := 60.0
var vigil_point := Vector3.ZERO
var vigil_look := Vector3.ZERO
var _model: Node3D
var _anim: AnimationPlayer
var _heard_strength := 0.0
var _heard_pos := Vector3.ZERO
var _search_near_hide_t := 0.0
var _eyes: Array[MeshInstance3D] = []
var _eye_mat: StandardMaterial3D
var _head_offset := Vector3(0, 2.0, -2.0)

signal state_changed(state: int)

func _ready() -> void:
	add_to_group("cat")
	collision_layer = GameState.L_CAT
	collision_mask = GameState.L_WORLD | GameState.L_CAT_BLOCKER
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new(); cap.radius = 0.9; cap.height = BODY_LENGTH
	cs.shape = cap; cs.rotation.x = PI / 2; cs.position.y = 1.2
	add_child(cs)
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 1.0
	agent.target_desired_distance = 1.5
	agent.radius = 1.2
	agent.height = 2.6
	add_child(agent)
	_build_model()
	NoiseBus.noise_emitted.connect(_on_noise)

func _build_model() -> void:
	_model = Node3D.new(); add_child(_model)
	var ps := load(MODEL_PATH) as PackedScene
	if ps == null:
		push_warning("cat model missing")
		return
	var visible_cat := ps.instantiate() as Node3D
	_model.add_child(visible_cat)
	_fit(visible_cat)
	_set_shadow(visible_cat, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	_anim = _find_anim(visible_cat)
	# The "wrong" shadow: an invisible stretched twin that only casts shadows.
	var twin := ps.instantiate() as Node3D
	_model.add_child(twin)
	_fit(twin)
	twin.scale *= Vector3(0.85, 1.75, 1.3)
	twin.position.y -= 0.2
	_set_shadow(twin, GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
	var twin_anim := _find_anim(twin)
	if twin_anim and twin_anim.get_animation_list().size() > 0:
		twin_anim.play(twin_anim.get_animation_list()[0])
		twin_anim.speed_scale = 0.6   # out of sync with the body: subtly wrong
	_build_eyes()

func _fit(n: Node3D) -> void:
	n.rotation.y = model_yaw
	var aabb := _mesh_aabb(n)
	var length := maxf(aabb.size.z, aabb.size.x)
	if length > 0.0:
		n.scale = Vector3.ONE * (BODY_LENGTH / length)
		aabb = _mesh_aabb(n)
		n.position.y -= aabb.position.y
		_head_offset = Vector3(0, aabb.size.y * 0.82, aabb.position.z * 0.92)

func _mesh_aabb(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var t := global_transform.affine_inverse() * m.global_transform if is_inside_tree() else _rel(m, n)
		var a := t * m.get_aabb()
		out = a if first else out.merge(a)
		first = false
	return out

func _rel(m: Node3D, root: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = m
	while cur and cur != self:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t

func _set_shadow(n: Node, mode: GeometryInstance3D.ShadowCastingSetting) -> void:
	for gi in n.find_children("*", "GeometryInstance3D", true, false):
		(gi as GeometryInstance3D).cast_shadow = mode

func _find_anim(n: Node) -> AnimationPlayer:
	var a := n.find_children("*", "AnimationPlayer", true, false)
	return a[0] if not a.is_empty() else null

func _build_eyes() -> void:
	# Tapetum lucidum: eyes flare when the viewer is near the light->eye axis.
	_eye_mat = StandardMaterial3D.new()
	_eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_eye_mat.albedo_color = Color(0.0, 0.0, 0.0)
	_eye_mat.emission_enabled = true
	_eye_mat.emission = Color(0.75, 0.95, 0.55)
	_eye_mat.emission_energy_multiplier = 0.0
	for side in [-1.0, 1.0]:
		var e := MeshInstance3D.new()
		var s := SphereMesh.new(); s.radius = 0.07; s.height = 0.12
		e.mesh = s
		e.material_override = _eye_mat
		e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		e.position = _head_offset + Vector3(side * 0.2, 0.0, 0.0)
		_model.add_child(e)
		_eyes.append(e)

func set_patrol(points: Array[Vector3]) -> void:
	brain.set_patrol(points)

func _on_noise(pos: Vector3, loudness: float, _src: Node) -> void:
	var walls := 0
	var q := PhysicsRayQueryParameters3D.create(_head(), pos + Vector3.UP * 0.3, GameState.L_WORLD)
	if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
		walls = 1
	var s := NoiseBus.perceived(pos, loudness, global_position, walls)
	if s > _heard_strength:
		_heard_strength = s
		_heard_pos = pos

func _head() -> Vector3:
	return global_transform * _head_offset

func _sees_rat() -> bool:
	if rat == null:
		return false
	var to := rat.global_position + Vector3.UP * 0.25 - _head()
	if to.length() > view_range:
		return false
	var fwd := -global_basis.z
	if rad_to_deg(fwd.angle_to(to.normalized())) > view_half_angle:
		return false
	var q := PhysicsRayQueryParameters3D.create(_head(), rat.global_position + Vector3.UP * 0.25, GameState.L_WORLD)
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func _physics_process(dt: float) -> void:
	var p := CatBrain.Perception.new()
	p.rhyme_singing = Director.rhyme_singing
	if rat:
		p.sees_rat = _sees_rat()
		p.rat_exposure = rat.exposure
		p.rat_hidden = rat.is_hidden()
		p.rat_pos = rat.global_position
		p.rat_in_sanctuary = rat.in_sanctuary()
		p.dist_to_rat = global_position.distance_to(rat.global_position)
	p.heard_strength = _heard_strength
	p.heard_pos = _heard_pos
	p.reached_target = agent.is_navigation_finished()
	_heard_strength = 0.0
	var prev := brain.state
	var st := brain.tick(dt, p)
	if st != prev:
		state_changed.emit(st)
	Director.report_cat_state(st, p.dist_to_rat)

	var speed := CatBrain.speed_for(st)
	var goal := vigil_point if st == CatBrain.State.VIGIL else brain.target
	agent.target_position = goal
	var hv := Vector3.ZERO
	if speed > 0.0 and not agent.is_navigation_finished():
		var nxt := agent.get_next_path_position()
		hv = (nxt - global_position)
		hv.y = 0
		hv = hv.normalized() * speed
	velocity.x = move_toward(velocity.x, hv.x, 25.0 * dt)
	velocity.z = move_toward(velocity.z, hv.z, 25.0 * dt)
	velocity.y = 0.0 if is_on_floor() else velocity.y - gravity * dt
	move_and_slide()
	var flat := Vector3(velocity.x, 0, velocity.z)
	var look_dir := flat
	if st == CatBrain.State.VIGIL and global_position.distance_to(vigil_point) < 2.0:
		look_dir = vigil_look - global_position
	elif st == CatBrain.State.CHASE and rat:
		look_dir = rat.global_position - global_position
	look_dir.y = 0
	if look_dir.length() > 0.2:
		rotation.y = lerp_angle(rotation.y, atan2(-look_dir.x, -look_dir.z), 1.0 - exp(-6.0 * dt))
	_update_anim(flat.length())
	_update_eyes()
	_check_catch(st, p)

func _update_anim(sp: float) -> void:
	if _anim == null or _anim.get_animation_list().is_empty():
		return
	var name := _anim.get_animation_list()[0]
	if not _anim.is_playing():
		_anim.play(name)
		_anim.get_animation(name).loop_mode = Animation.LOOP_LINEAR
	_anim.speed_scale = clampf(sp / 3.2, 0.0, 2.6)

func _update_eyes() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _eyes.is_empty():
		return
	var eye := _eyes[0].global_position
	var to_cam := (cam.global_position - eye).normalized()
	var best := 0.0
	for l in get_tree().get_nodes_in_group("game_lights"):
		var light := l as Light3D
		if light and light.visible and light.light_energy > 0.05:
			var to_light := (light.global_position - eye).normalized()
			best = maxf(best, to_cam.dot(to_light) * light.light_energy)
	_eye_mat.emission_energy_multiplier = clampf((best - 0.55) * 6.0, 0.0, 4.0)

func _check_catch(st: int, p: CatBrain.Perception) -> void:
	if rat == null or p.rat_in_sanctuary:
		return
	if p.dist_to_rat < catch_distance and not p.rat_hidden and st in [CatBrain.State.CHASE, CatBrain.State.STALK]:
		GameState.player_caught.emit()
	# Paw reach into shallow hide spots while searching close by.
	if p.rat_hidden and st == CatBrain.State.SEARCH and p.dist_to_rat < 3.5:
		_search_near_hide_t += get_physics_process_delta_time()
		if _search_near_hide_t > 4.0 and _rat_spot_is_shallow():
			GameState.player_caught.emit()
	else:
		_search_near_hide_t = 0.0

func _rat_spot_is_shallow() -> bool:
	for h in get_tree().get_nodes_in_group("hide_spot"):
		var a := h as Area3D
		if a and a.get_meta("shallow", false) and a.global_position.distance_to(rat.global_position) < 2.0:
			return true
	return false

func teleport(t: Transform3D) -> void:
	global_transform = t
	velocity = Vector3.ZERO
	var pts := brain._patrol_points
	brain = CatBrain.new()
	brain.set_patrol(pts)
