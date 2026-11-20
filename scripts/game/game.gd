extends Node3D
## Mèo Survivors: one night = one run. TITLE -> SELECT -> RUN (<-> LEVELUP) -> RESULT -> SHOP/SELECT.

enum Phase { TITLE, SELECT, RUN, LEVELUP, PAUSED, RESULT, SHOP }
const CAM_OFF := Vector3(0, 13.5, 15.0)

var phase := Phase.TITLE
var village: Village
var swarm: MiceSwarm
var rice: RiceField
var weapons: Weapons
var player: Cat
var boss: RatKing
var wedding: RatWedding
var cam: Camera3D
var env: Environment
var ui: GameUI
var sfx: Sfx

# --- run state
var t := 0.0
var level := 1
var xp := 0.0
var xp_next := 5.0
var lives := 9
var max_lives := 9
var kills := 0
var fish_run := 0.0
var passives := {}
var rerolls := 0
var revives := 0
var pending_levels := 0
var boss_spawned := false
var wedding_done := false
var won := false
var offers: Array = []
var _invuln := 0.0
var _spawn_acc := 0.0
var _shake := 0.0
var _pop_budget := 0
var _hpm_t := 0.0

func _ready() -> void:
	randomize()
	_environment()
	village = Village.new(); add_child(village)
	village.build(Upgrades.AREAS.size())
	village.set_unlocked(Upgrades.AREAS.size())
	swarm = MiceSwarm.new(); add_child(swarm)
	swarm.killed.connect(_on_killed)
	swarm.bite.connect(on_bite)
	swarm.holes = village.holes(); swarm.obstacles = village.obstacles; swarm.inside = village.inside
	rice = RiceField.new(); add_child(rice)
	rice.collected.connect(_on_rice)
	weapons = Weapons.new(); add_child(weapons); weapons.game = self
	player = Cat.new(); add_child(player)
	player.bounds = village.clamp_inside
	player.swarm = swarm
	player.pounced.connect(func(): sfx.play("whoosh", -6.0))
	player.landed.connect(_on_player_landed)
	swarm.player = player; rice.player = player
	cam = Camera3D.new(); cam.fov = 42.0; cam.far = 400.0; add_child(cam); cam.current = true
	sfx = Sfx.new(); add_child(sfx)
	ui = GameUI.new(); add_child(ui)
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	ui.play_pressed.connect(show_select)
	ui.start_run_pressed.connect(start_run)
	ui.card_picked.connect(pick_card)
	ui.reroll_pressed.connect(reroll)
	ui.result_done.connect(show_select)
	ui.shop_pressed.connect(func(): phase = Phase.SHOP; ui.show_shop())
	ui.shop_back.connect(show_select)
	ui.resume_pressed.connect(_resume)
	ui.quit_run_pressed.connect(func(): get_tree().paused = false; _end_run(false))
	Progress.brightness_changed.connect(_apply_brightness)
	_apply_brightness(Progress.brightness)
	player.apply_skin(RunDefs.CHARACTERS[Progress.character].skin)
	player.global_position = RunDefs.STAGES[Progress.stage].start
	_place_cam(true)
	if "--autostart" in OS.get_cmdline_user_args():
		start_run()
	else:
		ui.show_title()

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("pause"):
		if phase == Phase.RUN:
			phase = Phase.PAUSED; get_tree().paused = true; ui.show_pause()
		elif phase == Phase.PAUSED:
			_resume()

func _resume() -> void:
	if phase == Phase.PAUSED:
		phase = Phase.RUN; get_tree().paused = false; ui.show_hud()

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
	env.glow_enabled = true; env.glow_intensity = 0.9; env.glow_bloom = 0.12; env.glow_hdr_threshold = 0.9
	env.fog_enabled = true; env.fog_light_color = Color(0.12, 0.1, 0.25); env.fog_density = 0.01; env.fog_sky_affect = 0.0
	env.ssao_enabled = true; env.ssao_radius = 1.2; env.ssao_intensity = 2.2
	env.adjustment_enabled = true; env.adjustment_saturation = 1.15; env.adjustment_contrast = 1.05
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.62, 0.7, 1.0); moon.light_energy = 1.15
	moon.rotation_degrees = Vector3(-55, -35, 0)
	moon.shadow_enabled = true; moon.directional_shadow_max_distance = 60.0
	add_child(moon)
	var fx := GPUParticles3D.new()
	fx.amount = 220; fx.lifetime = 6.0; fx.preprocess = 6.0
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(55, 1.5, 45)
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = 0.1; pm.initial_velocity_max = 0.4
	pm.spread = 180.0
	pm.turbulence_enabled = true; pm.turbulence_noise_strength = 0.6
	var curve := Curve.new(); curve.add_point(Vector2(0, 0)); curve.add_point(Vector2(0.2, 1)); curve.add_point(Vector2(0.8, 1)); curve.add_point(Vector2(1, 0))
	var ct := CurveTexture.new(); ct.curve = curve; pm.scale_curve = ct
	fx.process_material = pm
	var q := QuadMesh.new(); q.size = Vector2(0.12, 0.12)
	var qm := StandardMaterial3D.new(); qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; qm.albedo_color = Color(0.85, 1.0, 0.45)
	qm.emission_enabled = true; qm.emission = Color(0.8, 1.0, 0.4); qm.emission_energy_multiplier = 4.0
	q.material = qm; fx.draw_pass_1 = q
	fx.position = Vector3(0, 1.5, 20)
	fx.visibility_aabb = AABB(Vector3(-70, -5, -60), Vector3(140, 10, 120))
	add_child(fx)

func _apply_brightness(v: float) -> void:
	env.ambient_light_energy = 0.7 * v
	env.tonemap_exposure = 1.0 * v

# ---------------------------------------------------------------- derived stats
func plv(id: String) -> int:
	return int(passives.get(id, 0))

func might() -> float:
	return (1.0 + 0.12 * plv("might")) * (1.0 + 0.08 * Progress.mlv("m_might"))

func fish_mult() -> float:
	return float(RunDefs.STAGES[Progress.stage].fish) * pow(1.5, Progress.heat) * (1.0 + 0.15 * plv("fish")) * (1.0 + 0.12 * Progress.mlv("m_greed"))

func _apply_stats() -> void:
	player.speed = 7.0 * (1.0 + 0.1 * plv("speed")) * (1.0 + 0.05 * Progress.mlv("m_speed"))
	player.catch_radius = 1.0
	player.pounce_dist = 4.5
	player.pounce_cd = 1.2 * _cd_mult()
	rice.magnet = 2.2 * (1.0 + 0.4 * plv("whisker")) * (1.0 + 0.2 * Progress.mlv("m_magnet"))
	weapons.might = might()
	weapons.cd_mult = _cd_mult()

func _cd_mult() -> float:
	return maxf(0.3, (1.0 - 0.08 * plv("bell")) * (1.0 - 0.04 * Progress.mlv("m_cd")))

# ---------------------------------------------------------------- run lifecycle
func show_select() -> void:
	get_tree().paused = false
	phase = Phase.SELECT
	_clear_run()
	player.apply_skin(RunDefs.CHARACTERS[Progress.character].skin)
	player.global_position = RunDefs.STAGES[Progress.stage].start
	ui.show_select()

func _clear_run() -> void:
	swarm.clear(); rice.clear(); weapons.clear()
	if is_instance_valid(boss): boss.queue_free()
	if is_instance_valid(wedding): wedding.queue_free()
	boss = null; wedding = null

func start_run() -> void:
	_clear_run()
	get_tree().paused = false
	var ch: Dictionary = RunDefs.CHARACTERS[Progress.character]
	player.apply_skin(ch.skin)
	player.global_position = RunDefs.STAGES[Progress.stage].start
	t = 0.0; level = 1; xp = 0.0; xp_next = RunDefs.xp_to_next(1); kills = 0; fish_run = 0.0
	passives = {}
	max_lives = 9 + Progress.mlv("m_life"); lives = max_lives
	rerolls = Progress.mlv("m_reroll"); revives = Progress.mlv("m_revive")
	pending_levels = 0; boss_spawned = false; wedding_done = false; won = false
	weapons.levels[ch.weapon] = 1
	passives[ch.perk] = int(ch.get("perk_lv", 1))
	if ch.perk == "bowl":
		max_lives += passives[ch.perk]; lives = max_lives
	_apply_stats()
	_update_hp_mult()
	for i in 10:
		_spawn_one(true)
	phase = Phase.RUN
	ui.show_hud()
	ui.banner(RunDefs.STAGES[Progress.stage].name + ("" if Progress.heat == 0 else "  ·  Đêm rằm +%d" % Progress.heat))

func _update_hp_mult() -> void:
	swarm.hp_mult = RunDefs.mouse_hp(1.0, t / 60.0, Progress.stage) * pow(1.6, Progress.heat)

func _process(dt: float) -> void:
	_place_cam(false, dt)
	_pop_budget = 6
	if phase != Phase.RUN:
		return
	if not boss_spawned:
		t += dt
	_invuln = maxf(0.0, _invuln - dt)
	_hpm_t -= dt
	if _hpm_t <= 0.0:
		_hpm_t = 1.0; _update_hp_mult()
	_director(dt)
	if not wedding_done and t >= RunDefs.WEDDING_AT:
		_start_wedding()
	if not boss_spawned and t >= RunDefs.NIGHT_SECONDS:
		_spawn_boss()
	if pending_levels > 0 and phase == Phase.RUN:
		_open_levelup()
	ui.update_hud({"t": t, "total": RunDefs.NIGHT_SECONDS, "lives": lives, "max_lives": max_lives, "level": level,
		"xp": xp / xp_next, "kills": kills, "fish": fish_run, "cool": player.cooldown_ratio(),
		"charges": player.charges_left(), "boss": boss_spawned})

# ---------------------------------------------------------------- director
func _director(dt: float) -> void:
	var minute := t / 60.0
	var rate := RunDefs.spawn_rate(minute, Progress.stage) * (1.0 + 0.2 * Progress.heat)
	if boss_spawned:
		rate *= 0.4
	_spawn_acc += dt * rate
	var cap := RunDefs.max_alive(minute)
	while _spawn_acc >= 1.0:
		_spawn_acc -= 1.0
		if swarm.count() < cap:
			_spawn_one()

func _roll_kind() -> int:
	var minute := t / 60.0
	var allowed: Array = RunDefs.STAGES[Progress.stage].kinds
	if randf() < 0.015:
		return MiceSwarm.Kind.VANG
	var r := randf()
	if "ma" in allowed and minute >= 3.0 and r < 0.12:
		return MiceSwarm.Kind.MA
	if "chu" in allowed and minute >= 1.5 and r < 0.25:
		return MiceSwarm.Kind.CHU
	if minute >= 0.75 and r < clampf(0.25 + 0.1 * minute, 0.0, 0.6):
		return MiceSwarm.Kind.CONG
	return MiceSwarm.Kind.NHAT

## Mice appear in a ring just off-screen around the cat (survivors-style); edge holes as fallback.
func _spawn_one(near := false) -> void:
	var k := MiceSwarm.Kind.NHAT if near else _roll_kind()
	for tries in 8:
		var a := randf() * TAU
		var r := randf_range(5.0, 10.0) if near else randf_range(15.0, 21.0)
		var p := player.global_position + Vector3(cos(a) * r, 0, sin(a) * r * 0.8)
		if village.inside(p):
			swarm.spawn(k, p)
			return
	swarm.spawn_at_random_hole(k)

# ---------------------------------------------------------------- combat plumbing
## Every weapon hits through here: mice, the boss and the wedding palanquin.
func hit(center: Vector3, r: float, dmg: float, dir := Vector3.ZERO, arc := TAU, knock := 2.0) -> int:
	var n := swarm.damage_in(center, r, dmg, dir, arc, knock)
	if is_instance_valid(boss):
		boss.try_hit(center, r, dmg)
	if is_instance_valid(wedding):
		wedding.try_hit(center, r, dmg)
	return n

func on_bite(dmg: int) -> void:
	if phase != Phase.RUN or _invuln > 0.0 or player.is_pouncing():
		return
	lives -= dmg
	_invuln = 1.0
	shake(0.35)
	sfx.play("click", 0.0, 0.5)
	ui.hurt()
	if lives <= 0:
		if revives > 0:
			revives -= 1
			lives = maxi(1, max_lives / 2)
			_invuln = 2.0
			hit(player.global_position, 9.0, 99999.0, Vector3.ZERO, TAU, 8.0)
			Juice.ring(self, player.global_position, 9.0)
			ui.banner("Chín kiếp mèo: sống lại!")
		else:
			_end_run(false)

func _on_player_landed(at: Vector3) -> void:
	Juice.dust(self, at)
	if phase == Phase.RUN:
		hit(at, 1.9, 30.0 * might(), Vector3.ZERO, TAU, 3.0)

func _on_killed(p: Vector3, kind: int) -> void:
	kills += 1
	var d: Dictionary = MiceSwarm.KINDS[kind]
	rice.drop(p, float(d.xp))
	var gain: float = float(d.fish) * fish_mult()
	fish_run += gain
	if _pop_budget > 0:
		_pop_budget -= 1
		Juice.burst(self, p, d.color)
		sfx.play("pop", -10.0, 1.0 + randf() * 0.3)
	if kind == MiceSwarm.Kind.VANG:
		Juice.popup(self, p + Vector3(0, 0.8, 0), "+" + BigNum.fmt(gain), Color(1.0, 0.85, 0.35))
		Juice.fish(self, p)

func _on_rice(v: float) -> void:
	xp += v * (1.0 + 0.1 * Progress.mlv("m_growth"))
	while xp >= xp_next:
		xp -= xp_next
		level += 1
		xp_next = RunDefs.xp_to_next(level)
		pending_levels += 1

func shake(v: float) -> void:
	_shake = minf(_shake + v, 0.7)

# ---------------------------------------------------------------- level-up cards
func _open_levelup() -> void:
	pending_levels -= 1
	offers = build_offers()
	phase = Phase.LEVELUP
	get_tree().paused = true
	sfx.play("chime", -8.0, 1.2)
	ui.show_levelup(offers, rerolls, level)

## Returns up to 3 card dicts: {type: weapon|passive|evo|heal|fish, id, lv, name, desc}.
func build_offers() -> Array:
	var pool := []
	for id in RunDefs.WEAPONS:
		var w: Dictionary = RunDefs.WEAPONS[id]
		if weapons.levels.has(id):
			var lv: int = weapons.levels[id]
			if lv >= RunDefs.MAX_WEAPON_LV and not weapons.evolved.get(id, false) and plv(w.evo) > 0:
				pool.append({"type": "evo", "id": id, "name": w.evo_name, "desc": w.evo_desc, "lv": 0, "w": 100.0})
			elif lv < RunDefs.MAX_WEAPON_LV:
				pool.append({"type": "weapon", "id": id, "name": w.name, "desc": w.desc, "lv": lv + 1, "w": 3.0})
		elif weapons.levels.size() < RunDefs.MAX_WEAPONS:
			pool.append({"type": "weapon", "id": id, "name": w.name, "desc": w.desc, "lv": 1, "w": 2.0})
	for id in RunDefs.PASSIVES:
		var p: Dictionary = RunDefs.PASSIVES[id]
		var lv := plv(id)
		if lv > 0 and lv < RunDefs.MAX_PASSIVE_LV:
			pool.append({"type": "passive", "id": id, "name": p.name, "desc": p.desc, "lv": lv + 1, "w": 2.0})
		elif lv == 0 and passives.size() < RunDefs.MAX_PASSIVES:
			pool.append({"type": "passive", "id": id, "name": p.name, "desc": p.desc, "lv": 1, "w": 1.5})
	var out := []
	for k in 3:
		if pool.is_empty():
			break
		var total := 0.0
		for c in pool:
			total += c.w
		var r := randf() * total
		for c in pool:
			r -= c.w
			if r <= 0.0:
				out.append(c); pool.erase(c); break
	if out.size() < 3:
		out.append({"type": "heal", "id": "", "name": "Bát cháo", "desc": "Hồi 3 mạng", "lv": 0})
	if out.size() < 3:
		out.append({"type": "fish", "id": "", "name": "Xâu cá khô", "desc": "+%s cá" % BigNum.fmt(25.0 * fish_mult()), "lv": 0})
	return out

func pick_card(i: int) -> void:
	if phase != Phase.LEVELUP or i >= offers.size():
		return
	apply_card(offers[i])
	sfx.play("coin", -2.0)
	get_tree().paused = false
	phase = Phase.RUN
	ui.show_hud()

func apply_card(c: Dictionary) -> void:
	match c.type:
		"weapon": weapons.levels[c.id] = c.lv
		"evo":
			weapons.evolved[c.id] = true
			ui.banner("Tiến hóa: " + c.name + "!")
		"passive":
			passives[c.id] = c.lv
			if c.id == "bowl":
				max_lives += 1; lives = mini(max_lives, lives + 2)
		"heal": lives = mini(max_lives, lives + 3)
		"fish": fish_run += 25.0 * fish_mult()
	_apply_stats()

func reroll() -> void:
	if phase != Phase.LEVELUP or rerolls <= 0:
		return
	rerolls -= 1
	offers = build_offers()
	ui.show_levelup(offers, rerolls, level)

# ---------------------------------------------------------------- events
func _start_wedding() -> void:
	wedding_done = true
	wedding = RatWedding.new(); add_child(wedding)
	var c := player.global_position
	var side := Vector3(1, 0, 0).rotated(Vector3.UP, randf() * TAU)
	var from := village.clamp_inside(c - side * 22.0 + Vector3(0, 0, -4))
	var to := village.clamp_inside(c + side * 22.0 + Vector3(0, 0, 4))
	wedding.setup(self, from, to, 350.0 * swarm.hp_mult)
	wedding.opened.connect(_on_chest)
	ui.banner("Đám cưới chuột! Phá kiệu để nhận rương báu")
	sfx.play("unlock", -4.0)

func _on_chest(at: Vector3) -> void:
	Juice.ring(self, at, 4.0)
	Juice.popup(self, at + Vector3(0, 1.5, 0), "Rương báu!", Color(1.0, 0.85, 0.35))
	pending_levels += 2
	var bonus := 60.0 * fish_mult()
	fish_run += bonus
	rice.pull_all()
	shake(0.4)
	sfx.play("unlock", -2.0)

func _spawn_boss() -> void:
	boss_spawned = true
	boss = RatKing.new(); add_child(boss)
	var a := randf() * TAU
	boss.global_position = village.clamp_inside(player.global_position + Vector3(cos(a), 0, sin(a)) * 14.0)
	boss.setup(self, float(RunDefs.STAGES[Progress.stage].boss_hp) * pow(1.6, Progress.heat))
	boss.died.connect(_on_boss_died)
	boss.hp_changed.connect(func(r): ui.boss_bar(r))
	ui.boss_bar(1.0)
	ui.banner("Chuột Chúa xuất hiện!")
	sfx.play("unlock", 0.0, 0.6)
	shake(0.5)

func _on_boss_died(at: Vector3) -> void:
	won = true
	Juice.ring(self, at, 8.0)
	hit(at, 30.0, 99999.0)
	fish_run += 300.0 * fish_mult()
	rice.pull_all()
	shake(0.7)
	ui.banner("Hạ Chuột Chúa!")
	await get_tree().create_timer(2.0).timeout
	if phase == Phase.RUN:
		_end_run(true)

func _end_run(victory: bool) -> void:
	if phase == Phase.RESULT:
		return
	phase = Phase.RESULT
	get_tree().paused = false
	var survived_bonus := fish_run * (0.5 if victory else 0.0)
	var total := fish_run + survived_bonus
	Progress.add_fish(total)
	var unlocked := Progress.end_night(victory, t, kills)
	_clear_run()
	sfx.play("chime", -6.0)
	ui.show_result({"won": victory, "t": t, "kills": kills, "level": level, "fish": total, "unlocked": unlocked})

# ---------------------------------------------------------------- camera
func _place_cam(snap: bool, dt := 0.016) -> void:
	var focus := player.global_position
	var goal := focus + Vector3(0, 0, -1.0) + CAM_OFF
	if snap:
		cam.global_position = goal
	else:
		cam.global_position = cam.global_position.lerp(goal, 1.0 - exp(-6.0 * dt))
	_shake = maxf(0.0, _shake - dt * 1.8)
	var sh := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.3
	cam.look_at(cam.global_position - CAM_OFF.normalized() + sh * 0.02, Vector3.UP)
	cam.global_position += sh
