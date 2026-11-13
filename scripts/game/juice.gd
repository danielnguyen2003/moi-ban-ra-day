class_name Juice
extends RefCounted
## Feedback effects: rising number popups and little dust/sparkle bursts.

const FONT := preload("res://assets/fonts/google/bevietnampro/BeVietnamPro-ExtraBold.ttf")

static func popup(parent: Node3D, at: Vector3, text: String, color := Color.WHITE) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = FONT
	l.font_size = 96
	l.outline_size = 28
	l.pixel_size = 0.006
	l.modulate = color
	l.outline_modulate = Color(0.1, 0.05, 0.15)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 10
	parent.add_child(l)
	l.global_position = at
	l.scale = Vector3.ONE * 0.4
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "global_position", at + Vector3(0, 1.6, 0), 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.6)
	tw.chain().tween_callback(l.queue_free)

static func burst(parent: Node3D, at: Vector3, color: Color) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = 14
	p.lifetime = 0.5
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, -9, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var s := SphereMesh.new(); s.radius = 0.07; s.height = 0.14; s.radial_segments = 6; s.rings = 3
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color.lightened(0.3); m.emission_enabled = true; m.emission = color; m.emission_energy_multiplier = 2.0
	s.material = m
	p.mesh = s
	parent.add_child(p)
	p.global_position = at + Vector3(0, 0.3, 0)
	p.emitting = true
	p.get_tree().create_timer(1.0).timeout.connect(p.queue_free)

## A little dried fish pops out of a caught mouse, spins, and vanishes.
static func fish(parent: Node3D, at: Vector3) -> void:
	var f := Node3D.new()
	f.add_child(Toon.part(Toon.sphere(0.22), Color(0.95, 0.75, 0.4), Vector3.ZERO, Vector3(0.5, 0.8, 1.6)))
	var tail := Toon.part(Toon.cone(0.2, 0.3, 4), Color(0.9, 0.65, 0.35), Vector3(0, 0, 0.42))
	tail.rotation.x = PI / 2; f.add_child(tail)
	var eye := MeshInstance3D.new(); eye.mesh = Toon.sphere(0.04); eye.material_override = Toon.glow(Color(0.1, 0.1, 0.1), 0.0)
	eye.position = Vector3(0.1, 0.05, -0.2); f.add_child(eye)
	parent.add_child(f)
	f.global_position = at + Vector3(0, 0.4, 0)
	var tw := f.create_tween().set_parallel(true)
	tw.tween_property(f, "global_position", at + Vector3(randf_range(-0.6, 0.6), 2.2, randf_range(-0.6, 0.6)), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(f, "rotation", Vector3(0, TAU * 1.5, 0.6), 0.55)
	tw.tween_property(f, "scale", Vector3.ONE * 0.05, 0.2).set_delay(0.45)
	tw.chain().tween_callback(f.queue_free)

## Landing dust puff: a ring of soft grey blobs that expand and fade.
static func dust(parent: Node3D, at: Vector3) -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.75, 0.72, 0.85, 0.55)
	for k in 7:
		var a := k * TAU / 7.0 + randf() * 0.3
		var b := MeshInstance3D.new(); b.mesh = Toon.sphere(0.18, 6, 8); b.material_override = m
		parent.add_child(b)
		b.global_position = at + Vector3(0, 0.15, 0)
		var tw := b.create_tween().set_parallel(true)
		tw.tween_property(b, "global_position", at + Vector3(cos(a) * 1.0, 0.3, sin(a) * 1.0), 0.35).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "scale", Vector3.ONE * 1.8, 0.35)
		tw.tween_property(b, "transparency", 1.0, 0.35)
		tw.chain().tween_callback(b.queue_free)

## Shockwave ring on the ground.
static func ring(parent: Node3D, at: Vector3, r: float) -> void:
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new(); t.inner_radius = 0.85; t.outer_radius = 1.0; t.rings = 32; t.ring_segments = 6
	mi.mesh = t
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.7, 0.9, 1.0, 0.8); m.emission_enabled = true; m.emission = Color(0.6, 0.85, 1.0); m.emission_energy_multiplier = 2.0
	mi.material_override = m
	parent.add_child(mi)
	mi.global_position = at + Vector3(0, 0.1, 0)
	mi.scale = Vector3(0.2, 0.2, 0.2)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(r, 0.3, r), 0.25).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "transparency", 1.0, 0.3)
	tw.chain().tween_callback(mi.queue_free)
