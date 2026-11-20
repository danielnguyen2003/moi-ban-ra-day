extends GutTest
## Simulated nights on the real scene.

var game: Node3D

func before_each() -> void:
	Progress.from_dict({})
	Engine.time_scale = 1.0
	game = load("res://scenes/game.tscn").instantiate()
	game.pause_on_levelup = false
	add_child(game)
	await wait_physics_frames(3)
	game.start_run()
	await wait_physics_frames(2)

func _steer(dir: Vector3) -> void:
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)
	if dir.x < -0.2: Input.action_press("move_left", -dir.x)
	if dir.x > 0.2: Input.action_press("move_right", dir.x)
	if dir.z < -0.2: Input.action_press("move_up", -dir.z)
	if dir.z > 0.2: Input.action_press("move_down", dir.z)

func after_each() -> void:
	_steer(Vector3.ZERO)
	get_tree().paused = false
	Engine.time_scale = 1.0
	game.free()

func test_run_starts_with_character_weapon_and_9_lives() -> void:
	assert_eq(game.phase, game.Phase.RUN)
	assert_true(game.weapons.levels.has("claw"))
	assert_eq(game.lives, 9)
	assert_gt(game.swarm.count(), 0, "a few mice near the cat at the start")

func test_weapon_kill_drops_rice_and_rice_levels_up() -> void:
	game.swarm.clear()
	var at: Vector3 = game.player.global_position + Vector3(2, 0, 0)
	game.swarm.spawn(MiceSwarm.Kind.NHAT, at); game.swarm.spawn_in[0] = 0.0
	assert_eq(game.hit(at, 1.0, 999.0), 1)
	assert_eq(game.kills, 1)
	assert_eq(game.rice.pos.size(), 1)
	for k in 10: game.rice.drop(game.player.global_position, 1.0)
	await wait_physics_frames(5)
	assert_gt(game.level, 1, "picking up rice levels the cat up")

func test_levelup_pauses_and_card_applies() -> void:
	game.pending_levels = 1
	await wait_physics_frames(3)
	assert_eq(game.phase, game.Phase.LEVELUP)
	assert_eq(game.offers.size(), 3)
	game.pick_card(0)
	assert_eq(game.phase, game.Phase.RUN)

func test_levelup_really_pauses_in_game() -> void:
	game.pause_on_levelup = true
	game._open_levelup()
	assert_true(get_tree().paused, "the world freezes while choosing a card")
	game.pick_card(1)
	assert_false(get_tree().paused)

func test_offers_respect_slots_and_offer_evolution() -> void:
	game.weapons.levels = {"claw": 8, "lantern": 3, "yarn": 2, "nia": 1}
	game.passives = {"might": 1}
	var seen_new_weapon := false
	var seen_evo := false
	for k in 30:
		for o in game.build_offers():
			if o.type == "weapon" and not game.weapons.levels.has(o.id): seen_new_weapon = true
			if o.type == "evo": seen_evo = true
	assert_false(seen_new_weapon, "4 weapon slots full: no new weapons offered")
	assert_true(seen_evo, "claw lv8 + Móng sắc offers Vuốt hổ")

func test_bite_costs_a_life_with_invulnerability() -> void:
	game.on_bite(1)
	game.on_bite(1)
	assert_eq(game.lives, 8, "second bite inside i-frames is ignored")

func test_death_ends_run_and_banks_fish() -> void:
	game.fish_run = 50.0
	game.lives = 1
	game.on_bite(1)
	assert_eq(game.phase, game.Phase.RESULT)
	assert_eq(Progress.fish, 50.0)

func test_revive() -> void:
	game.revives = 1
	game.lives = 1
	game.on_bite(1)
	assert_eq(game.phase, game.Phase.RUN)
	assert_gt(game.lives, 1)

func test_wedding_chest() -> void:
	game.t = RunDefs.WEDDING_AT
	await wait_physics_frames(2)
	assert_not_null(game.wedding)
	var wp: Vector3 = game.wedding.global_position
	game.hit(wp, 2.0, 1e9)
	await wait_physics_frames(4)
	assert_eq(game.phase, game.Phase.LEVELUP, "chest grants level-up picks")

func test_boss_spawns_at_5_minutes_and_win_unlocks_stage() -> void:
	game.t = RunDefs.NIGHT_SECONDS
	await wait_physics_frames(2)
	assert_true(game.boss_spawned)
	assert_not_null(game.boss)
	game.hit(game.boss.global_position, 3.0, 1e9)
	await wait_seconds(2.3)
	assert_eq(game.phase, game.Phase.RESULT)
	assert_eq(Progress.stages_open, 2)

func test_bot_plays_a_full_night() -> void:
	# A simple bot: kite away from the nearest hostile, walk to rice, always take the first card.
	Engine.time_scale = 2.0
	var steps := 0
	var last: Vector3 = game.player.global_position
	var stuck := 0
	var side := 1.0
	while game.phase != game.Phase.RESULT and steps < 30000:
		steps += 1
		if game.phase == game.Phase.LEVELUP:
			game.pick_card(0)
		var p: Vector3 = game.player.global_position
		var threat = game.swarm.nearest(p, 3.5)
		var dir := Vector3.ZERO
		if threat != null:
			dir = (p - threat).normalized()
		elif game.rice.pos.size() > 0:
			dir = (game.rice.pos[0] - p).normalized()
		# slide sideways when pinned against a wall, jar or tree
		stuck = stuck + 1 if p.distance_to(last) < 0.03 and dir != Vector3.ZERO else 0
		if stuck > 3:
			side = -side if stuck % 40 == 0 else side
			dir = dir.rotated(Vector3.UP, side * PI / 2)
		last = p
		_steer(dir)
		if randf() < 0.05: game.player.try_pounce()
		await wait_physics_frames(1)
	gut.p("bot: t=%.0fs kills=%d level=%d lives=%d won=%s weapons=%s" % [game.t, game.kills, game.level, game.lives, game.won, game.weapons.levels])
	assert_gt(game.kills, 60, "a night has plenty to hunt")
	assert_gt(game.level, 5, "levels come at a healthy pace")

func test_yarn_actually_hits() -> void:
	# feedback: "quăng cuộn len nhưng không trúng gì hết"
	game.weapons.levels = {"yarn": 1}
	game._apply_stats()
	game.swarm.clear()
	var c: Vector3 = game.player.global_position
	for k in 12:
		var a := k * TAU / 12.0
		game.swarm.spawn(MiceSwarm.Kind.NHAT, c + Vector3(cos(a), 0, sin(a)) * randf_range(4.0, 8.0))
	for k in game.swarm.count(): game.swarm.spawn_in[k] = 0.0
	game.swarm.frozen = true          # stationary targets: measure aim, not chase
	await wait_seconds(4.0)
	gut.p("yarn kills in 4 s: %d" % game.kills)
	assert_gte(game.kills, 6, "aimed, ricocheting yarn clears a ring of mice")
