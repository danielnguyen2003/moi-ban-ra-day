class_name GameUI
extends CanvasLayer
## All screens: title, select (cats + stages), HUD, level-up cards, pause, result, meta shop.

signal play_pressed
signal start_run_pressed
signal card_picked(i: int)
signal reroll_pressed
signal result_done
signal shop_pressed
signal shop_back
signal resume_pressed
signal quit_run_pressed

const F_REG := preload("res://assets/fonts/google/bevietnampro/BeVietnamPro-Regular.ttf")
const F_SEMI := preload("res://assets/fonts/google/bevietnampro/BeVietnamPro-SemiBold.ttf")
const F_BOLD := preload("res://assets/fonts/google/bevietnampro/BeVietnamPro-ExtraBold.ttf")
const GOLD := Color(1.0, 0.8, 0.4)
const INK := Color(0.07, 0.05, 0.14)
const PANEL := Color(0.11, 0.09, 0.22, 0.94)
const TYPE_COL := {"weapon": Color(1.0, 0.62, 0.3), "passive": Color(0.45, 0.75, 1.0), "evo": Color(1.0, 0.85, 0.3), "heal": Color(0.5, 0.95, 0.6), "fish": Color(0.5, 0.95, 0.6)}

var theme_: Theme
var root: Control
var screens := {}
var toast: Label
var _banner: Label
var _hurt: ColorRect
# hud
var _hearts: HBoxContainer
var _lives_l: Label
var _xp: ProgressBar
var _lvl_l: Label
var _time_l: Label
var _kills_l: Label
var _fish_l: Label
var _boss: ProgressBar
var _boss_l: Label
var _pounce_bar: ProgressBar
# dynamic containers
var _cards: HBoxContainer
var _lvl_title: Label
var _reroll_b: Button
var _sel_chars: GridContainer
var _sel_stages: VBoxContainer
var _sel_fish: Label
var _res_box: VBoxContainer
var _shop_grid: GridContainer
var _shop_fish: Label
var _restart_armed := false

func _ready() -> void:
	theme_ = _make_theme()
	root = Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.theme = theme_
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_hurt = ColorRect.new(); _hurt.color = Color(0.8, 0.05, 0.05, 0.0); _hurt.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hurt.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(_hurt)
	_build_hud(); _build_title(); _build_select(); _build_levelup(); _build_pause(); _build_result(); _build_shop()
	_banner = _lbl("", 44, F_BOLD, Color(1.0, 0.88, 0.6))
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP); _banner.position.y = 150
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(_banner)
	toast = _lbl("", 22, F_SEMI, Color(1, 0.95, 0.85))
	toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM); toast.position.y -= 90
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(toast)
	var version := _lbl("%s   ·   F9 cập nhật" % Updater.version_label(), 13, F_REG, Color(0.8, 0.78, 0.9, 0.55))
	version.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT); version.position += Vector2(-260, -26)
	root.add_child(version)
	Updater.status.connect(func(t): _toast(t, 4.0))
	Updater.update_ready.connect(func(_r): _restart_armed = true)
	Updater.check_for_updates(true)
	Progress.brightness_changed.connect(func(v): _toast("Độ sáng: %d%%" % roundi(v * 100)))
	Progress.changed.connect(_refresh_dynamic)

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("update_game"):
		if _restart_armed: Updater.restart()
		else: Updater.check_for_updates()
	if screens.levelup.visible:
		for k in 3:
			if e.is_action_pressed("pick_%d" % (k + 1)):
				card_picked.emit(k); get_viewport().set_input_as_handled()
		if e.is_action_pressed("reroll"):
			reroll_pressed.emit()
	elif screens.pause.visible and e.is_action_pressed("pause"):
		resume_pressed.emit(); get_viewport().set_input_as_handled()

# ------------------------------------------------------------------ helpers
func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = F_SEMI
	t.default_font_size = 20
	var panel := StyleBoxFlat.new()
	panel.bg_color = PANEL; panel.set_corner_radius_all(22); panel.set_border_width_all(2)
	panel.border_color = Color(GOLD, 0.45); panel.shadow_color = Color(0, 0, 0, 0.45); panel.shadow_size = 18
	panel.set_content_margin_all(20)
	t.set_stylebox("panel", "PanelContainer", panel)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var b := StyleBoxFlat.new()
		b.set_corner_radius_all(16); b.set_content_margin_all(10)
		b.content_margin_left = 20; b.content_margin_right = 20
		match st:
			"normal": b.bg_color = Color(0.95, 0.6, 0.25)
			"hover": b.bg_color = Color(1.0, 0.72, 0.35)
			"pressed": b.bg_color = Color(0.85, 0.5, 0.2)
			"disabled": b.bg_color = Color(0.3, 0.27, 0.4)
			"focus": b.bg_color = Color(0, 0, 0, 0); b.set_border_width_all(2); b.border_color = Color(1, 1, 1, 0.6)
		b.shadow_color = Color(0, 0, 0, 0.35); b.shadow_size = 6 if st != "pressed" else 2
		t.set_stylebox(st, "Button", b)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(0.65, 0.62, 0.75))
	t.set_font("font", "Button", F_BOLD)
	var bar_bg := StyleBoxFlat.new(); bar_bg.bg_color = Color(0.05, 0.04, 0.1, 0.8); bar_bg.set_corner_radius_all(8)
	var bar_fg := StyleBoxFlat.new(); bar_fg.bg_color = Color(0.45, 0.85, 1.0); bar_fg.set_corner_radius_all(8)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fg)
	return t

func _lbl(text: String, size: int, font: Font, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.add_theme_constant_override("shadow_offset_x", 0)
	return l

func _btn(text: String, cb: Callable, size := 22) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(func(): _pop(b); cb.call())
	b.mouse_entered.connect(func(): b.pivot_offset = b.size / 2; b.create_tween().tween_property(b, "scale", Vector2.ONE * 1.04, 0.08))
	b.mouse_exited.connect(func(): b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.1))
	return b

func _pop(c: Control) -> void:
	c.pivot_offset = c.size / 2
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2.ONE * 0.94, 0.05)
	tw.tween_property(c, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	get_parent().sfx.play("click", -4.0)

func _screen(name: String, dim := 0.6) -> Control:
	var s := Control.new(); s.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE if dim <= 0.0 else Control.MOUSE_FILTER_STOP
	if dim > 0.0:
		var shade := ColorRect.new(); shade.color = Color(0.02, 0.01, 0.06, dim); shade.set_anchors_preset(Control.PRESET_FULL_RECT)
		s.add_child(shade)
	root.add_child(s)
	screens[name] = s
	s.visible = false
	return s

func _show(names: Array) -> void:
	for n in screens:
		var on: bool = n in names
		if on and not screens[n].visible:
			screens[n].modulate.a = 0.0
			screens[n].create_tween().tween_property(screens[n], "modulate:a", 1.0, 0.2)
		screens[n].visible = on

func _vcenter(parent: Control, sep := 14) -> VBoxContainer:
	var v := VBoxContainer.new(); v.set_anchors_preset(Control.PRESET_CENTER)
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH; v.grow_vertical = Control.GROW_DIRECTION_BOTH
	v.alignment = BoxContainer.ALIGNMENT_CENTER; v.add_theme_constant_override("separation", sep)
	parent.add_child(v)
	return v

func _toast(t: String, secs := 1.6) -> void:
	toast.text = t; toast.modulate.a = 1.0
	var tw := toast.create_tween(); tw.tween_interval(secs); tw.tween_property(toast, "modulate:a", 0.0, 0.4)

func banner(t: String) -> void:
	_banner.text = t
	_banner.pivot_offset = _banner.size / 2
	_banner.modulate.a = 1.0; _banner.scale = Vector2.ONE * 1.3
	var tw := _banner.create_tween()
	tw.tween_property(_banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(2.0); tw.tween_property(_banner, "modulate:a", 0.0, 0.5)

func hurt() -> void:
	_hurt.color.a = 0.35
	_hurt.create_tween().tween_property(_hurt, "color:a", 0.0, 0.4)

func _refresh_dynamic() -> void:
	if screens.select.visible: _fill_select()
	if screens.shop.visible: _fill_shop()

# ------------------------------------------------------------------ title
func _build_title() -> void:
	var s := _screen("title", 0.5)
	var v := _vcenter(s)
	var t1 := _lbl("Mời Bạn Ra Đây", 92, F_BOLD, Color(1.0, 0.88, 0.6)); t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var t2 := _lbl("Mèo săn chuột đêm rằm  ·  sống sót 5 phút, hạ Chuột Chúa", 26, F_SEMI, Color(0.8, 0.85, 1.0)); t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t1); v.add_child(t2)
	var sp := Control.new(); sp.custom_minimum_size.y = 24; v.add_child(sp)
	var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_btn("Chơi", func(): play_pressed.emit(), 32))
	v.add_child(row)
	var t3 := _lbl("WASD chạy  ·  Space/chuột trái vồ  ·  vũ khí tự đánh  ·  1/2/3 chọn thẻ", 18, F_REG, Color(0.85, 0.82, 0.95, 0.8))
	t3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(t3)

func show_title() -> void:
	_show(["title"])

# ------------------------------------------------------------------ select
func _build_select() -> void:
	var s := _screen("select", 0.55)
	var v := VBoxContainer.new(); v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 50; v.offset_right = -50; v.offset_top = 30; v.offset_bottom = -30
	v.add_theme_constant_override("separation", 14); s.add_child(v)
	var head := HBoxContainer.new()
	head.add_child(_lbl("Chọn mèo & đêm săn", 42, F_BOLD, Color(1.0, 0.88, 0.6)))
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(sp)
	_sel_fish = _lbl("", 30, F_BOLD, GOLD); head.add_child(_sel_fish)
	v.add_child(head)
	var body := HBoxContainer.new(); body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24); v.add_child(body)
	_sel_chars = GridContainer.new(); _sel_chars.columns = 4
	_sel_chars.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _sel_chars.size_flags_stretch_ratio = 2.2
	_sel_chars.add_theme_constant_override("h_separation", 12); _sel_chars.add_theme_constant_override("v_separation", 12)
	body.add_child(_sel_chars)
	_sel_stages = VBoxContainer.new(); _sel_stages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sel_stages.add_theme_constant_override("separation", 10)
	body.add_child(_sel_stages)
	var foot := HBoxContainer.new(); foot.alignment = BoxContainer.ALIGNMENT_END; foot.add_theme_constant_override("separation", 16)
	foot.add_child(_btn("Nâng cấp vĩnh viễn", func(): shop_pressed.emit(), 24))
	foot.add_child(_btn("Bắt đầu đêm săn  ›", func(): start_run_pressed.emit(), 30))
	v.add_child(foot)

func show_select() -> void:
	_fill_select()
	_show(["select"])

func _fill_select() -> void:
	_sel_fish.text = "Cá khô  " + BigNum.fmt(Progress.fish)
	for c in _sel_chars.get_children(): c.queue_free()
	for id in RunDefs.CHARACTERS:
		var ch: Dictionary = RunDefs.CHARACTERS[id]
		var owned: bool = id in Progress.chars_owned
		var sel: bool = Progress.character == id
		var label := "Đang chọn" if sel else ("Chọn" if owned else "Mở · %s cá" % BigNum.fmt(ch.cost))
		var desc := "Vũ khí: %s\nBiệt tài: %s" % [RunDefs.WEAPONS[ch.weapon].name, ch.perk_desc]
		_sel_chars.add_child(_card(Upgrades.SKINS[ch.skin].name, desc, "", not sel and (owned or Progress.fish >= ch.cost),
			func(): Progress.buy_or_select_char(id), label, TYPE_COL.weapon if sel else Color(0, 0, 0, 0), 230))
	for c in _sel_stages.get_children(): c.queue_free()
	_sel_stages.add_child(_lbl("Đêm săn" + ("   ·   Đêm rằm +%d" % Progress.heat if Progress.heat > 0 else ""), 26, F_BOLD, Color(0.8, 0.88, 1.0)))
	for i in RunDefs.STAGES.size():
		var st: Dictionary = RunDefs.STAGES[i]
		var open := i < Progress.stages_open
		var b: Dictionary = Progress.best.get("%d:%d" % [i, Progress.heat], {})
		var info := "Khóa: hạ Chuột Chúa ở màn trước" if not open else ("Đã thắng · %d chuột" % b.kills if b.get("won", false) else ("Kỷ lục %d:%02d · %d chuột" % [int(b.time) / 60, int(b.time) % 60, b.kills] if b.has("time") else "Chưa săn"))
		var btn := _btn("%d. %s" % [i + 1, st.name], func(): Progress.select_stage(i), 20)
		btn.disabled = not open
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if Progress.stage == i:
			btn.add_theme_stylebox_override("normal", _flat(Color(1.0, 0.82, 0.4)))
		var row := VBoxContainer.new(); row.add_child(btn)
		row.add_child(_lbl("   " + info + "   ·   cá ×%s" % str(st.fish), 15, F_REG, Color(0.85, 0.83, 0.95, 0.8)))
		_sel_stages.add_child(row)

func _flat(c: Color) -> StyleBoxFlat:
	var b := StyleBoxFlat.new(); b.bg_color = c; b.set_corner_radius_all(16); b.set_content_margin_all(10)
	b.content_margin_left = 20; b.content_margin_right = 20
	return b

func _card(name: String, desc: String, tag: String, enabled: bool, cb: Callable, btn_text: String, border := Color(0, 0, 0, 0), min_h := 160) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(250, min_h)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if border.a > 0.0:
		var sb := (theme_.get_stylebox("panel", "PanelContainer") as StyleBoxFlat).duplicate()
		sb.border_color = border; sb.set_border_width_all(3)
		p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 6); p.add_child(v)
	var top := HBoxContainer.new()
	top.add_child(_lbl(name, 22, F_BOLD, Color(1, 0.95, 0.85)))
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(sp)
	if tag != "":
		top.add_child(_lbl(tag, 15, F_SEMI, Color(0.75, 0.8, 1.0, 0.85)))
	v.add_child(top)
	var d := _lbl(desc, 15, F_REG, Color(0.85, 0.83, 0.95, 0.85)); d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(d)
	var b := _btn(btn_text, cb, 18)
	b.disabled = not enabled
	v.add_child(b)
	return p

# ------------------------------------------------------------------ hud
func _build_hud() -> void:
	var s := _screen("hud", 0.0)
	_xp = ProgressBar.new(); _xp.show_percentage = false
	_xp.set_anchors_preset(Control.PRESET_TOP_WIDE); _xp.offset_left = 0; _xp.offset_right = 0; _xp.offset_bottom = 14
	s.add_child(_xp)
	_lvl_l = _lbl("Cấp 1", 18, F_BOLD, Color(0.8, 0.95, 1.0)); _lvl_l.position = Vector2(14, 16); s.add_child(_lvl_l)
	var left := VBoxContainer.new(); left.position = Vector2(24, 48); s.add_child(left)
	_hearts = HBoxContainer.new(); _hearts.add_theme_constant_override("separation", 5); left.add_child(_hearts)
	_lives_l = _lbl("", 15, F_SEMI, Color(1, 0.75, 0.75, 0.85)); left.add_child(_lives_l)
	_fish_l = _lbl("", 26, F_BOLD, GOLD); left.add_child(_fish_l)
	_time_l = _lbl("00:00", 40, F_BOLD, Color(0.9, 0.93, 1.0))
	_time_l.set_anchors_preset(Control.PRESET_CENTER_TOP); _time_l.position.y = 20
	_time_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _time_l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	s.add_child(_time_l)
	_kills_l = _lbl("0", 30, F_BOLD, Color(0.9, 0.95, 1.0))
	_kills_l.set_anchors_preset(Control.PRESET_TOP_RIGHT); _kills_l.position += Vector2(-220, 24)
	s.add_child(_kills_l)
	_boss = ProgressBar.new(); _boss.show_percentage = false; _boss.custom_minimum_size = Vector2(700, 22)
	_boss.set_anchors_preset(Control.PRESET_CENTER_TOP); _boss.position += Vector2(-350, 100); _boss.visible = false
	var bf := StyleBoxFlat.new(); bf.bg_color = Color(0.9, 0.2, 0.25); bf.set_corner_radius_all(8)
	_boss.add_theme_stylebox_override("fill", bf)
	s.add_child(_boss)
	_boss_l = _lbl("Chuột Chúa", 20, F_BOLD, Color(1, 0.7, 0.65)); _boss_l.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss_l.position += Vector2(-60, 72); _boss_l.visible = false; s.add_child(_boss_l)
	_pounce_bar = ProgressBar.new(); _pounce_bar.show_percentage = false; _pounce_bar.custom_minimum_size = Vector2(160, 10)
	_pounce_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM); _pounce_bar.position += Vector2(-80, -40)
	s.add_child(_pounce_bar)

func show_hud() -> void:
	_show(["hud"])

func update_hud(d: Dictionary) -> void:
	var tt: float = d.t
	_time_l.text = "%02d:%02d" % [int(tt) / 60, int(tt) % 60] if not d.boss else "BOSS"
	_xp.value = 100.0 * d.xp
	_lvl_l.text = "Cấp %d" % d.level
	_kills_l.text = "%s chuột" % BigNum.fmt(d.kills)
	_fish_l.text = "Cá khô " + BigNum.fmt(d.fish)
	_lives_l.text = "Mạng %d/%d" % [d.lives, d.max_lives]
	_pounce_bar.value = 100.0 * (1.0 - d.cool)
	if _hearts.get_child_count() != d.max_lives:
		for c in _hearts.get_children(): c.queue_free()
		for k in d.max_lives:
			var h := Panel.new(); h.custom_minimum_size = Vector2(18, 18)
			_hearts.add_child(h)
	for k in _hearts.get_child_count():
		var sb := StyleBoxFlat.new(); sb.set_corner_radius_all(9)
		sb.bg_color = Color(1.0, 0.35, 0.4) if k < d.lives else Color(0.2, 0.15, 0.25, 0.8)
		sb.set_border_width_all(2); sb.border_color = Color(0.08, 0.04, 0.1)
		_hearts.get_child(k).add_theme_stylebox_override("panel", sb)
	_boss.visible = d.boss; _boss_l.visible = d.boss

func boss_bar(ratio: float) -> void:
	_boss.value = 100.0 * ratio

# ------------------------------------------------------------------ level-up
func _build_levelup() -> void:
	var s := _screen("levelup", 0.55)
	var v := _vcenter(s, 22)
	_lvl_title = _lbl("Lên cấp!", 56, F_BOLD, Color(1.0, 0.88, 0.6)); _lvl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_lvl_title)
	_cards = HBoxContainer.new(); _cards.alignment = BoxContainer.ALIGNMENT_CENTER; _cards.add_theme_constant_override("separation", 22)
	v.add_child(_cards)
	var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_CENTER
	_reroll_b = _btn("Đổi thẻ (R)", func(): reroll_pressed.emit(), 20); row.add_child(_reroll_b)
	v.add_child(row)

func show_levelup(offers: Array, rerolls: int, level: int) -> void:
	_lvl_title.text = "Lên cấp %d!" % level
	for c in _cards.get_children(): c.queue_free()
	for i in offers.size():
		var o: Dictionary = offers[i]
		var col: Color = TYPE_COL[o.type]
		var tag := "Tiến hóa!" if o.type == "evo" else ("Mới!" if o.lv == 1 else ("Cấp %d" % o.lv if o.lv > 0 else ""))
		var kind: String = {"weapon": "Vũ khí", "passive": "Chỉ số", "evo": "Tiến hóa", "heal": "Hồi phục", "fish": "Phần thưởng"}[o.type]
		var card := _card(o.name, kind + "\n" + o.desc, tag, true, func(): card_picked.emit(i), "Chọn  [%d]" % (i + 1), col, 260)
		card.custom_minimum_size = Vector2(330, 260)
		_cards.add_child(card)
		card.modulate.a = 0.0
		card.create_tween().tween_property(card, "modulate:a", 1.0, 0.15).set_delay(0.05 * i)
	_reroll_b.text = "Đổi thẻ (R)  ×%d" % rerolls
	_reroll_b.disabled = rerolls <= 0
	_show(["hud", "levelup"])

# ------------------------------------------------------------------ pause
func _build_pause() -> void:
	var s := _screen("pause", 0.6)
	var v := _vcenter(s)
	var t := _lbl("Tạm dừng", 56, F_BOLD, Color(1.0, 0.88, 0.6)); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(_btn("Tiếp tục (Esc)", func(): resume_pressed.emit(), 26))
	v.add_child(_btn("Bỏ đêm này", func(): quit_run_pressed.emit(), 22))

func show_pause() -> void:
	_show(["hud", "pause"])

# ------------------------------------------------------------------ result
func _build_result() -> void:
	var s := _screen("result", 0.6)
	var p := PanelContainer.new(); p.set_anchors_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH; p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.custom_minimum_size = Vector2(560, 0); s.add_child(p)
	_res_box = VBoxContainer.new(); _res_box.add_theme_constant_override("separation", 12); p.add_child(_res_box)

func show_result(d: Dictionary) -> void:
	for c in _res_box.get_children(): c.queue_free()
	var h := _lbl("Hạ Chuột Chúa!" if d.won else "Trời sáng mất rồi…", 42, F_BOLD, Color(1.0, 0.88, 0.6))
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _res_box.add_child(h)
	var tt: float = d.t
	_res_box.add_child(_lbl("Sống sót   %02d:%02d" % [int(tt) / 60, int(tt) % 60], 28, F_SEMI))
	_res_box.add_child(_lbl("Bắt được   %s chuột  ·  cấp %d" % [BigNum.fmt(d.kills), d.level], 28, F_SEMI))
	_res_box.add_child(_lbl("Cá khô     +%s%s" % [BigNum.fmt(d.fish), "  (thưởng thắng +50%)" if d.won else ""], 28, F_SEMI, GOLD))
	if d.unlocked:
		_res_box.add_child(_lbl("Mở khóa: " + ("màn mới!" if Progress.stages_open <= RunDefs.STAGES.size() and Progress.heat == 0 else "Đêm rằm +%d!" % Progress.heat), 26, F_BOLD, Color(0.55, 1.0, 0.7)))
	_res_box.add_child(_btn("Tiếp tục", func(): result_done.emit(), 26))
	_show(["result"])

# ------------------------------------------------------------------ shop (meta)
func _build_shop() -> void:
	var s := _screen("shop", 0.7)
	var v := VBoxContainer.new(); v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 60; v.offset_right = -60; v.offset_top = 36; v.offset_bottom = -36
	v.add_theme_constant_override("separation", 16); s.add_child(v)
	var head := HBoxContainer.new()
	head.add_child(_lbl("Nâng cấp vĩnh viễn", 44, F_BOLD, Color(1.0, 0.88, 0.6)))
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(sp)
	_shop_fish = _lbl("", 32, F_BOLD, GOLD); head.add_child(_shop_fish)
	v.add_child(head)
	_shop_grid = GridContainer.new(); _shop_grid.columns = 3
	_shop_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shop_grid.add_theme_constant_override("h_separation", 16); _shop_grid.add_theme_constant_override("v_separation", 16)
	v.add_child(_shop_grid)
	var foot := HBoxContainer.new(); foot.alignment = BoxContainer.ALIGNMENT_END
	foot.add_child(_btn("‹  Quay lại", func(): shop_back.emit(), 26)); v.add_child(foot)

func show_shop() -> void:
	_fill_shop()
	_show(["shop"])

func _fill_shop() -> void:
	_shop_fish.text = "Cá khô  " + BigNum.fmt(Progress.fish)
	for c in _shop_grid.get_children(): c.queue_free()
	for id in RunDefs.META:
		var d: Dictionary = RunDefs.META[id]
		var cost := RunDefs.meta_cost(id, Progress.mlv(id))
		_shop_grid.add_child(_card(d.name, d.desc, "Cấp %d" % Progress.mlv(id), Progress.fish >= cost,
			func():
				if Progress.buy_meta(id): get_parent().sfx.play("coin", -2.0),
			"Mua  ·  %s cá" % BigNum.fmt(cost)))
