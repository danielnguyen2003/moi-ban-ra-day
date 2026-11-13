extends GutTest

func before_each() -> void:
	Progress.from_dict({})

func test_bignum_format() -> void:
	assert_eq(BigNum.fmt(0), "0")
	assert_eq(BigNum.fmt(999), "999")
	assert_eq(BigNum.fmt(1250), "1.25K")
	assert_eq(BigNum.fmt(3_400_000), "3.40M")
	assert_eq(BigNum.fmt(999_999), "1.00M")
	assert_eq(BigNum.fmt(2e12), "2.00T")
	assert_eq(BigNum.fmt(5e15), "5.00aa")

func test_costs_grow_exponentially() -> void:
	for id in Upgrades.DEFS:
		var a := Upgrades.cost(id, 0); var b := Upgrades.cost(id, 10)
		assert_gt(b, a * 50.0, id + " grows fast enough")

func test_buy_spends_fish_and_levels_up() -> void:
	Progress.fish = 100.0
	var c := Upgrades.cost("speed", 0)
	assert_true(Progress.buy("speed"))
	assert_eq(Progress.lv("speed"), 1)
	assert_almost_eq(Progress.fish, 100.0 - c, 0.001)

func test_cannot_buy_without_fish_or_before_unlock() -> void:
	Progress.fish = 1.0
	assert_false(Progress.buy("speed"))
	Progress.fish = 1e9
	assert_false(Progress.buy("kitten"), "kitten needs region 3")
	Progress.areas = 3
	assert_true(Progress.buy("kitten"))

func test_area_unlock() -> void:
	Progress.fish = Upgrades.area_cost(1)
	assert_true(Progress.buy_area())
	assert_eq(Progress.areas, 2)
	assert_eq(Progress.fish, 0.0)

func test_upgrades_make_cat_stronger() -> void:
	assert_gt(Upgrades.move_speed(5), Upgrades.move_speed(0))
	assert_gt(Upgrades.catch_radius(5), Upgrades.catch_radius(0))
	assert_lt(Upgrades.pounce_cooldown(10), Upgrades.pounce_cooldown(0))
	assert_gt(Upgrades.spawn_per_second(0, 3), Upgrades.spawn_per_second(0, 1))

func test_reincarnation_resets_and_grants_souls() -> void:
	Progress.lifetime_fish = 4e5; Progress.fish = 1000; Progress.levels = {"speed": 7}; Progress.areas = 4
	var s := Progress.reincarnate()
	assert_eq(s, 2)
	assert_eq(Progress.souls, 2)
	assert_eq(Progress.lv("speed"), 0)
	assert_eq(Progress.areas, 1)
	assert_gt(Upgrades.bounty_mult(0, 2), Upgrades.bounty_mult(0, 0))

func test_save_roundtrip() -> void:
	Progress.fish = 42.5; Progress.levels = {"claw": 3}; Progress.areas = 2; Progress.souls = 1
	var d := Progress.to_dict()
	Progress.from_dict({})
	Progress.from_dict(JSON.parse_string(JSON.stringify(d)))
	assert_eq(Progress.fish, 42.5)
	assert_eq(Progress.lv("claw"), 3)
	assert_eq(Progress.areas, 2)
