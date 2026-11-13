extends GutTest

func _p() -> CatBrain.Perception:
	return CatBrain.Perception.new()

func test_rhyme_puts_cat_in_vigil_and_silence_releases_it() -> void:
	var b := CatBrain.new()
	var p := _p(); p.rhyme_singing = true
	assert_eq(b.tick(0.1, p), CatBrain.State.VIGIL)
	p.rhyme_singing = false
	assert_eq(b.tick(0.1, p), CatBrain.State.PATROL)

func test_noise_triggers_investigation_at_noise_position() -> void:
	var b := CatBrain.new()
	var p := _p(); p.heard_strength = 0.5; p.heard_pos = Vector3(3, 0, 4)
	assert_eq(b.tick(0.1, p), CatBrain.State.INVESTIGATE)
	assert_eq(b.target, Vector3(3, 0, 4))

func test_faint_noise_is_ignored() -> void:
	var b := CatBrain.new()
	var p := _p(); p.heard_strength = 0.05
	assert_eq(b.tick(0.1, p), CatBrain.State.PATROL)

func test_lit_visible_rat_escalates_to_stalk_then_chase() -> void:
	var b := CatBrain.new()
	var p := _p(); p.sees_rat = true; p.rat_exposure = 1.0; p.dist_to_rat = 20.0
	var seen := []
	for i in 40:
		seen.append(b.tick(0.05, p))
	assert_has(seen, CatBrain.State.STALK)
	assert_eq(seen[-1], CatBrain.State.CHASE)

func test_dark_distant_rat_is_not_noticed() -> void:
	var b := CatBrain.new()
	var p := _p(); p.sees_rat = true; p.rat_exposure = 0.0; p.dist_to_rat = 30.0
	for i in 100:
		b.tick(0.05, p)
	assert_eq(b.state, CatBrain.State.PATROL)

func test_hidden_rat_is_invisible() -> void:
	var b := CatBrain.new()
	var p := _p(); p.sees_rat = true; p.rat_exposure = 1.0; p.rat_hidden = true; p.dist_to_rat = 3.0
	for i in 100:
		b.tick(0.05, p)
	assert_eq(b.awareness, 0.0)

func test_sanctuary_ends_chase() -> void:
	var b := CatBrain.new()
	b.state = CatBrain.State.CHASE; b.awareness = 1.0
	var p := _p(); p.sees_rat = true; p.rat_exposure = 1.0; p.rat_in_sanctuary = true
	assert_eq(b.tick(0.1, p), CatBrain.State.SEARCH)

func test_long_chase_gives_up() -> void:
	var b := CatBrain.new()
	b.state = CatBrain.State.CHASE; b.awareness = 1.0
	var p := _p(); p.sees_rat = true; p.rat_exposure = 1.0; p.dist_to_rat = 5.0
	var t := 0.0
	while t < CatBrain.MAX_CHASE_TIME + 1.0:
		b.tick(0.5, p); t += 0.5
		if b.state != CatBrain.State.CHASE:
			break
	assert_eq(b.state, CatBrain.State.SEARCH)

func test_chase_continues_through_rhyme() -> void:
	var b := CatBrain.new()
	b.state = CatBrain.State.CHASE; b.awareness = 1.0
	var p := _p(); p.sees_rat = true; p.rat_exposure = 1.0; p.rhyme_singing = true; p.dist_to_rat = 5.0
	assert_eq(b.tick(0.1, p), CatBrain.State.CHASE)

func test_search_times_out_to_patrol() -> void:
	var b := CatBrain.new()
	b.set_patrol([Vector3(1, 0, 0), Vector3(2, 0, 0)] as Array[Vector3])
	b.state = CatBrain.State.SEARCH
	var p := _p()
	for i in 30:
		b.tick(0.5, p)
	assert_eq(b.state, CatBrain.State.PATROL)
