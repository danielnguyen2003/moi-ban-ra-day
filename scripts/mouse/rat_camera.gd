class_name RatCamera
extends Node3D
## Close third-person camera with collision (SpringArm3D). Stays world-upright even while the rat climbs.

var target: Node3D
var yaw := 0.0
var pitch := deg_to_rad(-12.0)
var sensitivity := 0.0025
var shake := 0.0
var arm: SpringArm3D
var cam: Camera3D

func _ready() -> void:
	top_level = true
	arm = SpringArm3D.new()
	arm.spring_length = 3.4
	arm.margin = 0.15
	arm.collision_mask = GameState.L_WORLD
	var s := SphereShape3D.new(); s.radius = 0.12
	arm.shape = s
	add_child(arm)
	cam = Camera3D.new()
	cam.fov = 72.0
	cam.near = 0.03
	cam.far = 400.0
	arm.add_child(cam)
	cam.current = true
	if target is CollisionObject3D:
		arm.add_excluded_object((target as CollisionObject3D).get_rid())
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= e.relative.x * sensitivity
		pitch = clampf(pitch - e.relative.y * sensitivity, deg_to_rad(-70), deg_to_rad(35))
	elif e.is_action_pressed("ui_cancel_game"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

func _process(dt: float) -> void:
	if target == null:
		return
	var goal := target.global_position + Vector3.UP * 0.75
	global_position = global_position.lerp(goal, 1.0 - exp(-14.0 * dt))
	rotation = Vector3(pitch, yaw, 0.0)
	shake = maxf(0.0, shake - dt)
	if shake > 0.0:
		cam.h_offset = randf_range(-1, 1) * 0.04 * shake
		cam.v_offset = randf_range(-1, 1) * 0.04 * shake
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0
