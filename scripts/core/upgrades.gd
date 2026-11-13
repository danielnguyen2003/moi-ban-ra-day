class_name Upgrades
extends RefCounted
## Upgrade table + pure formulas. Levels live in Progress; everything here is stateless and tested.

## id -> definition. cost(level) = base * growth^level. Effects are read through the helpers below.
const DEFS := {
	# --- săn bắt ---
	"speed":   {"name": "Chân nhanh",       "desc": "Chạy nhanh hơn 8%",                      "base": 5.0,    "growth": 1.45, "unlock": 0, "cat": "Săn bắt"},
	"claw":    {"name": "Móng sắc",         "desc": "Vùng bắt rộng hơn 10%",                  "base": 8.0,    "growth": 1.5,  "unlock": 0, "cat": "Săn bắt"},
	"pounce":  {"name": "Vồ xa",            "desc": "Vồ xa hơn 12%, hồi vồ nhanh hơn",        "base": 12.0,   "growth": 1.5,  "unlock": 0, "cat": "Săn bắt"},
	"charges": {"name": "Vồ liên hoàn",     "desc": "Thêm 1 lần vồ liên tiếp trước khi hồi",  "base": 60.0,   "growth": 2.6,  "unlock": 1, "cat": "Săn bắt"},
	"shock":   {"name": "Cú vồ chấn động",  "desc": "Khi đáp, bắt mọi chuột quanh chỗ đáp",   "base": 150.0,  "growth": 1.9,  "unlock": 1, "cat": "Săn bắt"},
	"whisker": {"name": "Râu nhạy",         "desc": "Chuột gần bị hút về phía mèo",           "base": 400.0,  "growth": 1.9,  "unlock": 2, "cat": "Săn bắt"},
	# --- đêm & chuột ---
	"time":    {"name": "Đêm dài",          "desc": "Thêm 2 giây mỗi đêm",                    "base": 15.0,   "growth": 1.6,  "unlock": 0, "cat": "Đêm & chuột"},
	"spawn":   {"name": "Ổ chuột",          "desc": "Chuột ra nhiều hơn 18%",                 "base": 10.0,   "growth": 1.5,  "unlock": 0, "cat": "Đêm & chuột"},
	"wave":    {"name": "Đàn chuột",        "desc": "Mỗi 6 giây một đàn chuột ùa ra",         "base": 90.0,   "growth": 1.85, "unlock": 1, "cat": "Đêm & chuột"},
	"clock":   {"name": "Bùa giờ",          "desc": "Mỗi con bắt được +0.1 giây",             "base": 250.0,  "growth": 2.0,  "unlock": 2, "cat": "Đêm & chuột"},
	"luck":    {"name": "May mắn",          "desc": "Chuột vàng xuất hiện thường hơn",        "base": 200.0,  "growth": 1.9,  "unlock": 2, "cat": "Đêm & chuột"},
	# --- cá khô ---
	"bounty":  {"name": "Bội thu",          "desc": "Cá nhận được ×1.15",                     "base": 30.0,   "growth": 1.7,  "unlock": 0, "cat": "Cá khô"},
	"double":  {"name": "Cá to",            "desc": "+5% cơ hội nhận cá ×3",                  "base": 70.0,   "growth": 1.8,  "unlock": 1, "cat": "Cá khô"},
	"combo":   {"name": "Liên hoàn dài",    "desc": "Giữ chuỗi liên hoàn lâu hơn, thưởng cao hơn", "base": 45.0, "growth": 1.75, "unlock": 1, "cat": "Cá khô"},
	# --- trợ thủ ---
	"kitten":  {"name": "Mèo con",          "desc": "Thêm một mèo con săn giúp",              "base": 120.0,  "growth": 2.3,  "unlock": 1, "cat": "Trợ thủ"},
	"trap":    {"name": "Bẫy chuột",        "desc": "Thêm 2 bẫy tre quanh làng, tự bắt chuột", "base": 180.0, "growth": 2.0,  "unlock": 2, "cat": "Trợ thủ"},
	"owl":     {"name": "Cú mèo",           "desc": "Cú bay vòng, sà xuống bắt chuột",        "base": 900.0,  "growth": 2.2,  "unlock": 3, "cat": "Trợ thủ"},
}

## Original cosmetic skins (no licensed characters). Bought once with fish, then selectable.
const SKINS := {
	"muop":   {"name": "Mèo mướp",    "cost": 0.0,     "fur": Color(0.62, 0.55, 0.47), "stripe": Color(0.3, 0.24, 0.2),  "belly": Color(0.95, 0.9, 0.82), "eye": Color(0.75, 1.0, 0.35), "stripes": true,  "hat": ""},
	"mun":    {"name": "Mèo mun",     "cost": 150.0,   "fur": Color(0.12, 0.11, 0.14), "stripe": Color(0.08, 0.07, 0.1), "belly": Color(0.2, 0.19, 0.22), "eye": Color(1.0, 0.85, 0.2),  "stripes": false, "hat": ""},
	"vang":   {"name": "Mèo vàng",    "cost": 400.0,   "fur": Color(0.95, 0.62, 0.3),  "stripe": Color(0.75, 0.4, 0.18), "belly": Color(1.0, 0.92, 0.8), "eye": Color(0.5, 0.95, 0.6),  "stripes": true,  "hat": ""},
	"tamthe": {"name": "Mèo tam thể", "cost": 1500.0,  "fur": Color(0.98, 0.96, 0.92), "stripe": Color(0.9, 0.55, 0.25), "belly": Color(1, 1, 1),        "eye": Color(0.6, 0.9, 1.0),  "stripes": true,  "hat": "", "patches": Color(0.15, 0.13, 0.13)},
	"xiem":   {"name": "Mèo Xiêm",    "cost": 6000.0,  "fur": Color(0.93, 0.86, 0.74), "stripe": Color(0.35, 0.25, 0.2), "belly": Color(0.98, 0.94, 0.86), "eye": Color(0.35, 0.65, 1.0), "stripes": false, "hat": "", "points": true},
	"hoa":    {"name": "Mèo trắng cài hoa", "cost": 20000.0, "fur": Color(0.98, 0.97, 0.98), "stripe": Color(0.9, 0.88, 0.9), "belly": Color(1, 1, 1), "eye": Color(0.45, 0.8, 1.0), "stripes": false, "hat": "flower"},
	"nonla":  {"name": "Mèo đội nón lá", "cost": 60000.0, "fur": Color(0.62, 0.55, 0.47), "stripe": Color(0.3, 0.24, 0.2), "belly": Color(0.95, 0.9, 0.82), "eye": Color(0.75, 1.0, 0.35), "stripes": true, "hat": "nonla"},
	"khanran": {"name": "Mèo khăn rằn", "cost": 200000.0, "fur": Color(0.95, 0.62, 0.3), "stripe": Color(0.75, 0.4, 0.18), "belly": Color(1.0, 0.92, 0.8), "eye": Color(0.5, 0.95, 0.6), "stripes": true, "hat": "scarf"},
}

## Map regions, unlocked in order by buying "Mở vùng".
const AREAS := [
	{"id": "san",     "name": "Sân gạch",        "cost": 0.0},
	{"id": "nha",     "name": "Gian nhà & bếp",  "cost": 80.0},
	{"id": "vuon",    "name": "Vườn chuối",      "cost": 1500.0},
	{"id": "ao",      "name": "Ao làng",         "cost": 25000.0},
	{"id": "dinh",    "name": "Đình & cây đa",   "cost": 400000.0},
	{"id": "thama",   "name": "Bãi tha ma",      "cost": 7000000.0},
]

static func cost(id: String, level: int) -> float:
	var d: Dictionary = DEFS[id]
	return ceil(d.base * pow(d.growth, level))

static func area_cost(index: int) -> float:
	if index < AREAS.size():
		return AREAS[index].cost
	return AREAS[-1].cost * pow(20.0, index - AREAS.size() + 1)

# ----------------------------------------------------------------- effects
static func move_speed(lv: int) -> float:          ## world units / s
	return 7.0 * pow(1.08, lv)

static func catch_radius(lv: int) -> float:
	return 1.2 * pow(1.10, lv)

static func night_seconds(lv: int) -> float:
	return 20.0 + 2.0 * lv

static func spawn_per_second(lv: int, areas: int) -> float:
	## Busy from the first night (~8–12 catches), grows with upgrades and map size.
	return 0.75 * pow(1.18, lv) * (1.0 + 0.6 * (areas - 1))

static func max_mice(lv: int, areas: int) -> int:
	return int(14 + 6 * lv + 30 * (areas - 1))

static func pounce_distance(lv: int) -> float:
	return 4.0 * pow(1.12, lv)

static func pounce_cooldown(lv: int) -> float:
	return maxf(0.25, 1.4 * pow(0.92, lv))

static func bounty_mult(lv: int, souls: int) -> float:
	return pow(1.15, lv) * (1.0 + 0.1 * souls)

static func golden_chance(lv: int) -> float:
	return 0.0 if lv <= 0 else minf(0.25, 0.02 + 0.015 * lv)

static func kittens(lv: int) -> int:
	return lv

static func magnet_radius(lv: int) -> float:
	return 0.0 if lv <= 0 else 2.0 + 0.6 * lv

## Souls earned by reincarnating now ("Chín kiếp"). Needs lifetime fish >= 1e5.
static func souls_for(lifetime_fish: float) -> int:
	if lifetime_fish < 1e5:
		return 0
	return int(floor(pow(lifetime_fish / 1e5, 0.5)))

static func charges(lv: int) -> int:
	return 1 + lv

static func shock_radius(lv: int) -> float:
	return 0.0 if lv <= 0 else 1.6 + 0.35 * lv

static func wave_size(lv: int) -> int:
	return 0 if lv <= 0 else 4 + 3 * lv

static func time_per_catch(lv: int) -> float:
	return 0.1 * lv

static func triple_chance(lv: int) -> float:
	return minf(0.6, 0.05 * lv)

static func combo_window(lv: int) -> float:
	return 1.6 + 0.35 * lv

static func combo_bonus(lv: int) -> float:
	return 0.1 + 0.03 * lv

static func traps(lv: int) -> int:
	return 2 * lv

static func owls(lv: int) -> int:
	return mini(lv, 6)
