class_name Hud
extends CanvasLayer
## Subtitles for the rhyme, a quiet objective line, fade for capture, FPS counter (F3),
## and the full-screen grain/vignette/heartbeat post-process.

const POST_SHADER := preload("res://scripts/shaders/post_grain_vignette.gdshader")
var subtitle: Label
var objective: Label
var fps: Label
var fade: ColorRect
var post: ColorRect
var fading := false
var prompt: Label
var controls: Label
var _controls_t := 25.0
var version: Label
var _restart_armed := false
var _post_mat: ShaderMaterial

func _ready() -> void:
	add_to_group("hud")
	post = ColorRect.new()
	post.set_anchors_preset(Control.PRESET_FULL_RECT)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post_mat = ShaderMaterial.new(); _post_mat.shader = POST_SHADER
	post.material = _post_mat
	add_child(post)
	subtitle = _label(Vector2(0.5, 0.86), 30, HORIZONTAL_ALIGNMENT_CENTER)
	subtitle.add_theme_color_override("font_color", Color(0.92, 0.88, 0.8, 0.85))
	objective = _label(Vector2(0.03, 0.05), 20, HORIZONTAL_ALIGNMENT_LEFT)
	objective.add_theme_color_override("font_color", Color(0.75, 0.72, 0.66, 0.7))
	fps = _label(Vector2(0.92, 0.03), 16, HORIZONTAL_ALIGNMENT_LEFT)
	fps.visible = false
	prompt = _label(Vector2(0.5, 0.62), 26, HORIZONTAL_ALIGNMENT_CENTER)
	prompt.add_theme_color_override("font_color", Color(1.0, 0.93, 0.78, 0.95))
	controls = _label(Vector2(0.03, 0.72), 18, HORIZONTAL_ALIGNMENT_LEFT)
	controls.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75, 0.85))
	controls.text = "W A S D — đi      Chuột — nhìn      Shift — chạy (ồn)\nSpace — nhảy      E — ngậm / đặt đồ      − / = — độ sáng      F9 — cập nhật\nĐi thẳng vào cột, chân sập, tủ chè, dây thừng để leo\nĐứng yên dưới gầm sập, sau chum, trong ổ rơm để nấp      Esc — thả chuột máy tính"
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	Director.rhyme_line.connect(func(t): subtitle.text = ("“%s”" % t) if t != "" else "")
	GameState.objective_changed.connect(func(t): objective.text = t)
	version = _label(Vector2(0.9, 0.965), 14, HORIZONTAL_ALIGNMENT_LEFT)
	version.add_theme_color_override("font_color", Color(0.7, 0.68, 0.62, 0.5))
	version.text = "%s   F9: cập nhật" % Updater.version_label()
	Updater.status.connect(func(t): _flash(t, 4.0))
	Updater.update_ready.connect(func(_r): _restart_armed = true)
	Updater.check_for_updates(true)
	GameState.brightness_changed.connect(func(v): _flash("Độ sáng: %d%%" % roundi(v * 100)))

func _label(anchor: Vector2, size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.anchor_left = anchor.x; l.anchor_right = anchor.x
	l.anchor_top = anchor.y; l.anchor_bottom = anchor.y
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		l.anchor_left = 0.1; l.anchor_right = 0.9
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	add_child(l)
	return l

func _process(_dt: float) -> void:
	if Input.is_action_just_pressed("update_game"):
		if _restart_armed:
			Updater.restart()
		else:
			Updater.check_for_updates()
	if Input.is_action_just_pressed("toggle_fps"):
		fps.visible = not fps.visible
	if fps.visible:
		fps.text = "%d fps" % Engine.get_frames_per_second()
	var rat := get_tree().get_first_node_in_group("player") as Rat
	var fear := Director.menace
	if rat:
		fear = maxf(fear, rat.exposure * 0.6)
		prompt.text = rat.interact_hint()
	if _controls_t > 0.0:
		_controls_t -= _dt
		controls.modulate.a = clampf(_controls_t / 3.0, 0.0, 1.0)
	_post_mat.set_shader_parameter("fear", fear)
	_post_mat.set_shader_parameter("time_s", Time.get_ticks_msec() / 1000.0)

func fade_out(msg := "") -> void:
	fading = true
	subtitle.text = msg
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.8)
	await tw.finished
	await get_tree().create_timer(1.6).timeout

func fade_in() -> void:
	subtitle.text = ""
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 0.0, 1.2)
	await tw.finished
	fading = false

func show_ending() -> void:
	subtitle.text = "Bản thử M1 — hết. (Cảm ơn bạn đã chơi.)"

func _flash(t: String, secs := 1.5) -> void:
	subtitle.text = t
	await get_tree().create_timer(secs).timeout
	if subtitle.text == t:
		subtitle.text = ""
