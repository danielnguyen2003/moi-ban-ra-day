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
	ui.update_hud(time_left, night_len, caught_night, Progress.fish, combo, player.cooldown_ratio())
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
	_combo_t = 1.6
	var base: float = MiceSwarm.KINDS[kind].fish
	var mult := Upgrades.bounty_mult(Progress.lv("bounty"), Progress.souls) * (1.0 + 0.1 * mini(combo - 1, 20))
	var gain := base * mult
	fish_night += gain
	Progress.add_fish(gain)
	Juice.popup(self, p + Vector3(0, 0.8, 0), "+" + BigNum.fmt(gain), Color(1.0, 0.85, 0.35) if kind == MiceSwarm.Kind.VANG else Color(0.85, 0.95, 1.0))
	Juice.burst(self, p, MiceSwarm.KINDS[kind].color)
	sfx.play("pop", -4.0, 1.0 + minf(combo, 12) * 0.04)
	if by_player:
		_shake = minf(_shake + 0.18, 0.5)

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
