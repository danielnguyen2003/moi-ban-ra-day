extends GutTest

func before_each() -> void:
	Progress.from_dict({})

func test_bignum() -> void:
	assert_eq(BigNum.fmt(1250), "1.25K")
	assert_eq(BigNum.fmt(999_999), "1.00M")

func test_xp_curve_grows() -> void:
	assert_eq(RunDefs.xp_to_next(1), 5.0)
	assert_gt(RunDefs.xp_to_next(20), RunDefs.xp_to_next(10) * 1.5)

func test_weapons_scale_with_level_and_evolution() -> void:
	for id in RunDefs.WEAPONS:
		var a := RunDefs.weapon_stats(id, 1)
		var b := RunDefs.weapon_stats(id, 8)
		assert_gt(b.dmg, a.dmg, id)
		assert_has(RunDefs.PASSIVES, RunDefs.WEAPONS[id].evo, id + " evolves with an existing passive")
	assert_eq(RunDefs.weapon_stats("lantern", 8, true).count, 6)
	assert_eq(RunDefs.weapon_stats("claw", 8, true).arc, TAU)

func test_every_character_has_valid_weapon_and_perk() -> void:
	assert_eq(RunDefs.CHARACTERS.size(), 8)
	for id in RunDefs.CHARACTERS:
		var c: Dictionary = RunDefs.CHARACTERS[id]
		assert_has(RunDefs.WEAPONS, c.weapon)
		assert_has(RunDefs.PASSIVES, c.perk)
		assert_has(Upgrades.SKINS, c.skin)

func test_stage_difficulty_rises() -> void:
	for i in range(1, RunDefs.STAGES.size()):
		assert_gt(RunDefs.STAGES[i].hp, RunDefs.STAGES[i - 1].hp)
		assert_gt(RunDefs.STAGES[i].boss_hp, RunDefs.STAGES[i - 1].boss_hp)

func test_meta_buy() -> void:
	Progress.fish = 1000.0
	var c := RunDefs.meta_cost("m_might", 0)
	assert_true(Progress.buy_meta("m_might"))
	assert_eq(Progress.mlv("m_might"), 1)
	assert_almost_eq(Progress.fish, 1000.0 - c, 0.01)
	assert_gt(RunDefs.meta_cost("m_might", 5), c * 5.0)

func test_char_unlock_and_select() -> void:
	Progress.fish = 150.0
	assert_true(Progress.buy_or_select_char("xiem"))
	assert_eq(Progress.character, "xiem")
	assert_false(Progress.buy_or_select_char("khanran"), "too expensive")

func test_winning_unlocks_next_stage_then_endless() -> void:
	assert_eq(Progress.stages_open, 1)
	assert_true(Progress.end_night(true, 300.0, 500))
	assert_eq(Progress.stages_open, 2)
	assert_false(Progress.end_night(false, 100.0, 50), "losing unlocks nothing")
	Progress.stages_open = 5; Progress.stage = 4
	assert_true(Progress.end_night(true, 300.0, 900))
	assert_eq(Progress.heat, 1, "endless difficulty after the last stage")

func test_save_roundtrip() -> void:
	Progress.fish = 42.5; Progress.meta = {"m_life": 2}; Progress.chars_owned = ["muop", "mun"]; Progress.stages_open = 3
	var d: Dictionary = JSON.parse_string(JSON.stringify(Progress.to_dict()))
	Progress.from_dict({}); Progress.from_dict(d)
	assert_eq(Progress.fish, 42.5)
	assert_eq(Progress.mlv("m_life"), 2)
	assert_has(Progress.chars_owned, "mun")
	assert_eq(Progress.stages_open, 3)
