class_name RiceField
extends Node3D
## XP pickups: glowing rice grains dropped by mice, pulled to the cat inside the magnet radius.

signal collected(value: float)

const CAP := 3000
var pos := PackedVector3Array()
var val := PackedFloat32Array()
var pulled := PackedByteArray()
var player: Node3D
var magnet := 2.0
var _mm: MultiMesh

func _ready() -> void:
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	var cap := CapsuleMesh.new(); cap.radius = 0.07; cap.height = 0.26; cap.radial_segments = 8; cap.rings = 2
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.emission_enabled = true; m.emission = Color(1.0, 0.95, 0.75); m.emission_energy_multiplier = 1.6
	cap.material = m
	_mm.mesh = cap
	_mm.instance_count = CAP
	_mm.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new(); mi.multimesh = _mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-300, -5, -300), Vector3(600, 20, 600))
	add_child(mi)

func clear() -> void:
	pos.clear(); val.clear(); pulled.clear()
	_mm.visible_instance_count = 0

func drop(at: Vector3, value: float) -> void:
	# merge into a nearby grain when crowded, so late-game hordes don't blow the cap
	if pos.size() >= CAP - 10:
		var j := randi() % pos.size()
		val[j] += value
		return
	pos.append(Vector3(at.x + randf_range(-0.3, 0.3), 0.25, at.z + randf_range(-0.3, 0.3)))
	val.append(value)
	pulled.append(0)

## Vacuum every grain to the cat (chest / boss reward).
func pull_all() -> void:
	for i in pulled.size():
		pulled[i] = 1

func _physics_process(dt: float) -> void:
	if player == null:
		return
	var c := player.global_position
	var i := 0
	while i < pos.size():
		var p := pos[i]
		var off := Vector3(c.x - p.x, 0, c.z - p.z)
		var d := off.length()
		if pulled[i] == 0 and d < magnet:
			pulled[i] = 1
		if pulled[i] == 1:
			var sp := 10.0 + 25.0 * clampf(1.0 - d / maxf(magnet, 1.0), 0.0, 1.0)
			p += off.normalized() * minf(sp * dt, d)
			pos[i] = p
		if d < 0.5:
			collected.emit(val[i])
			var last := pos.size() - 1
			pos[i] = pos[last]; pos.resize(last)
			val[i] = val[last]; val.resize(last)
			pulled[i] = pulled[last]; pulled.resize(last)
			continue
		i += 1
	_mm.visible_instance_count = pos.size()
	var t := Time.get_ticks_msec() * 0.003
	for k in pos.size():
		var b := Basis(Vector3.UP, t + k).rotated(Vector3.RIGHT, PI / 2)
		var big := val[k] >= 5.0
		b = b.scaled(Vector3.ONE * (1.6 if big else 1.0))
		_mm.set_instance_transform(k, Transform3D(b, pos[k] + Vector3(0, sin(t * 2.0 + k) * 0.06, 0)))
		_mm.set_instance_color(k, Color(1.0, 0.85, 0.35) if big else Color(1.0, 0.98, 0.9))
