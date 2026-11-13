class_name GameUI
extends CanvasLayer
## Title, in-night HUD, end-of-night summary and the upgrade shop. Theme built in code.

signal start_pressed
signal next_pressed
signal night_pressed
signal area_bought

const F_REG := preload("res://assets/fonts/google/bevietnampro/BeVietnamPro-Regular.ttf")
const F_SEMI := preload("res://assets/fonts/google/bevietnampro/BeVietnamPro-SemiBold.ttf")
const F_BOLD := preload("res://assets/fonts/google/bevietnampro/BeVietnamPro-ExtraBold.ttf")
const GOLD := Color(1.0, 0.8, 0.4)
const INK := Color(0.07, 0.05, 0.14)
const PANEL := Color(0.11, 0.09, 0.22, 0.94)

var theme_: Theme
var root: Control
var title: Control
var hud: Control
var summary: Control
var shop: Control
var toast: Label
var version: Label
var _timer_bar: ProgressBar
var _fish_l: Label
var _caught_l: Label
var _combo_l: Label
var _pounce_bar: ProgressBar
var _time_l: Label
var _shop_grid: GridContainer
var _shop_fish: Label
var _sum_box: VBoxContainer
var _restart_armed := false

func _ready() -> void:
	theme_ = _make_theme()
	root = Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.theme = theme_
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_hud(); _build_title(); _build_summary(); _build_shop()
	toast = _lbl("", 22, F_SEMI, Color(1, 0.95, 0.85))
	toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM); toast.position.y -= 70
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(toast)
	version = _lbl("%s   ·   F9 cập nhật" % Updater.version_label(), 13, F_REG, Color(0.8, 0.78, 0.9, 0.55))
	version.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT); version.position += Vector2(-260, -26)
	root.add_child(version)
	Updater.status.connect(func(t): _toast(t, 4.0))
	Updater.update_ready.connect(func(_r): _restart_armed = true)
	Updater.check_for_updates(true)
	Progress.brightness_changed.connect(func(v): _toast("Độ sáng: %d%%" % roundi(v * 100)))
	Progress.changed.connect(_refresh_shop)

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("update_game"):
		if _restart_armed:
			Updater.restart()
		else:
			Updater.check_for_updates()

# ------------------------------------------------------------------ theme
func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = F_SEMI
	t.default_font_size = 20
	var panel := StyleBoxFlat.new()
	panel.bg_color = PANEL
	panel.set_corner_radius_all(22)
	panel.set_border_width_all(2)
	panel.border_color = Color(GOLD, 0.45)
	panel.shadow_color = Color(0, 0, 0, 0.45); panel.shadow_size = 18
	panel.set_content_margin_all(22)
	t.set_stylebox("panel", "PanelContainer", panel)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var b := StyleBoxFlat.new()
		b.set_corner_radius_all(16)
		b.set_content_margin_all(12)
		b.content_margin_left = 22; b.content_margin_right = 22
		match st:
			"normal": b.bg_color = Color(0.95, 0.6, 0.25)
			"hover": b.bg_color = Color(1.0, 0.72, 0.35)
			"pressed": b.bg_color = Color(0.85, 0.5, 0.2)
			"disabled": b.bg_color = Color(0.3, 0.27, 0.4)
			"focus": b.bg_color = Color(0, 0, 0, 0); b.set_border_width_all(2); b.border_color = Color(1, 1, 1, 0.6)
		b.shadow_color = Color(0, 0, 0, 0.35); b.shadow_size = 6 if st != "pressed" else 2
		t.set_stylebox(st, "Button", b)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(0.65, 0.62, 0.75))
	t.set_font("font", "Button", F_BOLD)
	var bar_bg := StyleBoxFlat.new(); bar_bg.bg_color = Color(0.05, 0.04, 0.1, 0.8); bar_bg.set_corner_radius_all(10)
	var bar_fg := StyleBoxFlat.new(); bar_fg.bg_color = GOLD; bar_fg.set_corner_radius_all(10)
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

func _centered_panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH; p.grow_vertical = Control.GROW_DIRECTION_BOTH
	return p

func _show_only(c: Control) -> void:
	for x in [title, hud, summary, shop]:
		x.visible = x == c or (x == hud and c == hud)
	if c != hud:
		c.modulate.a = 0.0
		c.create_tween().tween_property(c, "modulate:a", 1.0, 0.25)

func _toast(t: String, secs := 1.6) -> void:
	toast.text = t
	toast.modulate.a = 1.0
	var tw := toast.create_tween()
	tw.tween_interval(secs); tw.tween_property(toast, "modulate:a", 0.0, 0.4)

# ------------------------------------------------------------------ title
func _build_title() -> void:
	title = Control.new(); title.set_anchors_preset(Control.PRESET_FULL_RECT); root.add_child(title)
	var shade := ColorRect.new(); shade.color = Color(0.03, 0.02, 0.08, 0.55); shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.add_child(shade)
	var v := VBoxContainer.new(); v.set_anchors_preset(Control.PRESET_CENTER)
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH; v.grow_vertical = Control.GROW_DIRECTION_BOTH
	v.alignment = BoxContainer.ALIGNMENT_CENTER; v.add_theme_constant_override("separation", 14)
	title.add_child(v)
	var t1 := _lbl("Mời Bạn Ra Đây", 84, F_BOLD, Color(1.0, 0.88, 0.6)); t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var t2 := _lbl("Mèo săn chuột đêm rằm tháng Bảy", 26, F_SEMI, Color(0.8, 0.85, 1.0)); t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var t3 := _lbl("WASD để chạy  ·  Space / chuột trái để vồ", 18, F_REG, Color(0.85, 0.82, 0.95, 0.8)); t3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t1); v.add_child(t2)
	var sp := Control.new(); sp.custom_minimum_size.y = 20; v.add_child(sp)
	var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_CENTER; row.add_theme_constant_override("separation", 16)
	row.add_child(_btn("Bắt đầu săn", func(): start_pressed.emit(), 28))
	row.add_child(_btn("Nâng cấp", func(): show_shop(), 28))
	v.add_child(row); v.add_child(t3)

func show_title() -> void:
	_show_only(title)

# ------------------------------------------------------------------ hud
func _build_hud() -> void:
	hud = Control.new(); hud.set_anchors_preset(Control.PRESET_FULL_RECT); hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE); top.offset_top = 18; top.offset_left = 28; top.offset_right = -28
	top.add_theme_constant_override("separation", 24)
	hud.add_child(top)
	_fish_l = _lbl("0", 34, F_BOLD, GOLD)
	var fish_box := HBoxContainer.new(); fish_box.add_child(_lbl("Cá khô", 18, F_SEMI, Color(1, 0.9, 0.7, 0.8))); fish_box.add_child(_fish_l)
	fish_box.add_theme_constant_override("separation", 10)
	top.add_child(fish_box)
	var mid := VBoxContainer.new(); mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_time_l = _lbl("30", 26, F_BOLD, Color(0.85, 0.9, 1.0)); _time_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_bar = ProgressBar.new(); _timer_bar.show_percentage = false; _timer_bar.custom_minimum_size = Vector2(420, 16)
	_timer_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mid.add_child(_time_l); mid.add_child(_timer_bar)
	top.add_child(mid)
	_caught_l = _lbl("0 chuột", 30, F_BOLD, Color(0.9, 0.95, 1.0))
	top.add_child(_caught_l)
	_combo_l = _lbl("", 40, F_BOLD, Color(1.0, 0.6, 0.35))
	_combo_l.set_anchors_preset(Control.PRESET_CENTER_TOP); _combo_l.position.y = 110
	_combo_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _combo_l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hud.add_child(_combo_l)
	_pounce_bar = ProgressBar.new(); _pounce_bar.show_percentage = false; _pounce_bar.custom_minimum_size = Vector2(160, 10)
	_pounce_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM); _pounce_bar.position += Vector2(-80, -40)
	hud.add_child(_pounce_bar)
	var pl := _lbl("Vồ  [Space]", 15, F_SEMI, Color(1, 1, 1, 0.7))
	pl.set_anchors_preset(Control.PRESET_CENTER_BOTTOM); pl.position += Vector2(-42, -66)
	hud.add_child(pl)

func show_hud() -> void:
	_show_only(hud)

func update_hud(time_left: float, total: float, caught: int, fish: float, combo: int, cool: float) -> void:
	_time_l.text = str(int(ceil(maxf(time_left, 0.0))))
	_timer_bar.value = 100.0 * maxf(time_left, 0.0) / total
	_time_l.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4) if time_left < 5.0 else Color(0.85, 0.9, 1.0))
	_fish_l.text = BigNum.fmt(fish)
	_caught_l.text = "%d chuột" % caught
	_combo_l.text = ("Liên hoàn ×%d" % combo) if combo >= 3 else ""
	_pounce_bar.value = 100.0 * (1.0 - cool)

# ------------------------------------------------------------------ summary
func _build_summary() -> void:
	summary = Control.new(); summary.set_anchors_preset(Control.PRESET_FULL_RECT); root.add_child(summary)
	var shade := ColorRect.new(); shade.color = Color(0.02, 0.01, 0.06, 0.6); shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	summary.add_child(shade)
	var p := _centered_panel(); p.custom_minimum_size = Vector2(520, 0); summary.add_child(p)
	_sum_box = VBoxContainer.new(); _sum_box.add_theme_constant_override("separation", 12); p.add_child(_sum_box)

func show_summary(caught: int, fish: float, record: bool) -> void:
	for c in _sum_box.get_children():
		c.queue_free()
	var h := _lbl("Trời sắp sáng…", 40, F_BOLD, Color(1.0, 0.88, 0.6)); h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sum_box.add_child(h)
	_sum_box.add_child(_lbl("Đêm thứ %d" % Progress.nights, 20, F_REG, Color(0.8, 0.8, 0.95)))
	_sum_box.add_child(_lbl("Bắt được   %d chuột" % caught, 30, F_SEMI))
	_sum_box.add_child(_lbl("Cá khô     +%s" % BigNum.fmt(fish), 30, F_SEMI, GOLD))
	if record:
		_sum_box.add_child(_lbl("Kỷ lục mới!", 26, F_BOLD, Color(1.0, 0.55, 0.4)))
	var b := _btn("Nâng cấp mèo", func(): next_pressed.emit(), 26)
	_sum_box.add_child(b)
	_show_only(summary)

# ------------------------------------------------------------------ shop
func _build_shop() -> void:
	shop = Control.new(); shop.set_anchors_preset(Control.PRESET_FULL_RECT); root.add_child(shop)
	var shade := ColorRect.new(); shade.color = Color(0.02, 0.01, 0.06, 0.72); shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shop.add_child(shade)
	var v := VBoxContainer.new(); v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 60; v.offset_right = -60; v.offset_top = 36; v.offset_bottom = -36
	v.add_theme_constant_override("separation", 16)
	shop.add_child(v)
	var head := HBoxContainer.new(); head.add_theme_constant_override("separation", 20)
	head.add_child(_lbl("Nâng cấp", 46, F_BOLD, Color(1.0, 0.88, 0.6)))
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(sp)
	_shop_fish = _lbl("", 34, F_BOLD, GOLD); head.add_child(_shop_fish)
	v.add_child(head)
	var scroll := ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_shop_grid = GridContainer.new(); _shop_grid.columns = 3
	_shop_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_grid.add_theme_constant_override("h_separation", 18); _shop_grid.add_theme_constant_override("v_separation", 18)
	scroll.add_child(_shop_grid)
	var foot := HBoxContainer.new(); foot.alignment = BoxContainer.ALIGNMENT_END; foot.add_theme_constant_override("separation", 16)
	foot.add_child(_btn("Đêm tiếp theo  ›", func(): night_pressed.emit(), 30))
	v.add_child(foot)

func show_shop() -> void:
	_refresh_shop()
	_show_only(shop)

func _refresh_shop() -> void:
	if _shop_grid == null:
		return
	_shop_fish.text = "Cá khô  " + BigNum.fmt(Progress.fish)
	for c in _shop_grid.get_children():
		c.queue_free()
	# region unlock card first
	if Progress.areas < Upgrades.AREAS.size():
		var a: Dictionary = Upgrades.AREAS[Progress.areas]
		_shop_grid.add_child(_card("Mở vùng: " + a.name, "Bản đồ rộng hơn, thêm hang chuột, chuột mới", "Vùng %d/%d" % [Progress.areas, Upgrades.AREAS.size()],
			Progress.next_area_cost(), Progress.fish >= Progress.next_area_cost(), func():
				if Progress.buy_area():
					get_parent().sfx.play("unlock", -4.0); area_bought.emit(), true))
	for id in Upgrades.DEFS:
		var d: Dictionary = Upgrades.DEFS[id]
		if d.unlock >= Progress.areas:
			continue
		_shop_grid.add_child(_card(d.name, d.desc, "Cấp %d" % Progress.lv(id), Upgrades.cost(id, Progress.lv(id)), Progress.can_buy(id),
			func():
				if Progress.buy(id):
					get_parent().sfx.play("coin", -2.0)))
	var souls := Upgrades.souls_for(Progress.lifetime_fish)
	_shop_grid.add_child(_card("Chín kiếp", "Đầu thai: mất hết nâng cấp, nhận %d Hồn mèo (+%d%% cá vĩnh viễn). Đang có %d hồn." % [souls, souls * 10, Progress.souls],
		"Kiếp %d/9" % (Progress.lives_used + 1), 0.0, souls > 0 and Progress.lives_used < 8, func():
			if Progress.reincarnate() > 0:
				get_parent().sfx.play("unlock", -2.0); area_bought.emit(), false, "Đầu thai"))

func _card(name: String, desc: String, tag: String, cost: float, enabled: bool, cb: Callable, special := false, btn_text := "") -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(380, 170)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if special:
		var sb := (theme_.get_stylebox("panel", "PanelContainer") as StyleBoxFlat).duplicate()
		sb.border_color = Color(0.5, 0.95, 1.0, 0.8); sb.set_border_width_all(3)
		p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 6); p.add_child(v)
	var top := HBoxContainer.new()
	top.add_child(_lbl(name, 24, F_BOLD, Color(1, 0.95, 0.85)))
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(sp)
	top.add_child(_lbl(tag, 16, F_SEMI, Color(0.75, 0.8, 1.0, 0.85)))
	v.add_child(top)
	var d := _lbl(desc, 16, F_REG, Color(0.85, 0.83, 0.95, 0.85)); d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(d)
	var b := _btn(btn_text if btn_text != "" else "Mua  ·  %s cá" % BigNum.fmt(cost), cb, 20)
	b.disabled = not enabled
	v.add_child(b)
	return p
