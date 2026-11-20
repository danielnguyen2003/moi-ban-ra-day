class_name Fx
extends RefCounted
## Reusable VFX (see design/art-direction.md "VFX budget"). Everything self-destructs.

const ADD := preload("res://scripts/shaders/vfx_add.gdshader")
static var budget := 0      ## reset each frame by the game; heavy effects check it

static func add_mat(color: Color, energy := 2.0, edge_soft := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new(); m.shader = ADD
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("energy", energy)
	m.set_shader_parameter("edge_soft", edge_soft)
	return m

static func _fade(node: Node3D, mat: ShaderMaterial, dur: float, grow := Vector3.ONE) -> void:
	var tw := node.create_tween().set_parallel(true)
	tw.tween_method(func(a): mat.set_shader_parameter("alpha", a), 1.0, 0.0, dur)
	tw.tween_property(node, "scale", node.scale * grow, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(node.queue_free)

static func _particles(parent: Node3D, at: Vector3, amount: int, color: Color, vmin: float, vmax: float, life: float,
		size: float, gravity := -9.0, spread := 70.0, dir := Vector3.UP, mesh: Mesh = null, emissive := 2.0) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true; p.emitting = false; p.amount = amount; p.lifetime = life; p.explosiveness = 0.95
	p.direction = dir; p.spread = spread
	p.initial_velocity_min = vmin; p.initial_velocity_max = vmax
	p.gravity = Vector3(0, gravity, 0)
	p.damping_min = 1.0; p.damping_max = 3.0
	p.scale_amount_min = 0.6; p.scale_amount_max = 1.3
	var curve := Curve.new(); curve.add_point(Vector2(0, 1)); curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	if mesh == null:
		var s := SphereMesh.new(); s.radius = size; s.height = size * 2.0; s.radial_segments = 6; s.rings = 3
		mesh = s
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color; m.emission_enabled = emissive > 0.0; m.emission = color; m.emission_energy_multiplier = emissive
	m.vertex_color_use_as_albedo = false
	mesh = mesh.duplicate(); mesh.surface_set_material(0, m)
	p.mesh = mesh
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	p.get_tree().create_timer(life + 0.3).timeout.connect(p.queue_free)
	return p

# ------------------------------------------------------------------ primitives
static func sparks(parent: Node3D, at: Vector3, color: Color, n := 10, speed := 6.0) -> void:
	var box := BoxMesh.new(); box.size = Vector3(0.04, 0.04, 0.22)
	var p := _particles(parent, at, n, color, speed * 0.5, speed, 0.35, 0.05, -4.0, 180.0, Vector3.UP, box, 3.0)
	p.particle_flag_align_y = true

static func smoke(parent: Node3D, at: Vector3, color := Color(0.55, 0.5, 0.65), n := 6, size := 0.35) -> void:
	var p := _particles(parent, at + Vector3(0, 0.3, 0), n, color, 0.6, 1.8, 0.8, size, 1.5, 60.0, Vector3.UP, null, 0.0)
	p.scale_amount_min = 1.0; p.scale_amount_max = 2.2

static func flash(parent: Node3D, at: Vector3, color: Color, energy := 4.0, rng := 6.0, dur := 0.15) -> void:
	var l := OmniLight3D.new(); l.light_color = color; l.light_energy = energy; l.omni_range = rng
	parent.add_child(l); l.global_position = at + Vector3(0, 1.0, 0)
	var tw := l.create_tween(); tw.tween_property(l, "light_energy", 0.0, dur); tw.tween_callback(l.queue_free)

static func ring(parent: Node3D, at: Vector3, r: float, color := Color(0.7, 0.9, 1.0), dur := 0.3) -> void:
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new(); t.inner_radius = 0.82; t.outer_radius = 1.0; t.rings = 40; t.ring_segments = 6
	mi.mesh = t
	var m := add_mat(color, 2.5); mi.material_override = m
	parent.add_child(mi)
	mi.global_position = at + Vector3(0, 0.12, 0)
	mi.scale = Vector3(0.25, 0.25, 0.25) * r
	_fade(mi, m, dur, Vector3(4.0, 1.0, 4.0))

static func fireball(parent: Node3D, at: Vector3, r: float) -> void:
	var core := MeshInstance3D.new(); core.mesh = Toon.sphere(1.0, 10, 14)
	var m := add_mat(Color(1.0, 0.55, 0.15), 3.0); core.material_override = m
	parent.add_child(core); core.global_position = at + Vector3(0, 0.6, 0)
	core.scale = Vector3.ONE * r * 0.3
	_fade(core, m, 0.28, Vector3.ONE * 3.0)
	var hot := MeshInstance3D.new(); hot.mesh = Toon.sphere(1.0, 8, 10)
	var m2 := add_mat(Color(1.0, 0.95, 0.7), 4.0); hot.material_override = m2
	parent.add_child(hot); hot.global_position = at + Vector3(0, 0.6, 0)
	hot.scale = Vector3.ONE * r * 0.15
	_fade(hot, m2, 0.18, Vector3.ONE * 3.0)

## Signature detail: red firecracker paper (xác pháo) fluttering down.
static func confetti(parent: Node3D, at: Vector3, n := 18) -> void:
	var q := QuadMesh.new(); q.size = Vector2(0.14, 0.09)
	var p := _particles(parent, at + Vector3(0, 0.5, 0), n, Color(0.92, 0.12, 0.1), 3.0, 7.0, 1.6, 0.05, -2.2, 75.0, Vector3.UP, q, 0.6)
	p.angular_velocity_min = -720.0; p.angular_velocity_max = 720.0
	p.damping_min = 2.0; p.damping_max = 4.0
	var curve := Curve.new(); curve.add_point(Vector2(0, 1)); curve.add_point(Vector2(0.8, 1)); curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	p.particle_flag_rotate_y = true
	(p.mesh.surface_get_material(0) as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED

static func dirt(parent: Node3D, at: Vector3, n := 7) -> void:
	_particles(parent, at + Vector3(0, 0.1, 0), n, Color(0.38, 0.28, 0.22), 2.0, 4.0, 0.45, 0.07, -14.0, 40.0, Vector3.UP, null, 0.0)

## Crescent slash: a curved additive ribbon sweeping `arc` radians around `dir`.
static func slash(parent: Node3D, at: Vector3, dir: Vector3, r: float, arc: float, color: Color, width := 0.5, dur := 0.18, tilt := 0.0) -> void:
	var im := ImmediateMesh.new()
	var segs := 20
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for k in segs + 1:
		var u := float(k) / segs
		var a := -arc * 0.5 + arc * u
		var w := width * sin(u * PI)              # thick in the middle, pointed tips
		var d := Vector3(sin(a), 0, -cos(a))
		im.surface_set_uv(Vector2(u, 0.0)); im.surface_add_vertex(d * (r - w))
		im.surface_set_uv(Vector2(u, 1.0)); im.surface_add_vertex(d * (r + w * 0.3) + Vector3(0, w * 0.2, 0))
	im.surface_end()
	var mi := MeshInstance3D.new(); mi.mesh = im
	var m := add_mat(color, 3.0, 1.0); mi.material_override = m
	parent.add_child(mi)
	mi.global_position = at + Vector3(0, 0.55, 0)
	mi.rotation = Vector3(tilt, atan2(-dir.x, -dir.z), 0)
	_fade(mi, m, dur, Vector3(1.15, 1.0, 1.15))

## The mouse's own mesh flips up, spins and shrinks into a puff.
static func death_flip(parent: Node3D, mesh: Mesh, mat: Material, at: Vector3, scale: float) -> void:
	var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = at
	mi.scale = Vector3.ONE * scale
	var side := randf_range(-1.0, 1.0)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "global_position", at + Vector3(side * 0.8, 1.6, 0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "rotation", Vector3(PI * 1.5, side * 2.0, side * 3.0), 0.4)
	tw.tween_property(mi, "scale", Vector3.ONE * scale * 0.05, 0.18).set_delay(0.25)
	tw.chain().tween_callback(func():
		smoke(parent, mi.global_position, Color(0.75, 0.72, 0.85), 4, 0.22)
		mi.queue_free())

static func beam(parent: Node3D, at: Vector3, color := Color(1.0, 0.85, 0.4)) -> void:
	var mi := MeshInstance3D.new(); mi.mesh = Toon.cyl(0.7, 1.1, 14.0, 20)
	var m := add_mat(color, 1.6); mi.material_override = m
	parent.add_child(mi); mi.global_position = at + Vector3(0, 7.0, 0)
	_fade(mi, m, 0.7, Vector3(0.2, 1.0, 0.2))
	sparks(parent, at + Vector3(0, 0.5, 0), color, 24, 8.0)
	ring(parent, at, 3.0, color, 0.5)

## Soft dark disc under characters so they sit on the ground.
static func blob_shadow(size := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := Toon.cyl(0.6, 0.6, 0.01, 24)
	mi.mesh = q
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.albedo_color = Color(0.02, 0.0, 0.05, 0.45)
	mi.material_override = m
	mi.scale = Vector3(size, 1, size)
	mi.position.y = 0.04
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## A ribbon trail that follows a node (ImmediateMesh, N points), fading toward the tail.
class Trail extends MeshInstance3D:
	var target: Node3D
	var points: Array[Vector3] = []
	var max_points := 14
	var width := 0.25
	var mat: ShaderMaterial
	func _init(t: Node3D, color: Color, w := 0.25, n := 14) -> void:
		target = t; width = w; max_points = n
		mesh = ImmediateMesh.new()
		mat = Fx.add_mat(color, 2.5, 1.0)
		material_override = mat
		top_level = true
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	func _process(_dt: float) -> void:
		if not is_instance_valid(target):
			queue_free(); return
		points.push_front(target.global_position)
		if points.size() > max_points: points.resize(max_points)
		var im: ImmediateMesh = mesh
		im.clear_surfaces()
		if points.size() < 2: return
		var cam := get_viewport().get_camera_3d()
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for k in points.size():
			var p: Vector3 = points[k]
			var nxt: Vector3 = points[mini(k + 1, points.size() - 1)]
			var fwd := (p - nxt); if fwd.length() < 0.001: fwd = Vector3.FORWARD
			var to_cam := (cam.global_position - p).normalized() if cam else Vector3.UP
			var side := fwd.cross(to_cam).normalized() * width * (1.0 - float(k) / points.size())
			var u := float(k) / (points.size() - 1)
			im.surface_set_uv(Vector2(u, 0)); im.surface_add_vertex(p - side)
			im.surface_set_uv(Vector2(u, 1)); im.surface_add_vertex(p + side)
		im.surface_end()
