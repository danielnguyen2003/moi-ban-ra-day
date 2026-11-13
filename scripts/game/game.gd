extends Node3D
## Main flow: HUNT (one night) -> SUMMARY -> SHOP -> HUNT … Builds world, camera, lighting.

const FONT_B := preload("res://assets/fonts/google/bevietnampro/BeVietnamPro-ExtraBold.ttf")
enum Phase { TITLE, HUNT, SUMMARY, SHOP }

var phase := Phase.TITLE
var village: Village
var swarm: MiceSwarm
var player: Cat
var kittens: Array[Cat] = []
var cam: Camera3D
var env: Environment
var ui: GameUI
var sfx: Sfx

var time_left := 0.0
var night_len := 30.0
var caught_night := 0
var fish_night := 0.0
var combo := 0
var _combo_t := 0.0
var _spawn_acc := 0.0
var _shake := 0.0
var _wave_t := 6.0
var traps: Array[Node3D] = []
var owls: Array[Node3D] = []
var _cam_zoom := 1.0
const CAM_OFF := Vector3(0, 10.5, 12.5)   # ~40° pitch: shows faces, not just backs

func _ready() -> void:
	randomize()
	_environment()
	village = Village.new()
	add_child(village)
	village.build(Progress.areas)
	swarm = MiceSwarm.new()
	add_child(swarm)
	swarm.caught.connect(_on_caught)
	player = Cat.new()
	add_child(player)
	player.global_position = Vector3(0, 0, 3)
	player.bounds = village.clamp_inside
	player.pounced.connect(func(): sfx.play("whoosh", -6.0))
	player.landed.connect(_on_player_landed)
	player.swarm = swarm
	player.apply_skin(Progress.skin)
	Progress.skin_changed.connect(func(): player.apply_skin(Progress.skin))
	cam = Camera3D.new(); cam.fov = 40.0; cam.far = 300.0
	add_child(cam); cam.current = true
	sfx = Sfx.new(); add_child(sfx)
	ui = GameUI.new(); add_child(ui)
	ui.start_pressed.connect(start_night)
	ui.next_pressed.connect(func(): _show_shop())
	ui.night_pressed.connect(start_night)
	ui.area_bought.connect(_on_area_bought)
	Progress.brightness_changed.connect(_apply_brightness)
	_apply_brightness(Progress.brightness)
	_apply_stats()
	_place_cam(true)
	if "--autostart" in OS.get_cmdline_user_args():
		start_night()
	else:
		ui.show_title()

# ---------------------------------------------------------------- environment
func _environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.03, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.3, 0.55)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color(0.12, 0.1, 0.25)
	env.fog_density = 0.012
	env.fog_sky_affect = 0.0
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 2.2
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.adjustment_contrast = 1.05
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.62, 0.7, 1.0)
	moon.light_energy = 1.15
	moon.rotation_degrees = Vector3(-55, -35, 0)
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 80.0
	add_child(moon)
	# full moon disc low in the sky (seen at the top of the screen)
	var m := MeshInstance3D.new(); m.mesh = Toon.sphere(4.0)
	m.material_override = Toon.glow(Color(1.0, 0.95, 0.8), 2.5)
	m.position = Vector3(-20, 30, -70); add_child(m)
	# fireflies
	var fx := GPUParticles3D.new()
	fx.amount = 160; fx.lifetime = 6.0; fx.preprocess = 6.0
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(32, 1.5, 32)
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = 0.1; pm.initial_velocity_max = 0.4
	pm.direction = Vector3(0, 1, 0); pm.spread = 180.0
	pm.turbulence_enabled = true; pm.turbulence_noise_strength = 0.6
	var curve := Curve.new(); curve.add_point(Vector2(0, 0)); curve.add_point(Vector2(0.2, 1)); curve.add_point(Vector2(0.8, 1)); curve.add_point(Vector2(1, 0))
	var ct := CurveTexture.new(); ct.curve = curve; pm.scale_curve = ct
	fx.process_material = pm
	var q := QuadMesh.new(); q.size = Vector2(0.12, 0.12)
	var qm := StandardMaterial3D.new(); qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; qm.albedo_color = Color(0.85, 1.0, 0.45)
	qm.emission_enabled = true; qm.emission = Color(0.8, 1.0, 0.4); qm.emission_energy_multiplier = 4.0
	q.material = qm; fx.draw_pass_1 = q
	fx.position = Vector3(0, 1.5, 12)
	fx.visibility_aabb = AABB(Vector3(-40, -5, -40), Vector3(80, 10, 80))
	add_child(fx)

func _apply_brightness(v: float) -> void:
	env.ambient_light_energy = 0.7 * v
	env.tonemap_exposure = 1.0 * v

# ---------------------------------------------------------------- stats
func _apply_stats() -> void:
	player.speed = Upgrades.move_speed(Progress.lv("speed"))
	player.catch_radius = Upgrades.catch_radius(Progress.lv("claw"))
	player.pounce_dist = Upgrades.pounce_distance(Progress.lv("pounce"))
	player.pounce_cd = Upgrades.pounce_cooldown(Progress.lv("pounce"))
	player.max_charges = Upgrades.charges(Progress.lv("charges"))
	night_len = Upgrades.night_seconds(Progress.lv("time"))
	swarm.magnet = Upgrades.magnet_radius(Progress.lv("whisker"))
	village.set_unlocked(Progress.areas)
	swarm.holes = village.holes()
	swarm.obstacles = village.obstacles
	swarm.inside = village.inside
	# kittens
	var want := Upgrades.kittens(Progress.lv("kitten"))
	var colors := [Color(0.95, 0.6, 0.3), Color(0.15, 0.14, 0.16), Color(0.92, 0.9, 0.86), Color(0.7, 0.62, 0.55)]
	while kittens.size() < want:
		var k := Cat.new()
		k.is_player = false
		k.size = 0.62
		k.fur = colors[kittens.size() % colors.size()]
		k.stripe = k.fur.darkened(0.35)
		k.swarm = swarm
		k.bounds = village.clamp_inside
		add_child(k)
		k.global_position = player.global_position + Vector3(randf_range(-2, 2), 0, randf_range(1, 3))
		kittens.append(k)
	for k in kittens:
		k.speed = player.speed * 0.8
		k.catch_radius = player.catch_radius
		k.pounce_dist = player.pounce_dist * 0.8
		k.pounce_cd = player.pounce_cd * 1.5
	_sync_traps()
	_sync_owls()
	var all: Array[Cat] = [player]
	all.append_array(kittens)
	swarm.cats = all
	swarm.player = player

# ---------------------------------------------------------------- night loop
func start_night() -> void:
	_apply_stats()
	swarm.clear()
	time_left = night_len
	caught_night = 0
	fish_night = 0.0
	combo = 0
	_wave_t = 4.0
	for t in traps:
		t.set_meta("cd", 0.0)
	phase = Phase.HUNT
	ui.show_hud()
	# a few mice already out so the first seconds aren't empty
	for i in mini(1 + Progress.areas, Upgrades.max_mice(Progress.lv("spawn"), Progress.areas)):
		swarm.spawn_at_random_hole(_roll_kind())

func _process(dt: float) -> void:
	_place_cam(false, dt)
	if phase != Phase.HUNT:
		return
	time_left -= dt
	_combo_t -= dt
	if _combo_t <= 0.0:
		combo = 0
	_spawn_acc += dt * Upgrades.spawn_per_second(Progress.lv("spawn"), Progress.areas)
	while _spawn_acc >= 1.0:
		_spawn_acc -= 1.0
		if swarm.count() < Upgrades.max_mice(Progress.lv("spawn"), Progress.areas):
			swarm.spawn_at_random_hole(_roll_kind())
	# đàn chuột: periodic bursts from one hole
	var ws := Upgrades.wave_size(Progress.lv("wave"))
	if ws > 0:
		_wave_t -= dt
		if _wave_t <= 0.0:
			_wave_t = 6.0
			var h: Vector3 = swarm.holes[randi() % swarm.holes.size()] if not swarm.holes.is_empty() else Vector3.ZERO
			for i in ws:
				swarm.spawn(_roll_kind(), h + Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.8, 0.8)))
			ui.flash("Đàn chuột!")
	_update_traps(dt)
	_update_owls(dt)
	ui.update_hud(time_left, night_len, caught_night, Progress.fish, combo, player.cooldown_ratio(), player.charges_left(), player.max_charges)
	if time_left <= 0.0:
		_end_night()

func _roll_kind() -> int:
	if randf() < Upgrades.golden_chance(Progress.lv("luck")):
		return MiceSwarm.Kind.VANG
	if Progress.areas >= 6 and randf() < 0.12:
		return MiceSwarm.Kind.MA
	if Progress.areas >= 2 and randf() < 0.25:
		return MiceSwarm.Kind.CONG
	return MiceSwarm.Kind.NHAT

func _on_caught(p: Vector3, kind: int, by_player: bool) -> void:
	caught_night += 1
	combo += 1
	_combo_t = Upgrades.combo_window(Progress.lv("combo"))
	time_left += Upgrades.time_per_catch(Progress.lv("clock"))
	var base: float = MiceSwarm.KINDS[kind].fish
	var mult := Upgrades.bounty_mult(Progress.lv("bounty"), Progress.souls) * (1.0 + Upgrades.combo_bonus(Progress.lv("combo")) * mini(combo - 1, 30))
	var triple := randf() < Upgrades.triple_chance(Progress.lv("double"))
	if triple:
		mult *= 3.0
	var gain := base * mult
	fish_night += gain
	Progress.add_fish(gain)
	Juice.popup(self, p + Vector3(0, 0.8, 0), ("+%s ×3" if triple else "+%s") % BigNum.fmt(gain), Color(1.0, 0.85, 0.35) if (triple or kind == MiceSwarm.Kind.VANG) else Color(0.85, 0.95, 1.0))
	Juice.burst(self, p, MiceSwarm.KINDS[kind].color)
	Juice.fish(self, p)
	sfx.play("pop", -4.0, 1.0 + minf(combo, 12) * 0.04)
	if by_player:
		_shake = minf(_shake + 0.18, 0.5)

func _on_player_landed(at: Vector3) -> void:
	Juice.dust(self, at)
	var r := Upgrades.shock_radius(Progress.lv("shock"))
	if r > 0.0 and phase == Phase.HUNT:
		Juice.ring(self, at, r)
		if swarm.catch_in(at, r, true) > 0:
			_shake = minf(_shake + 0.25, 0.6)

# ---------------------------------------------------------------- helpers: traps & owls
func _rand_point() -> Vector3:
	var rs: Array[Rect2] = []
	for i in mini(Progress.areas, village.rects.size()):
		rs.append(village.rects[i])
	for k in 30:
		var r: Rect2 = rs[randi() % rs.size()].grow(-2.0)
		var p := Vector3(randf_range(r.position.x, r.end.x), 0, randf_range(r.position.y, r.end.y))
		var ok := true
		for o in village.obstacles:
			if Vector2(p.x - o[0].x, p.z - o[0].z).length() < o[1] + 0.8:
				ok = false; break
		if ok:
			return p
	return Vector3.ZERO

func _sync_traps() -> void:
	var want := Upgrades.traps(Progress.lv("trap"))
	while traps.size() < want:
		var t := Node3D.new()
		# bamboo spring trap: woven base + bent bamboo arm
		t.add_child(Toon.part(Toon.cyl(0.55, 0.6, 0.12, 12), Color(0.7, 0.6, 0.35), Vector3(0, 0.06, 0), Vector3.ONE, true, {"stripes": 40.0, "stripe_color": Color(0.55, 0.45, 0.25), "stripe_axis": Vector3(1, 0, 1)}))
		var arm := Node3D.new(); arm.position = Vector3(0, 0.15, 0.45); t.add_child(arm)
		var bar := Toon.part(Toon.cyl(0.04, 0.04, 0.9, 6), Color(0.55, 0.65, 0.3), Vector3(0, 0.4, 0)); arm.add_child(bar)
		arm.rotation.x = -1.2
		t.set_meta("arm", arm); t.set_meta("cd", 0.0)
		add_child(t)
		t.global_position = _rand_point()
		traps.append(t)

func _update_traps(dt: float) -> void:
	for t in traps:
		var cd: float = t.get_meta("cd") - dt
		var arm: Node3D = t.get_meta("arm")
		arm.rotation.x = lerpf(arm.rotation.x, -1.2 if cd <= 0.0 else 0.0, 1.0 - exp(-12.0 * dt))
		if cd <= 0.0 and swarm.catch_in(t.global_position, 0.8) > 0:
			cd = 2.5
			arm.rotation.x = 0.2
			sfx.play("click", -2.0, 0.7)
		t.set_meta("cd", cd)

func _sync_owls() -> void:
	var want := Upgrades.owls(Progress.lv("owl"))
	while owls.size() < want:
		var o := Node3D.new()
		var body := Toon.part(Toon.sphere(0.45), Color(0.55, 0.45, 0.35), Vector3.ZERO, Vector3(1, 1.15, 0.9)); o.add_child(body)
		o.add_child(Toon.part(Toon.sphere(0.32), Color(0.85, 0.78, 0.65), Vector3(0, -0.05, -0.25), Vector3(1, 1.1, 0.6), false))
		for sx in [-1.0, 1.0]:
			var e := MeshInstance3D.new(); e.mesh = Toon.sphere(0.12); e.material_override = Toon.glow(Color(1.0, 0.75, 0.2), 3.0)
			e.position = Vector3(0.17 * sx, 0.2, -0.36); o.add_child(e)
			var wing := Toon.part(Toon.sphere(0.35), Color(0.45, 0.36, 0.28), Vector3(0.45 * sx, 0.0, 0.05), Vector3(0.35, 0.9, 0.8))
			wing.name = "wing%d" % (0 if sx < 0 else 1)
			o.add_child(wing)
			o.add_child(Toon.part(Toon.cone(0.1, 0.25, 4), Color(0.45, 0.36, 0.28), Vector3(0.2 * sx, 0.55, 0)))
		o.set_meta("a", randf() * TAU); o.set_meta("t", randf() * 2.0); o.set_meta("dive", 0.0)
		add_child(o)
		owls.append(o)

func _update_owls(dt: float) -> void:
	var c := player.global_position
	for i in owls.size():
		var o := owls[i]
		var a: float = o.get_meta("a") + dt * 0.6
		o.set_meta("a", a)
		var t: float = o.get_meta("t") - dt
		var dive: float = o.get_meta("dive")
		var circle := c + Vector3(cos(a + i) * 9.0, 6.0, sin(a + i) * 9.0)
		if dive > 0.0:
			dive -= dt
			var target: Vector3 = o.get_meta("target")
			o.global_position = o.global_position.lerp(target + Vector3(0, 0.4, 0), 1.0 - exp(-10.0 * dt))
			if dive <= 0.0:
				swarm.catch_in(target, 1.3)
		else:
			o.global_position = o.global_position.lerp(circle, 1.0 - exp(-3.0 * dt))
			if t <= 0.0:
				t = maxf(1.0, 3.0 - 0.3 * Progress.lv("owl"))
				var n = swarm.nearest(Vector3(o.global_position.x, 0, o.global_position.z), 14.0)
				if n != null:
					o.set_meta("target", n); dive = 0.45
		o.set_meta("t", t); o.set_meta("dive", dive)
		o.look_at(o.global_position + Vector3(-sin(a + i), 0, cos(a + i)), Vector3.UP)
		var flap := sin(Time.get_ticks_msec() * 0.02 + i) * 0.6
		o.get_node("wing0").rotation.z = flap
		o.get_node("wing1").rotation.z = -flap

func _end_night() -> void:
	phase = Phase.SUMMARY
	swarm.clear()
	var record := caught_night > Progress.best_night
	Progress.end_night(caught_night)
	sfx.play("chime", -6.0)
	ui.show_summary(caught_night, fish_night, record)

func _show_shop() -> void:
	phase = Phase.SHOP
	ui.show_shop()

func _on_area_bought() -> void:
	village.set_unlocked(Progress.areas)
	_apply_stats()

# ---------------------------------------------------------------- camera
func _place_cam(snap: bool, dt := 0.016) -> void:
	var target_zoom := 1.0 + 0.12 * (Progress.areas - 1) + 0.03 * Progress.lv("kitten")
	_cam_zoom = lerpf(_cam_zoom, target_zoom, 1.0 - exp(-2.0 * dt))
	var focus := player.global_position
	if phase != Phase.HUNT:
		focus = focus.lerp(Vector3(0, 0, 0), 0.3)
	var goal := focus + Vector3(0, 0, -1.5) + CAM_OFF * _cam_zoom
	if snap:
		cam.global_position = goal
	else:
		cam.global_position = cam.global_position.lerp(goal, 1.0 - exp(-5.0 * dt))
	_shake = maxf(0.0, _shake - dt * 1.8)
	var sh := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.25
	cam.look_at(cam.global_position - CAM_OFF.normalized() + sh * 0.02, Vector3.UP)
	cam.global_position += sh
