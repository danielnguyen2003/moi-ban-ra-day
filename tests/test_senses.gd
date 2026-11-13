extends GutTest

func test_noise_falls_off_with_distance() -> void:
	var near := NoiseBus.perceived(Vector3.ZERO, 10.0, Vector3(2, 0, 0), 0)
	var far := NoiseBus.perceived(Vector3.ZERO, 10.0, Vector3(8, 0, 0), 0)
	assert_gt(near, far)
	assert_eq(NoiseBus.perceived(Vector3.ZERO, 10.0, Vector3(11, 0, 0), 0), 0.0)

func test_walls_muffle_noise() -> void:
	var open := NoiseBus.perceived(Vector3.ZERO, 10.0, Vector3(3, 0, 0), 0)
	var walled := NoiseBus.perceived(Vector3.ZERO, 10.0, Vector3(3, 0, 0), 1)
	assert_almost_eq(walled, open * 0.5, 0.001)

func test_light_contribution_zero_outside_range() -> void:
	assert_eq(ExposureSampler.light_contribution(31.0, 30.0, 2.0), 0.0)
	assert_gt(ExposureSampler.light_contribution(5.0, 30.0, 2.0), ExposureSampler.light_contribution(20.0, 30.0, 2.0))

func test_cat_speed_beats_rat_only_when_chasing() -> void:
	var rat_run := 8.8
	assert_gt(CatBrain.speed_for(CatBrain.State.CHASE), rat_run)
	assert_lt(CatBrain.speed_for(CatBrain.State.STALK), rat_run)
	assert_eq(CatBrain.speed_for(CatBrain.State.VIGIL), 0.0)
