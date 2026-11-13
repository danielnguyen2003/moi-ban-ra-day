class_name IncenseZone
extends Node3D
## A burning incense stick: while lit the cat cannot enter a radius around the altar.
## The physical barrier is a cylinder on the cat-blocker layer, so the cat's navmesh is not rebaked.

@export var radius := 9.0
@export var burn_seconds := 90.0
var lit := false
var remaining := 0.0
var _barrier: StaticBody3D
var _ember: OmniLight3D

signal burned_out

func _ready() -> void:
	add_to_group("incense_zone")
	_barrier = StaticBody3D.new()
	_barrier.collision_layer = 0
	_barrier.collision_mask = 0
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new(); cyl.radius = radius; cyl.height = 12.0
	cs.shape = cyl; cs.position.y = 6.0
	_barrier.add_child(cs)
	add_child(_barrier)

func light_up(ember: OmniLight3D = null) -> void:
	lit = true
	remaining = burn_seconds
	_barrier.collision_layer = GameState.L_CAT_BLOCKER
	_ember = ember
	if _ember:
		_ember.visible = true

func _process(dt: float) -> void:
	if not lit:
		return
	remaining -= dt
	if _ember:
		_ember.light_energy = 0.6 * clampf(remaining / burn_seconds, 0.2, 1.0)
	if remaining <= 0.0:
		lit = false
		_barrier.collision_layer = 0
		if _ember:
			_ember.visible = false
		burned_out.emit()

func contains(p: Vector3) -> bool:
	if not lit:
		return false
	var d := Vector2(p.x - global_position.x, p.z - global_position.z)
	return d.length() < radius
