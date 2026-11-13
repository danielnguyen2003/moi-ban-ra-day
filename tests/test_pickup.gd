extends GutTest
## Repro for "I can see the matchbox but can't pick it up".

var level: Node3D

func before_each() -> void:
	GameState.reset_run()
	level = load("res://scenes/main.tscn").instantiate()
	add_child(level)
	Director.enabled = false
	Director.rhyme_singing = true   # keep the cat sitting
	await wait_physics_frames(10)

func after_each() -> void:
	for a in ["move_forward", "interact", "run"]:
		Input.action_release(a)
	level.free()

func _press(a: String) -> void:
	Input.action_press(a)
	await wait_physics_frames(2)
	Input.action_release(a)
	await wait_physics_frames(2)

func test_pick_up_when_standing_next_to_matchbox() -> void:
	var rat: Rat = level.rat
	rat.global_position = Vector3(14.2, 10.4, -8.0)
	await wait_physics_frames(20)
	print("rat at ", rat.global_position, " on_floor=", rat.is_on_floor(), " nearby=", rat._nearby_pickups.size())
	assert_eq(rat.interact_hint(), "[E] Ngậm hộp diêm", "HUD tells the player what E does")
	await _press("interact")
	assert_not_null(rat.carrying, "rat carries the matchbox")

func test_pickup_radius_is_forgiving() -> void:
	var rat: Rat = level.rat
	rat.global_position = Vector3(14.6, 10.4, -6.3)   # ~1.7 units from the matchbox
	await wait_physics_frames(20)
	assert_ne(rat.interact_hint(), "", "prompt shows from a short distance away")

func test_deliver_matchbox_lights_incense() -> void:
	var rat: Rat = level.rat
	rat.global_position = Vector3(14.2, 10.4, -8.0)
	await wait_physics_frames(20)
	await _press("interact")
	rat.global_position = Vector3(1.5, 11.6, -21.0)   # on the altar beside the incense bowl
	await wait_physics_frames(20)
	assert_string_contains(rat.interact_hint(), "bát hương")
	await _press("interact")
	assert_true(level.incense.lit, "incense is burning")

func test_climb_tu_che_front_to_top() -> void:
	var rat: Rat = level.rat
	rat.global_position = Vector3(11.5, 0.5, -8.0)
	rat.camera_rig.yaw = -PI / 2   # camera faces +X, toward the tủ chè
	Input.action_press("move_forward")
	var max_y := 0.0
	for i in 600:
		await wait_physics_frames(1)
		max_y = maxf(max_y, rat.global_position.y)
		if rat.global_position.y > 9.8 and rat.is_on_floor():
			break
	Input.action_release("move_forward")
	print("final ", rat.global_position, " climbing=", rat.climbing, " max_y=", max_y)
	assert_gt(rat.global_position.y, 9.8, "rat reached the top of the tủ chè")
