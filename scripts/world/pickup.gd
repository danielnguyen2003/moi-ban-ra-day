class_name Pickup
extends Area3D
## Small carryable item (matchbox, incense bundle, water cup). Remembers where it started.

@export var item_id := "item"
var home_parent: Node
var home_xform: Transform3D

func setup(id: String, size: Vector3, color: Color, label := "") -> void:
	item_id = id
	name = id
	set_meta("item_id", id)
	set_meta("label", label if label != "" else id)
	collision_layer = GameState.L_HIDE
	collision_mask = 0
	add_to_group("pickup")
	add_to_group("pickup_reset")
	var cs := CollisionShape3D.new(); var sh := SphereShape3D.new(); sh.radius = 1.3
	cs.shape = sh; add_child(cs)
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size
	var m := StandardMaterial3D.new(); m.albedo_color = color; m.roughness = 0.8
	mi.mesh = bm; mi.material_override = m; add_child(mi)
	# A faint glint so the item reads in the dark (pulses gently).
	_glint = OmniLight3D.new()
	_glint.light_color = Color(1.0, 0.85, 0.6)
	_glint.light_energy = 0.25
	_glint.omni_range = 1.4
	_glint.shadow_enabled = false
	_glint.position = Vector3(0, 0.4, 0)
	add_child(_glint)

var _glint: OmniLight3D

func _process(_dt: float) -> void:
	if _glint:
		_glint.visible = get_parent() == home_parent
		_glint.light_energy = 0.18 + 0.12 * sin(Time.get_ticks_msec() * 0.003)

func _ready() -> void:
	home_parent = get_parent()
	home_xform = global_transform

func reset() -> void:
	if get_parent() != home_parent:
		reparent(home_parent)
	global_transform = home_xform
	monitorable = true
