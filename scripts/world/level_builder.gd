class_name LevelBuilder
extends RefCounted
## Helpers to assemble graybox geometry in code (M1). Every solid becomes a StaticBody3D
## parented under the NavigationRegion3D so the cat's navmesh is baked from it.

var root: Node3D
var mats := {}

func _init(parent: Node3D) -> void:
	root = parent

func mat(name: String, color: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	if not mats.has(name):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = rough
		m.metallic = metal
		mats[name] = m
	return mats[name]

func box(name: String, size: Vector3, pos: Vector3, m: Material, layer := GameState.L_WORLD, snd := "", rot_y := 0.0) -> StaticBody3D:
	var b := _body(name, pos, layer, snd)
	b.rotation.y = rot_y
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = size
	mi.mesh = bm; mi.material_override = m
	b.add_child(mi)
	var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = size
	cs.shape = sh; b.add_child(cs)
	return b

func cylinder(name: String, radius: float, height: float, pos: Vector3, m: Material, layer := GameState.L_WORLD, snd := "", top_radius := -1.0) -> StaticBody3D:
	var b := _body(name, pos, layer, snd)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = radius; cm.top_radius = radius if top_radius < 0.0 else top_radius
	cm.height = height; cm.radial_segments = 32
	mi.mesh = cm; mi.material_override = m; mi.position.y = height / 2
	b.add_child(mi)
	var cs := CollisionShape3D.new(); var sh := CylinderShape3D.new()
	sh.radius = maxf(radius, cm.top_radius); sh.height = height
	cs.shape = sh; cs.position.y = height / 2
	b.add_child(cs)
	return b

func invisible_wall(name: String, size: Vector3, pos: Vector3, layer: int) -> StaticBody3D:
	var b := _body(name, pos, layer, "")
	var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = size
	cs.shape = sh; b.add_child(cs)
	return b

func _body(name: String, pos: Vector3, layer: int, snd: String) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = name
	b.collision_layer = layer
	b.collision_mask = 0
	b.position = pos
	if snd != "":
		b.set_meta("snd", snd)
	root.add_child(b)
	return b

func area(name: String, size: Vector3, pos: Vector3, group: String, layer := GameState.L_HIDE) -> Area3D:
	var a := Area3D.new()
	a.name = name
	a.collision_layer = layer
	a.collision_mask = 0
	a.monitorable = true
	a.position = pos
	var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = size
	cs.shape = sh; a.add_child(cs)
	a.add_to_group(group)
	_world().add_child(a)
	return a

func omni(name: String, pos: Vector3, color: Color, energy: float, rng: float, shadows := true, flicker := "") -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = name
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.6
	l.shadow_enabled = shadows
	l.light_volumetric_fog_energy = 1.5
	_world().add_child(l)
	l.add_to_group("game_lights")
	if flicker != "":
		var f := LightFlicker.new(); f.mode = flicker; l.add_child(f)
	return l

func _world() -> Node:
	return root.get_parent() if root.get_parent() else root
