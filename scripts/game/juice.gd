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
