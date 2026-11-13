class_name Pickup
extends Area3D
## Small carryable item (matchbox, incense bundle, water cup). Remembers where it started.

@export var item_id := "item"
var home_parent: Node
var home_xform: Transform3D

func setup(id: String, size: Vector3, color: Color) -> void:
	item_id = id
	name = id
	set_meta("item_id", id)
	collision_layer = GameState.L_HIDE
	collision_mask = 0
	add_to_group("pickup")
	add_to_group("pickup_reset")
	var cs := CollisionShape3D.new(); var sh := SphereShape3D.new(); sh.radius = 0.7
	cs.shape = sh; add_child(cs)
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size
	var m := StandardMaterial3D.new(); m.albedo_color = color; m.roughness = 0.8
	mi.mesh = bm; mi.material_override = m; add_child(mi)

func _ready() -> void:
	home_parent = get_parent()
	home_xform = global_transform

func reset() -> void:
	if get_parent() != home_parent:
		reparent(home_parent)
	global_transform = home_xform
	monitorable = true
