extends GutTest
## Simulated play: real physics, real level, scripted input.

var level: Node3D

func before_each() -> void:
	GameState.reset_run()
	level = load("res://scenes/main.tscn").instantiate()
	add_child(level)
	Director.enabled = false
	Director.rhyme_singing = false
	await wait_physics_frames(10)

func after_each() -> void:
	for a in ["move_forward", "run"]:
		Input.action_release(a)
	level.free()

func test_rat_walks_forward_on_input() -> void:
	var rat: Rat = level.rat
	var start := rat.global_position
	Input.action_press("move_forward")
	await wait_seconds(1.5)
	Input.action_release("move_forward")
	assert_gt(start.distance_to(rat.global_position), 2.0, "rat moved")
	assert_true(rat.is_on_floor(), "rat stands on the porch/yard floor")

func test_running_makes_noise_the_cat_can_hear() -> void:
	var heard := []
	NoiseBus.noise_emitted.connect(func(p, l, s): heard.append(l))
	Input.action_press("move_forward")
	Input.action_press("run")
	await wait_seconds(1.0)
	assert_gt(heard.size(), 0, "footsteps emitted")
	assert_gt(heard.max(), 5.0, "running is loud")

func test_cat_catches_lit_rat_in_front_of_it() -> void:
	var rat: Rat = level.rat
	var cat: CatController = level.cat
	var caught := [false]
	GameState.player_caught.connect(func(): caught[0] = true)
	# Put the rat in the lamp light a few metres ahead of the cat, cat facing it.
	cat.global_position = Vector3(2, 0.2, 9)
	cat.rotation.y = 0.0                        # facing -Z
	rat.global_position = Vector3(2, 0.5, -1)   # in the lamp light; nearer the altar is in its shadow
	await wait_seconds(0.5)
	assert_gt(rat.exposure, 0.2, "rat is lit by the oil lamp")
	var states := []
	cat.state_changed.connect(func(s): states.append(s))
	var t := 0.0
	while t < 8.0 and not caught[0]:
		await wait_physics_frames(6)
		t += 0.1
	assert_has(states, CatBrain.State.CHASE, "cat chased")
	assert_true(caught[0], "cat caught the exposed rat")

func test_hidden_rat_under_sap_is_safe() -> void:
	var rat: Rat = level.rat
	var cat: CatController = level.cat
	var caught := [false]
	GameState.player_caught.connect(func(): caught[0] = true)
	rat.global_position = Vector3(-8.5, 0.4, 2)
	cat.global_position = Vector3(-1.5, 0.2, 2)
	cat.rotation.y = PI / 2                     # facing -X, toward the sập
	await wait_seconds(5.0)
	assert_true(rat.is_hidden(), "rat registers as hidden under the sập")
	assert_false(caught[0], "cat cannot reach under the sập")
