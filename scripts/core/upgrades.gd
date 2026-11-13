class_name Upgrades
extends RefCounted
## Upgrade table + pure formulas. Levels live in Progress; everything here is stateless and tested.

## id -> definition. cost(level) = base * growth^level. Effects are read through the helpers below.
const DEFS := {
	"speed":   {"name": "Chân nhanh",  "desc": "Chạy nhanh hơn 8%",              "base": 5.0,   "growth": 1.55, "icon": "🐾", "unlock": 0},
	"claw":    {"name": "Móng sắc",    "desc": "Vùng bắt rộng hơn 10%",          "base": 8.0,   "growth": 1.6,  "icon": "🪝", "unlock": 0},
	"time":    {"name": "Đêm dài",     "desc": "Thêm 3 giây mỗi đêm",            "base": 12.0,  "growth": 1.7,  "icon": "🌙", "unlock": 0},
	"spawn":   {"name": "Ổ chuột",     "desc": "Chuột ra nhiều hơn 15%",         "base": 10.0,  "growth": 1.6,  "icon": "🕳", "unlock": 0},
	"pounce":  {"name": "Vồ xa",       "desc": "Vồ xa hơn, hồi nhanh hơn",       "base": 20.0,  "growth": 1.65, "icon": "💨", "unlock": 1},
	"bounty":  {"name": "Bội thu",     "desc": "Cá nhận được ×1.15",             "base": 40.0,  "growth": 1.8,  "icon": "🐟", "unlock": 1},
	"kitten":  {"name": "Mèo con",     "desc": "Thêm một mèo con săn giúp",      "base": 150.0, "growth": 2.4,  "icon": "🐱", "unlock": 2},
	"luck":    {"name": "May mắn",     "desc": "Chuột vàng xuất hiện thường hơn", "base": 300.0, "growth": 2.0,  "icon": "✨", "unlock": 2},
	"whisker": {"name": "Râu nhạy",    "desc": "Chuột gần bị hút về phía mèo",   "base": 800.0, "growth": 2.1,  "icon": "〰", "unlock": 3},
}

## Map regions, unlocked in order by buying "Mở vùng".
const AREAS := [
	{"id": "san",     "name": "Sân gạch",        "cost": 0.0},
	{"id": "nha",     "name": "Gian nhà & bếp",  "cost": 60.0},
	{"id": "vuon",    "name": "Vườn chuối",      "cost": 900.0},
	{"id": "ao",      "name": "Ao làng",         "cost": 12000.0},
	{"id": "dinh",    "name": "Đình & cây đa",   "cost": 180000.0},
	{"id": "thama",   "name": "Bãi tha ma",      "cost": 3000000.0},
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
	return 30.0 + 3.0 * lv

static func spawn_per_second(lv: int, areas: int) -> float:
	## Starts stingy (a beginner catches 1–2), grows with upgrades and map size.
	return 0.09 * pow(1.15, lv) * (1.0 + 0.8 * (areas - 1))

static func max_mice(lv: int, areas: int) -> int:
	return int(4 + 4 * lv + 25 * (areas - 1))

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
