extends GutTest
## Simulated nights on the real scene.

var game: Node3D

func before_each() -> void:
	Progress.from_dict({})
	game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await wait_physics_frames(5)

func after_each() -> void:
	Input.action_release("move_up")
	game.free()

func test_village_regions_and_holes() -> void:
	assert_true(game.village.inside(Vector3(0, 0, 0)), "courtyard is walkable")
	assert_false(game.village.inside(Vector3(0, 0, -15)), "house locked at start")
	assert_gt(game.village.holes().size(), 2)
	game.village.set_unlocked(2)
	assert_true(game.village.inside(Vector3(0, 0, -15)))

func test_mouse_next_to_cat_is_caught_and_pays() -> void:
	game.start_night()
	game.swarm.clear()
	var before := Progress.fish
	game.swarm.spawn(MiceSwarm.Kind.NHAT, game.player.global_position + Vector3(0.5, 0, 0))
	game.swarm.spawn_in[0] = 0.0    # skip the pop-in grace period
	await wait_physics_frames(3)
	assert_eq(game.caught_night, 1)
	assert_gt(Progress.fish, before)

func test_tough_rat_needs_two_hits() -> void:
	game.start_night()
	game.swarm.clear()
	game.swarm.cats = [] as Array[Cat]   # catch manually
	game.swarm.spawn(MiceSwarm.Kind.CONG, Vector3(5, 0, 5))
	await wait_physics_frames(30)
	game.swarm.spawn_in[0] = 0.0
	game.player.global_position = game.swarm.pos[0]
	game.swarm.cats = [game.player] as Array[Cat]
	await wait_physics_frames(2)
	assert_eq(game.swarm.count(), 1, "first hit only knocks it back")

func test_mice_flee_and_stay_inside() -> void:
	game.start_night()
	game.swarm.clear()
	game.swarm.spawn(MiceSwarm.Kind.NHAT, game.player.global_position + Vector3(3, 0, 0))
	await wait_seconds(1.0)
	if game.swarm.count() > 0:
		var p: Vector3 = game.swarm.pos[0]
		assert_gt(p.distance_to(game.player.global_position), 3.0, "mouse ran away")
		assert_true(game.village.inside(p) or game.village.clamp_inside(p).distance_to(p) < 0.6)

func test_night_ends_and_shows_summary() -> void:
	game.start_night()
	game.time_left = 0.05
	await wait_physics_frames(5)
	assert_eq(game.phase, game.Phase.SUMMARY)
	assert_eq(Progress.nights, 1)

func test_beginner_night_is_stingy_but_not_empty() -> void:
	# The pitch: a fresh cat catches only a handful. Simulate 30 s with the cat chasing the nearest mouse.
	game.start_night()
	var t := 0.0
	while game.phase == game.Phase.HUNT and t < 40.0:
		var n = game.swarm.nearest(game.player.global_position, 100.0)
		if n != null:
			var d: Vector3 = n - game.player.global_position
			game.player.velocity = d.normalized() * game.player.speed
			if d.length() < 3.5:
				game.player._dir = d.normalized(); game.player.try_pounce()
		await wait_physics_frames(6)
		t += 0.1
	gut.p("beginner caught %d" % game.caught_night)
	assert_between(game.caught_night, 1, 6, "a perfect-play bot; humans catch fewer")

func test_kittens_spawn_from_upgrade() -> void:
	Progress.areas = 3; Progress.levels = {"kitten": 2}
	game._apply_stats()
	assert_eq(game.kittens.size(), 2)
	assert_eq(game.swarm.cats.size(), 3)
