class_name RunDefs
extends RefCounted
## All data for one night (run): weapons, passives, evolutions, characters, stages, meta upgrades.
## Pure data + formulas so balance can be unit-tested.

const MAX_WEAPON_LV := 8
const MAX_PASSIVE_LV := 5
const MAX_WEAPONS := 4
const MAX_PASSIVES := 4
const NIGHT_SECONDS := 300.0
const WEDDING_AT := 150.0

const WEAPONS := {
	"claw":    {"name": "Móng vuốt",   "desc": "Cào hình quạt phía trước mặt",            "evo": "might",   "evo_name": "Vuốt hổ",        "evo_desc": "Cào tròn 360°, sát thương ×2"},
	"lantern": {"name": "Đèn ông sao", "desc": "Đèn sao xoay quanh mèo, quật chuột",       "evo": "bell",    "evo_name": "Đèn kéo quân",   "evo_desc": "6 đèn xoay vòng rộng, không ngừng"},
	"cracker": {"name": "Pháo đùng",   "desc": "Ném pháo vào bầy chuột, nổ lan",           "evo": "bowl",    "evo_name": "Pháo hoa",       "evo_desc": "Mỗi quả nổ bung thành chùm pháo hoa"},
	"yarn":    {"name": "Cuộn len",    "desc": "Cuộn len lăn nảy khắp nơi",                "evo": "speed",   "evo_name": "Len thần",       "evo_desc": "Cuộn len to gấp đôi, tách đôi khi nảy"},
	"wisp":    {"name": "Ma trơi",     "desc": "Ma trơi tự đuổi theo chuột gần nhất",      "evo": "whisker", "evo_name": "Hồn ma trơi",    "evo_desc": "Ma trơi nảy liên hoàn sang 3 con"},
	"nia":     {"name": "Nia",         "desc": "Ném nia bay ra rồi quay về, xuyên bầy",    "evo": "fish",    "evo_name": "Nia vàng",       "evo_desc": "Hai nia, bay xa gấp đôi"},
}

const PASSIVES := {
	"speed":   {"name": "Chân nhanh", "desc": "Tốc độ chạy +10%"},
	"might":   {"name": "Móng sắc",   "desc": "Sát thương +12%"},
	"bell":    {"name": "Lục lạc",    "desc": "Hồi chiêu nhanh hơn 8%"},
	"whisker": {"name": "Râu nhạy",   "desc": "Tầm hút hạt gạo +40%"},
	"bowl":    {"name": "Bát cơm",    "desc": "+1 mạng tối đa và hồi 2 mạng"},
	"fish":    {"name": "Cá thần",    "desc": "Cá khô nhận được +15%"},
}

## Playable cats: each starts with its own weapon (and a small perk).
const CHARACTERS := {
	"muop":    {"skin": "muop",    "weapon": "claw",    "cost": 0.0,     "perk": "might",   "perk_desc": "Móng sắc cấp 1"},
	"xiem":    {"skin": "xiem",    "weapon": "lantern", "cost": 120.0,   "perk": "bell",    "perk_desc": "Lục lạc cấp 1"},
	"tamthe":  {"skin": "tamthe",  "weapon": "cracker", "cost": 300.0,   "perk": "bowl",    "perk_desc": "Bát cơm cấp 1"},
	"vang":    {"skin": "vang",    "weapon": "yarn",    "cost": 700.0,   "perk": "speed",   "perk_desc": "Chân nhanh cấp 1"},
	"mun":     {"skin": "mun",     "weapon": "wisp",    "cost": 1500.0,  "perk": "whisker", "perk_desc": "Râu nhạy cấp 1"},
	"hoa":     {"skin": "hoa",     "weapon": "nia",     "cost": 3000.0,  "perk": "fish",    "perk_desc": "Cá thần cấp 1"},
	"nonla":   {"skin": "nonla",   "weapon": "nia",     "cost": 8000.0,  "perk": "speed",   "perk_desc": "Chân nhanh cấp 2", "perk_lv": 2},
	"khanran": {"skin": "khanran", "weapon": "cracker", "cost": 20000.0, "perk": "might",   "perk_desc": "Móng sắc cấp 2", "perk_lv": 2},
}

## Stages: start region, difficulty and rewards.
const STAGES := [
	{"name": "Sân nhà",      "start": Vector3(0, 0, 3),    "hp": 1.0, "rate": 1.0, "fish": 1.0, "boss_hp": 1200.0, "kinds": ["nhat", "cong"]},
	{"name": "Vườn chuối",   "start": Vector3(38, 0, -10), "hp": 1.8, "rate": 1.2, "fish": 1.6, "boss_hp": 3000.0, "kinds": ["nhat", "cong", "chu"]},
	{"name": "Ao làng",      "start": Vector3(-26, 0, 8),  "hp": 3.0, "rate": 1.35, "fish": 2.5, "boss_hp": 7000.0, "kinds": ["nhat", "cong", "chu"]},
	{"name": "Đình làng",    "start": Vector3(0, 0, 30),   "hp": 4.8, "rate": 1.5, "fish": 4.0, "boss_hp": 15000.0, "kinds": ["nhat", "cong", "chu", "ma"]},
	{"name": "Bãi tha ma",   "start": Vector3(0, 0, 62),   "hp": 7.5, "rate": 1.7, "fish": 6.5, "boss_hp": 32000.0, "kinds": ["nhat", "cong", "chu", "ma"]},
]

## Permanent upgrades bought with fish between nights (infinite levels, exponential cost).
const META := {
	"m_might":  {"name": "Sức mạnh",   "desc": "Sát thương +8% vĩnh viễn",        "base": 40.0,  "growth": 1.55},
	"m_life":   {"name": "Thêm mạng",  "desc": "+1 mạng khởi đầu",                "base": 120.0, "growth": 2.1},
	"m_speed":  {"name": "Nhanh nhẹn", "desc": "Tốc độ +5% vĩnh viễn",            "base": 60.0,  "growth": 1.6},
	"m_magnet": {"name": "Hút gạo",    "desc": "Tầm hút hạt gạo +20%",           "base": 50.0,  "growth": 1.55},
	"m_greed":  {"name": "Tham ăn",    "desc": "Cá khô +12% vĩnh viễn",           "base": 80.0,  "growth": 1.6},
	"m_growth": {"name": "Lanh lợi",   "desc": "Kinh nghiệm +10%",               "base": 70.0,  "growth": 1.6},
	"m_cd":     {"name": "Nhanh tay",  "desc": "Hồi chiêu -4% vĩnh viễn",         "base": 150.0, "growth": 1.8},
	"m_reroll": {"name": "Đổi thẻ",    "desc": "+1 lượt đổi thẻ mỗi đêm",         "base": 200.0, "growth": 2.4},
	"m_revive": {"name": "Hồi sinh",   "desc": "+1 lần sống lại mỗi đêm",         "base": 2000.0, "growth": 4.0},
}

static func meta_cost(id: String, lv: int) -> float:
	var d: Dictionary = META[id]
	return ceil(d.base * pow(d.growth, lv))

# ---------------------------------------------------------------- formulas
static func xp_to_next(level: int) -> float:
	## level 1 -> 2 needs 5 rice; grows ~ like Vampire Survivors' early curve.
	return 5.0 + 5.0 * (level - 1) + 0.5 * pow(level - 1, 2.0)

## Mouse kinds by id (index into MiceSwarm.Kind).
static func spawn_rate(minute: float, stage: int) -> float:
	return (2.2 + 2.6 * minute) * float(STAGES[stage].rate)

static func max_alive(minute: float) -> int:
	return int(40 + 45 * minute)

static func mouse_hp(base: float, minute: float, stage: int) -> float:
	return base * (1.0 + 0.22 * minute + 0.03 * minute * minute) * float(STAGES[stage].hp)

## Weapon stats at level (1..8), evolved flag. Returns {dmg, cd, radius, count, ...}.
static func weapon_stats(id: String, lv: int, evolved := false) -> Dictionary:
	var l := float(lv - 1)
	match id:
		"claw":
			return {"dmg": (18.0 + 6.0 * l) * (2.0 if evolved else 1.0), "cd": maxf(0.3, 0.8 - 0.05 * l), "radius": 3.2 + 0.2 * l, "arc": TAU if evolved else 2.1}
		"lantern":
			return {"dmg": 9.0 + 3.5 * l, "cd": 0.3, "radius": 2.6 + 0.12 * l + (1.2 if evolved else 0.0), "count": 6 if evolved else 1 + int(lv / 2), "speed": 2.6 + 0.15 * l}
		"cracker":
			return {"dmg": 22.0 + 8.0 * l, "cd": maxf(0.6, 1.7 - 0.1 * l), "radius": 1.9 + 0.16 * l, "count": 1 + int(lv / 3), "cluster": evolved}
		"yarn":
			return {"dmg": 11.0 + 4.0 * l, "cd": maxf(1.2, 3.2 - 0.2 * l), "radius": (0.55 + 0.04 * l) * (2.0 if evolved else 1.0), "count": 1 + int(lv / 3), "life": 4.0 + 0.3 * l, "split": evolved}
		"wisp":
			return {"dmg": 16.0 + 6.0 * l, "cd": maxf(0.4, 1.25 - 0.08 * l), "count": 1 + int(lv / 3), "chain": 3 if evolved else 0}
		"nia":
			return {"dmg": 15.0 + 5.5 * l, "cd": maxf(0.7, 1.8 - 0.1 * l), "range": (7.0 + 0.4 * l) * (2.0 if evolved else 1.0), "radius": 0.95 + 0.05 * l, "count": 2 if evolved else 1}
	return {}
